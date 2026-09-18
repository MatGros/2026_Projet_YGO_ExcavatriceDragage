#!/usr/bin/env python3
"""
Prototype hors-automate (Python pur) du modele electrotechnique treuil M1/M2 :
moteur asynchrone rotor bobine + cascade resistances rotoriques + groupe electrogene
partage entre plusieurs treuils, avec protection thermique image I2t et mode
"rejeu d'incident" pour le debug/mise en service.

STATUT : brique exploratoire T317 (P0/P1) - AUCUNE valeur numerique n'est mesuree
terrain. Tout est SYNTHETIQUE/ESTIME tant que la plaque signaletique moteur et la
fiche groupe electrogene ne sont pas fournies (cf. PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md).

Ne remplace pas SimBench CODESYS : sert a valider le modele et son comportement
qualitatif (decrochage en charge, declenchement thermique, coincidence multi-treuils)
avant tout portage ST. Usage vise : debug/mise en service -- "est-ce que cette
sequence de commande va decrocher ou faire declencher le thermique ?"

Usage :
    # Un treuil, comparaison charge/a vide
    python sim_treuil_electrique.py --load 0.9 --compare --gradin-times 0,0.4,0.8,1.2 --plot

    # Deux treuils simultanes sur le meme groupe electrogene
    python sim_treuil_electrique.py --scenario deux_treuils --plot

    # Rejeu d'un incident terrain (fichier JSON de commandes observees)
    python sim_treuil_electrique.py --incident incident_exemple.json --plot
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field


def valider_gradin_times(gradin_times: list, nom: str = "") -> None:
    """Leve ValueError si la sequence n'est pas strictement croissante -- gradin_actif()
    suppose l'ordre temporel et donne un resultat incoherent silencieux sinon."""
    if any(a > b for a, b in zip(gradin_times, gradin_times[1:])):
        prefixe = f"[{nom}] " if nom else ""
        raise ValueError(
            f"{prefixe}instants de bascule gradins non croissants : {gradin_times} "
            "-- doivent etre ranges dans l'ordre chronologique."
        )


# ============================================================================
# Parametres moteur / groupe electrogene (HYPOTHESES SYNTHETIQUES - a caler)
# ============================================================================

@dataclass
class MotorParams:
    name: str = "M1"
    p: int = 4                      # nombre de poles -> HYPOTHESE
    f_nom: float = 50.0              # Hz reseau
    Cmax: float = 3800.0             # N.m, couple de decrochage -> SYNTHETIQUE
    C_nominal: float = 2500.0        # N.m, couple nominal (calage courant) -> aligne par defaut sur C_nominal_charge
    gmax0: float = 0.08              # glissement au couple max, gradin 0 (rotor court-circuite)
    X2: float = 1.0                  # reactance de fuite rotor ramenee
    R2_rotor: float = 0.08           # resistance propre rotor (gradin 0)
    R2_ext_gradins: tuple = (2.4, 1.1, 0.35, 0.0)  # gradin 0 = resistance max, dernier = rotor court-circuite
    In_stator: float = 200.0         # A, courant nominal stator a couple nominal -> point de calage utilisateur
    I0_pu: float = 0.35              # courant magnetisant a vide, fraction de In (0.25-0.45 typique moteurs lents/treuil, recherche 2026-09-18)
    J_total: float = 45.0            # kg.m2, inertie ramenee treuil+charge -> SYNTHETIQUE
    Tau_elec: float = 0.03           # s, constante de temps filtrage courant stator

    @property
    def Ns_rpm(self) -> float:
        return 120.0 * self.f_nom / self.p

    @property
    def Ns_rad_s(self) -> float:
        return self.Ns_rpm * 2 * math.pi / 60.0

    @property
    def I_actif_nominal(self) -> float:
        """Composante active du courant a couple nominal : I_actif = sqrt(In^2 - I0^2)
        (decomposition vectorielle I0 constant / Iactif proportionnel au couple, cf.
        recherche 2026-09-18 -- diagramme de Fresnel simplifie moteur asynchrone)."""
        I0 = self.I0_pu * self.In_stator
        return math.sqrt(max(self.In_stator ** 2 - I0 ** 2, 0.0))

    def courant_stator(self, C_motor: float) -> float:
        """I1 = sqrt(I0^2 + Iactif^2), Iactif proportionnel au couple electromagnetique
        developpe (pas au taux de charge commande) -- le courant suit le couple reel,
        y compris pendant les transitoires ou C_motor != Cr. Calage : a C_motor=C_nominal,
        I1=In_stator exactement."""
        I0 = self.I0_pu * self.In_stator
        ratio = abs(C_motor) / max(self.C_nominal, 1e-6)
        I_actif = ratio * self.I_actif_nominal
        return math.sqrt(I0 ** 2 + I_actif ** 2)

    def gmax(self, gradin: int) -> float:
        r2_total = self.R2_rotor + self.R2_ext_gradins[gradin]
        return self.gmax0 * r2_total / self.R2_rotor

    def tau_rotor(self, gradin: int) -> float:
        """Constante de temps electrique du circuit rotorique L2/R2_total au gradin donne.
        L2 deduite de X2 a la frequence reseau (L2 = X2/(2*pi*f_nom)). Determine la duree du
        pic de courant a la commutation d'un gradin (plus le gradin est faible en resistance,
        plus la constante de temps est courte -> pic bref mais marque)."""
        r2_total = self.R2_rotor + self.R2_ext_gradins[gradin]
        L2 = self.X2 / (2 * math.pi * self.f_nom)
        return L2 / max(r2_total, 1e-6)


def _couple_kloss(Cmax: float, g: float, gmax: float, U_ratio2: float = 1.0) -> float:
    """Formule de Kloss factorisee (utilisee pour le regime etabli ET pour evaluer le saut
    instantane de couple/courant a la commutation d'un gradin)."""
    g_eff = _safe_g(g)
    return 2.0 * Cmax / (g_eff / gmax + gmax / g_eff) * U_ratio2


@dataclass
class GensetParams:
    U_nom: float = 400.0             # V ligne, tension a vide
    I_nom_groupe: float = 350.0      # A, courant nominal du groupe -> SYNTHETIQUE (calage 400->360V)
    Xpp_pu: float = 0.13             # X"d en pu, phase subtransitoire (0.10-0.20 pu plage catalogue)
    Tavr: float = 0.4                # s, constante de temps regulation AVR
    I_base_site: float = 20.0        # A, charge de base non-treuil (eclairage, pompes, etc.)

    @property
    def Xpp_ohm(self) -> float:
        return self.Xpp_pu * self.U_nom / self.I_nom_groupe


@dataclass
class ThermalRelayParams:
    """Image thermique type relais/disjoncteur classe 10-30 (norme IEC 60947-4-1).
    Modele I2t simplifie : tau_th = classe * 10 / (rapport de declenchement)^2, calage generique."""
    Ith_reglage: float = 220.0       # A, seuil de reglage thermique (proche In_stator)
    classe_declenchement: int = 20   # classe 10/20/30 -> temps de declenchement a 7.2xIth (s), IEC 60947-4-1
    tau_refroidissement_s: float = 300.0  # s, constante de temps thermique globale -> SYNTHETIQUE

    def tau_declenchement(self) -> float:
        # temps de declenchement nominal a 7.2x In pour la classe donnee (ordre de grandeur norme)
        temps_a_7_2In = {10: 10.0, 20: 20.0, 30: 30.0}.get(self.classe_declenchement, 20.0)
        # tau du 1er ordre thermique tel que l'image atteigne le seuil de declenchement a 7.2xIth en temps_a_7_2In
        ratio = 7.2 ** 2
        return temps_a_7_2In * ratio / math.log(ratio / (ratio - 1))


class ThermalImage:
    """Integrateur I2t d'un relais thermique. theta=1.0 -> declenchement."""

    def __init__(self, params: ThermalRelayParams):
        self.p = params
        self.tau = params.tau_declenchement()
        self.theta = 0.0  # 0 = froid, 1 = declenchement
        self.tripped = False
        self.trip_time: float | None = None

    def step(self, I: float, t: float, dt: float):
        if self.tripped:
            return
        ratio2 = (I / max(self.p.Ith_reglage, 1e-6)) ** 2
        theta_cible = ratio2
        self.theta += (theta_cible - self.theta) * dt / self.tau
        if self.theta >= 1.0:
            self.tripped = True
            self.trip_time = t


# ============================================================================
# Vieillissement isolant bobinage (IEC 60034-1 classes B/F/H + regle de Montsinger)
# Source recherche 2026-09-18 : IEC 60034-1, IEC 60085, IEEE 1-2000.
# ============================================================================

@dataclass
class InsulationParams:
    classe: str = "F"                # B (130C) / F (155C) / H (180C) -- IEC 60034-1
    theta_ambiante: float = 40.0     # C, temperature ambiante de reference
    delta_theta_nominal: float = 105.0  # K, echauffement nominal a In (classe F = 105K par defaut)
    tau_th_winding_s: float = 1200.0  # s, constante de temps thermique enroulement -> 20 min, ordre de grandeur ~200A
    delta_T_montsinger: float = 10.0  # K, ecart pour division par 2 de la duree de vie (regle de Montsinger, 8-10C)
    duree_vie_nominale_h: float = 87600.0  # h, duree de vie nominale isolant a temperature nominale -> SYNTHETIQUE (10 ans)

    THETA_LIMITE = {"B": 130.0, "F": 155.0, "H": 180.0}

    @property
    def theta_limite_classe(self) -> float:
        return self.THETA_LIMITE.get(self.classe, 155.0)

    @property
    def theta_nominale(self) -> float:
        return self.theta_ambiante + self.delta_theta_nominal


class WindingThermalAging:
    """Image thermique du bobinage (pas la protection relais) + compteur de vieillissement
    accelere (loi de Montsinger). Independant du declenchement relais : un relais bien regle
    protege le materiel AVANT que ce compteur ne devienne critique -- sert a verifier cette
    hypothese, ou a la remettre en cause si le relais est trop permissif."""

    def __init__(self, params: InsulationParams, In_stator: float):
        self.p = params
        self.In = In_stator
        self.theta = params.theta_ambiante  # temperature bobinage estimee, C
        self.vieillissement_cumule_h = 0.0  # heures-equivalentes classe consommees
        self.isolant_endommage = False       # theta a depasse la limite de classe
        self.isolant_endommage_time: float | None = None

    def step(self, I: float, t: float, dt: float):
        ratio2 = (I / max(self.In, 1e-6)) ** 2
        theta_cible = self.p.theta_ambiante + self.p.delta_theta_nominal * ratio2
        self.theta += (theta_cible - self.theta) * dt / self.p.tau_th_winding_s

        if not self.isolant_endommage and self.theta > self.p.theta_limite_classe:
            self.isolant_endommage = True
            self.isolant_endommage_time = t

        # facteur d'acceleration de Montsinger : >1 si au-dessus de la temperature nominale
        F_AA = 2.0 ** ((self.theta - self.p.theta_nominale) / self.p.delta_T_montsinger)
        self.vieillissement_cumule_h += F_AA * dt / 3600.0

    @property
    def pct_vie_consommee(self) -> float:
        return 100.0 * self.vieillissement_cumule_h / max(self.p.duree_vie_nominale_h, 1e-6)


# ============================================================================
# Choc mecanique reducteur (facteur de service AGMA 6011 / ISO 6336)
# Source recherche 2026-09-18 : AGMA 6011 (reducteurs usage general), ISO 6336, FEM 9.511/9.751
# (classes de mecanismes de levage). Ordres de grandeur : uniforme 1.5x, choc modere 2x,
# choc lourd/levage 2.5-3x le couple nominal avant risque de dommage denture/arbre.
# ============================================================================

@dataclass
class GearboxParams:
    C_nominal: float = 2500.0        # N.m, couple nominal du reducteur -> aligne sur C_nominal_charge
    SF_choc_admissible: float = 2.5  # facteur de service levage/choc lourd (AGMA 6011 / pratique treuil) : 2.5-3x
    jerk_seuil_Nm_s: float = 15000.0  # N.m/s, taux de variation de couple aggravant -> HYPOTHESE, non normatif


class GearboxShockDetector:
    def __init__(self, params: GearboxParams):
        self.p = params
        self.C_prev = 0.0
        self.choc_detecte = False
        self.choc_time: float | None = None
        self.choc_severe = False  # amplitude ET jerk au-dessus du seuil simultanement

    def step(self, C_motor: float, t: float, dt: float):
        ratio = abs(C_motor) / max(self.p.C_nominal, 1e-6)
        jerk = (C_motor - self.C_prev) / max(dt, 1e-9)
        self.C_prev = C_motor

        if ratio > self.p.SF_choc_admissible:
            if not self.choc_detecte:
                self.choc_detecte = True
                self.choc_time = t
            if abs(jerk) > self.p.jerk_seuil_Nm_s:
                self.choc_severe = True


# ============================================================================
# Modele mecanique+electrique d'un treuil (instance reutilisable pour M1/M2)
# ============================================================================

def _safe_g(g: float, eps: float = 1e-4) -> float:
    """Evite la division par zero au voisinage de g=0 SANS ecraser le signe -- indispensable
    en mode bidirectionnel/generatrice ou g peut etre negatif (survitesse -> freinage
    electrique). L'ancien `max(g, 1e-4)` ecrasait tout g negatif a +1e-4, ce qui aurait
    invalide le mode genrateur (couple de freinage jamais calcule correctement)."""
    if abs(g) < eps:
        return eps if g >= 0 else -eps
    return g


@dataclass
class WinchInstance:
    motor: MotorParams
    load_frac: float
    gradin_times: list                # instants (s) de bascule au gradin suivant
    direction: int = 1                # +1 = montee (levage), -1 = descente -- sens de commande
    thermal: ThermalRelayParams = field(default_factory=ThermalRelayParams)
    insulation: InsulationParams = field(default_factory=InsulationParams)
    gearbox: GearboxParams = field(default_factory=GearboxParams)
    k_inrush: float = 1.0             # facteur multiplicatif sur le saut de courant a la commutation
                                       # -> HYPOTHESE (voir _couple_kloss/tau_rotor), 1.0 = pas d'overshoot
                                       # DC ajoute ; augmenter (ex 1.5-2.0) pour une hypothese pessimiste

    def __post_init__(self):
        valider_gradin_times(self.gradin_times, nom=self.motor.name)
        if self.direction not in (1, -1):
            raise ValueError(f"[{self.motor.name}] direction doit etre 1 (montee) ou -1 (descente), recu {self.direction}")
        self.N = 0.0                  # rad/s, EXPRIME DANS LE REPERE DE COMMANDE (N_rel) : voir step()
        self.I1_filt = 0.0
        self.stalled = False          # etat instantane, peut se reinitialiser si le moteur repart
        self.ever_stalled = False     # jamais reinitialise -- reflete l'historique complet, sert au verdict final
        self.stall_time: float | None = None
        self.image = ThermalImage(self.thermal)
        self.aging = WindingThermalAging(self.insulation, self.motor.In_stator)
        self.shock = GearboxShockDetector(self.gearbox)
        self._last_gradin: int | None = None
        self.I_transitoire = 0.0      # A, composante transitoire de courant (pic de commutation), decroit exp.
        self.commutations = []        # liste de (t, saut_A, pic_estime_A) -- une entree par bascule de gradin
        self.hist = {
            "t": [], "N_rpm": [], "g": [], "C": [], "Cr": [], "I1": [], "I1_brut": [], "theta": [], "gradin": [],
            "theta_bobinage": [], "pct_vie": [],
        }

    def gradin_actif(self, t: float) -> int:
        n = len(self.motor.R2_ext_gradins)
        gradin = 0
        for i, switch_t in enumerate(self.gradin_times):
            if t >= switch_t:
                gradin = min(i, n - 1)
        return gradin

    def couple_resistant(self) -> float:
        """Couple resistant projete dans le repere de commande (N_rel).
        La gravite tire TOUJOURS physiquement vers la descente, quel que soit le sens
        commande -- en montee elle s'oppose (Cr>0, comme avant) ; en descente elle AIDE
        (Cr peut devenir negatif : le poids fait descendre plus vite que necessaire, le
        moteur doit alors freiner -- c'est le regime generatrice, gere automatiquement
        par la formule de Kloss qui est impaire en glissement)."""
        C_frottements = 80.0  # N.m, frottements residuels -> SYNTHETIQUE, s'oppose toujours au mouvement commande
        C_nominal_charge = 2500.0  # N.m a pleine charge -> SYNTHETIQUE
        return C_frottements + self.direction * self.load_frac * C_nominal_charge

    def step(self, t: float, dt: float, U_reseau: float, U_nom: float) -> float:
        """Avance d'un pas. Retourne le courant stator filtre (pour sommation cote genset).

        self.N est exprime dans le repere de commande (N_rel = N_physique * direction) :
        cette projection permet de reutiliser telle quelle la formule de Kloss standard
        (qui suppose un sens de rotation positif de reference) tout en gerant motorisation
        ET generatrice dans les deux sens de commande. Voir REFERENCE_T317 pour le detail."""
        gradin = self.gradin_actif(t)
        g = 1.0 - self.N / self.motor.Ns_rad_s  # peut etre negatif (survitesse -> freinage genarateur)
        U_ratio2 = (U_reseau / U_nom) ** 2

        gmax = self.motor.gmax(gradin)
        C_motor = _couple_kloss(self.motor.Cmax, g, gmax, U_ratio2)
        Cr = self.couple_resistant()

        # Detection de commutation de gradin : saut instantane du couple/courant quasi-statique
        # a glissement inchange (ancien vs nouveau gradin), puis relaxation exponentielle du
        # circuit rotorique (tau_rotor = L2/R2, cf. MotorParams.tau_rotor). Modelise le pic de
        # courant reel a la bascule, absent du modele quasi-statique pur (limite signalee a
        # plusieurs reprises -- corrigee ici, demande explicite utilisateur 2026-09-18).
        if self._last_gradin is not None and gradin != self._last_gradin:
            gmax_avant = self.motor.gmax(self._last_gradin)
            C_avant = _couple_kloss(self.motor.Cmax, g, gmax_avant, U_ratio2)
            I_avant = self.motor.courant_stator(C_avant)
            I_apres_instant = self.motor.courant_stator(C_motor)
            saut = abs(I_apres_instant - I_avant)
            self.I_transitoire += self.k_inrush * saut
            pic_estime = self.I_transitoire + I_apres_instant
            self.commutations.append((t, saut, pic_estime))
        self._last_gradin = gradin

        tau_r = self.motor.tau_rotor(gradin)
        self.I_transitoire *= math.exp(-dt / max(tau_r, 1e-6))

        dN_dt = (C_motor - Cr) / self.motor.J_total
        self.N = self.N + dN_dt * dt  # pas de clamp >=0 : N_rel peut devenir negatif (marche arriere/recul)

        # Test predictif : au gradin courant, le couple disponible a glissement bloque (g=1)
        # est-il deja inferieur au couple resistant ? Ce n'est PAS une mesure de decrochage
        # reel (vitesse=0 stable), c'est une prediction sur ce gradin a l'instant t -- reste
        # correct tant que N est proche de 0, garde-fou N<3.0 rad/s ci-dessous.
        C_locked_rotor = _couple_kloss(self.motor.Cmax, 1.0, gmax, U_ratio2)
        if abs(self.N) < 3.0 and C_locked_rotor < Cr and t > 0.2:  # 3.0 rad/s ~ 28 rpm, seuil "quasi arrete"
            if not self.stalled:
                self.stalled = True
                self.ever_stalled = True
                self.stall_time = t
        elif abs(self.N) > 3.0:
            self.stalled = False  # etat instantane leve, mais ever_stalled garde la trace historique

        # Courant stator : composition en quadrature I0 (magnetisant, constant) / Iactif
        # (proportionnel au couple electromagnetique reellement developpe) -- cf. recherche
        # 2026-09-18. Calage : a C_motor=C_nominal, I1=In_stator exactement. + transitoire de
        # commutation (I_transitoire, cf. bloc ci-dessus) ajoute directement, NON lisse par
        # Tau_elec -- c'est le pic reel que la mesure/protection verrait.
        I1_quasi = self.motor.courant_stator(C_motor)
        I1_brut = I1_quasi + self.I_transitoire
        self.I1_filt += (I1_brut - self.I1_filt) * dt / self.motor.Tau_elec

        self.image.step(I1_brut, t, dt)
        self.aging.step(I1_brut, t, dt)
        self.shock.step(C_motor, t, dt)

        self.hist["t"].append(t)
        # N_rpm = vitesse PHYSIQUE reelle (signee : + = montee, - = descente), pas N_rel
        self.hist["N_rpm"].append(self.N * self.direction * 60.0 / (2 * math.pi))
        self.hist["g"].append(g)
        self.hist["C"].append(C_motor)
        self.hist["Cr"].append(Cr)
        self.hist["I1"].append(self.I1_filt)
        self.hist["I1_brut"].append(I1_brut)
        self.hist["theta"].append(self.image.theta)
        self.hist["gradin"].append(gradin)
        self.hist["theta_bobinage"].append(self.aging.theta)
        self.hist["pct_vie"].append(self.aging.pct_vie_consommee)

        return I1_brut


@dataclass
class MultiSimResult:
    winches: dict  # name -> WinchInstance (post-simulation, historique rempli)
    U_reseau_hist: list
    t_hist: list


def simulate_multi(genset: GensetParams, winches: list, t_end: float, dt: float = 0.01) -> MultiSimResult:
    """Simule N treuils partageant le meme bus groupe electrogene."""
    U_reseau = genset.U_nom
    t_hist, U_hist = [], []

    t = 0.0
    steps = int(t_end / dt)
    for _ in range(steps):
        I_total = genset.I_base_site
        for w in winches:
            I_total += w.step(t, dt, U_reseau, genset.U_nom)

        U_instant = genset.U_nom - genset.Xpp_ohm * I_total
        U_reseau += (U_instant - U_reseau) * dt / genset.Tavr
        U_reseau = max(U_reseau, 0.0)

        t_hist.append(t)
        U_hist.append(U_reseau)
        t += dt

    return MultiSimResult(winches={w.motor.name: w for w in winches}, U_reseau_hist=U_hist, t_hist=t_hist)


def _verdict(ok: bool) -> str:
    return "OK  " if ok else "!!!!"


def print_summary(res: MultiSimResult):
    U_min = min(res.U_reseau_hist)
    U_fin = res.U_reseau_hist[-1]
    U_nom = 400.0
    print("\n" + "=" * 72)
    print(f"  GROUPE ELECTROGENE  U_nom={U_nom:.0f}V")
    print(f"  {_verdict(U_min > 0.85 * U_nom)} U min pendant la sequence : {U_min:6.1f} V  ({(U_min/U_nom-1)*100:+.1f}%)")
    print(f"       U finale                    : {U_fin:6.1f} V")
    print("=" * 72)

    for name, w in res.winches.items():
        sens_txt = "MONTEE" if w.direction == 1 else "DESCENTE"
        print(f"\n  --- TREUIL {name}  (charge {w.load_frac*100:.0f}%, sens {sens_txt}) " + "-" * (25 - len(name)))
        print(f"  Caracteristiques : Cmax={w.motor.Cmax:.0f} N.m | In={w.motor.In_stator:.0f} A | "
              f"J={w.motor.J_total:.0f} kg.m2 | {len(w.motor.R2_ext_gradins)} gradins")
        print(f"  Dynamique finale : {w.hist['N_rpm'][-1]:6.1f} rpm | I1 max={max(w.hist['I1']):6.1f} A "
              f"(I1 brut avec transitoire max={max(w.hist['I1_brut']):6.1f} A) | C max={max(w.hist['C']):6.0f} N.m")

        # Pics de courant a chaque commutation de gradin -- demande explicite 2026-09-18.
        if w.commutations:
            print(f"  Commutations de gradin ({len(w.commutations)}) -- pic de courant estime a chaque bascule :")
            for t_c, saut, pic in w.commutations:
                ratio_in = pic / max(w.motor.In_stator, 1e-6)
                alerte = " !!" if ratio_in > 3.0 else ("  !" if ratio_in > 2.0 else "")
                print(f"    t={t_c:5.2f}s : saut +{saut:6.1f} A -> pic estime {pic:6.1f} A "
                      f"({ratio_in:.1f}x In){alerte}")

        # Regime generatrice : couple electromagnetique de signe oppose au sens de commande
        # (dans le repere N_rel, cela correspond a C_motor negatif) -- freinage electrique,
        # la charge entraine le moteur au lieu que le moteur entraine la charge.
        idx_gen = [i for i, c in enumerate(w.hist["C"]) if c < 0]
        if idx_gen:
            t_gen_debut = w.hist["t"][idx_gen[0]]
            print(f"  [GENERATRICE] freinage electrique detecte a partir de t={t_gen_debut:.2f}s "
                  f"-- {len(idx_gen)}/{len(w.hist['t'])} pas de temps concernes")
        print()
        print("  RISQUE                      VERDICT   DETAIL")
        print("  " + "-" * 68)

        def ligne(label: str, ok: bool, detail: str):
            print(f"  {label:<34}{_verdict(ok)}     {detail}")

        ok_mecanique = not w.ever_stalled
        detail = f"decrochage constate a t={w.stall_time:.2f}s (meme si repart ensuite)" if w.ever_stalled else "vitesse finale atteinte normalement"
        ligne("1. Blocage mecanique (cale)", ok_mecanique, detail)

        ok_thermique_relais = not w.image.tripped
        detail = f"declenchement a t={w.image.trip_time:.2f}s" if w.image.tripped else f"image {w.image.theta*100:.0f}% (seuil 100%)"
        ligne("2. Protection thermique relais", ok_thermique_relais, detail)

        ok_isolant = not w.aging.isolant_endommage
        theta_final = w.hist["theta_bobinage"][-1]
        detail = (f"depasse classe {w.insulation.classe} ({w.insulation.theta_limite_classe:.0f}C) a "
                  f"t={w.aging.isolant_endommage_time:.2f}s" if w.aging.isolant_endommage
                  else f"theta bobinage {theta_final:.0f}C / limite {w.insulation.theta_limite_classe:.0f}C")
        ligne(f"3. Isolant bobinage (classe {w.insulation.classe})", ok_isolant, detail)

        pct_vie = w.aging.pct_vie_consommee
        ok_vieillissement = pct_vie < 0.01
        ligne("4. Vieillissement isolant", ok_vieillissement,
              f"{pct_vie:.4f}% duree de vie nominale consommee (cette sequence)")

        ok_choc = not w.shock.choc_detecte
        detail = (f"couple crete a t={w.shock.choc_time:.2f}s, choc {'SEVERE (+jerk)' if w.shock.choc_severe else 'modere'}"
                  if w.shock.choc_detecte else f"couple max {max(w.hist['C']):.0f} N.m / seuil {w.gearbox.SF_choc_admissible}x nominal")
        ligne(f"5. Choc reducteur (SF {w.gearbox.SF_choc_admissible}x)", ok_choc, detail)
        print("     -> ATTENTION : le COURANT a la commutation inclut desormais un transitoire (L2/R2,")
        print("        cf. tableau des commutations ci-dessus), mais le COUPLE mecanique utilise ici reste")
        print("        quasi-statique (Kloss pur, pas de pulsation electromagnetique transitoire).")
        print("        Le choc reducteur peut donc encore etre sous-estime -- ne pas conclure OK a l'aveugle.")


def maybe_plot(res: MultiSimResult, path: str):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n(matplotlib non installe -- graphe ignore, resume texte seul)")
        return

    n_winches = len(res.winches)
    fig, axes = plt.subplots(3 + n_winches, 1, figsize=(10, 3 * (3 + n_winches)), sharex=True)

    axes[0].plot(res.t_hist, res.U_reseau_hist, color="black")
    axes[0].axhline(400, color="gray", linestyle="--", alpha=0.5, label="U nominal")
    axes[0].set_ylabel("U reseau (V)")
    axes[0].legend()

    for idx, (name, w) in enumerate(res.winches.items(), start=1):
        axes[idx].plot(w.hist["t"], w.hist["I1"], label=f"I1 {name}")
        axes[idx].set_ylabel(f"I1 {name} (A)")
        axes[idx].legend()

    ax_theta = axes[1 + n_winches]
    for name, w in res.winches.items():
        ax_theta.plot(w.hist["t"], [th * 100 for th in w.hist["theta"]], label=f"theta {name}")
    ax_theta.axhline(100, color="red", linestyle="--", alpha=0.5, label="declenchement")
    ax_theta.set_ylabel("Image thermique (%)")
    ax_theta.legend()

    ax_n = axes[2 + n_winches]
    for name, w in res.winches.items():
        ax_n.plot(w.hist["t"], w.hist["N_rpm"], label=f"N {name}")
    ax_n.set_ylabel("Vitesse (rpm)")
    ax_n.set_xlabel("Temps (s)")
    ax_n.legend()

    for ax in axes:
        ax.grid(True, alpha=0.3)

    fig.suptitle("Prototype T317 -- treuils multi-instances + protection thermique (SYNTHETIQUE, non calibre terrain)")
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    print(f"\nGraphe sauvegarde : {path}")


# ============================================================================
# Scenarios predefinis et mode rejeu d'incident
# ============================================================================

def scenario_un_treuil(load: float, gradin_times: list, t_end: float, direction: int = 1) -> tuple:
    genset = GensetParams()
    w = WinchInstance(motor=MotorParams(name="M1"), load_frac=load, gradin_times=gradin_times, direction=direction)
    return genset, [w], t_end


def scenario_deux_treuils(t_end: float = 6.0) -> tuple:
    """Demonstration de coincidence de charge : M1 demarre en charge, M2 embraye 0.5s apres
    pendant que M1 est encore en appel de courant -> chute de tension cumulee."""
    genset = GensetParams()
    m1 = WinchInstance(
        motor=MotorParams(name="M1"), load_frac=0.7,
        gradin_times=[0.0, 0.5, 1.0, 1.5],
    )
    m2 = WinchInstance(
        motor=MotorParams(name="M2"), load_frac=0.5,
        gradin_times=[0.5, 1.0, 1.5, 2.0],  # M2 embraye pendant que M1 est encore en transitoire
    )
    return genset, [m1, m2], t_end


def scenario_descente_generatrice(t_end: float = 10.0) -> tuple:
    """Demonstration du mode generatrice : descente en charge lourde, la gravite entraine
    le moteur au-dela de sa survitesse commandee -> couple de freinage electrique automatique
    (formule de Kloss impaire en glissement, aucun code special requis)."""
    genset = GensetParams()
    w = WinchInstance(
        motor=MotorParams(name="M1"), load_frac=0.85, direction=-1,
        gradin_times=[0.0, 1.0, 2.5, 4.0],
    )
    return genset, [w], t_end


def load_incident(path: str) -> tuple:
    """Charge un fichier JSON decrivant une sequence de commande terrain observee, pour rejeu.

    Format attendu :
    {
      "t_end": 8.0,
      "genset": {"U_nom": 400, "I_nom_groupe": 350},
      "winches": [
        {"name": "M1", "load_frac": 0.85, "gradin_times": [0.0, 0.4, 0.9, 1.3], "direction": 1},
        {"name": "M2", "load_frac": 0.0,  "gradin_times": [2.0, 2.4, 2.9, 3.3], "direction": -1}
      ]
    }
    "direction" est optionnel, defaut 1 (montee). -1 = descente (active le mode generatrice si
    load_frac est assez eleve pour que la gravite depasse le couple de freinage disponible).
    """
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    genset = GensetParams(**data.get("genset", {}))
    winches = [
        WinchInstance(
            motor=MotorParams(name=w["name"]),
            load_frac=w["load_frac"],
            gradin_times=w["gradin_times"],
            direction=w.get("direction", 1),
        )
        for w in data["winches"]
    ]
    return genset, winches, data.get("t_end", 8.0)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--load", type=float, default=0.9, help="[mode un treuil] Taux de charge 0.0-1.0")
    parser.add_argument("--gradin-times", type=str, default="0,0.4,0.8,1.2", help="[mode un treuil] Instants (s) de bascule gradin")
    parser.add_argument("--direction", type=int, choices=[1, -1], default=1, help="[mode un treuil] 1=montee, -1=descente (active le mode generatrice si charge lourde)")
    parser.add_argument("--t-end", type=float, default=6.0, help="Duree simulee (s)")
    parser.add_argument("--compare", action="store_true", help="[mode un treuil] Compare charge/a vide")
    parser.add_argument("--scenario", choices=["un_treuil", "deux_treuils", "descente_generatrice"], default="un_treuil", help="Scenario predefini")
    parser.add_argument("--incident", type=str, default=None, help="Chemin JSON d'un incident terrain a rejouer")
    parser.add_argument("--plot", action="store_true", help="Genere un graphe PNG")
    parser.add_argument("--out", type=str, default="sim_treuil_electrique.png", help="Chemin du graphe")
    args = parser.parse_args()

    if args.incident:
        print(f"=== Rejeu incident : {args.incident} ===")
        genset, winches, t_end = load_incident(args.incident)
        res = simulate_multi(genset, winches, t_end)
        print_summary(res)
    elif args.scenario == "deux_treuils":
        print("=== Scenario : M1 en charge (70%) + M2 embraye pendant le transitoire de M1 ===")
        genset, winches, t_end = scenario_deux_treuils(args.t_end)
        res = simulate_multi(genset, winches, t_end)
        print_summary(res)
    elif args.scenario == "descente_generatrice":
        print("=== Scenario : descente en charge lourde (mode generatrice) ===")
        genset, winches, t_end = scenario_descente_generatrice(args.t_end)
        res = simulate_multi(genset, winches, t_end)
        print_summary(res)
    else:
        gradin_times = [float(x) for x in args.gradin_times.split(",")]
        if args.compare:
            print(f"=== Charge {args.load*100:.0f}% ===")
            genset, winches, t_end = scenario_un_treuil(args.load, gradin_times, args.t_end, args.direction)
            res_charge = simulate_multi(genset, winches, t_end)
            print_summary(res_charge)
            print("\n=== A vide ===")
            genset2, winches2, _ = scenario_un_treuil(0.0, gradin_times, args.t_end, args.direction)
            res_vide = simulate_multi(genset2, winches2, t_end)
            print_summary(res_vide)
            res = res_charge  # pour le plot, on trace le cas charge
        else:
            genset, winches, t_end = scenario_un_treuil(args.load, gradin_times, args.t_end, args.direction)
            res = simulate_multi(genset, winches, t_end)
            print_summary(res)

    if args.plot:
        maybe_plot(res, args.out)

    print(
        "\nRAPPEL : tous les parametres moteur/genset/thermique sont SYNTHETIQUES (non mesures terrain)."
        " Voir DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md."
        " Ce script est un prototype d'exploration, pas un modele qualifie."
    )


if __name__ == "__main__":
    main()
