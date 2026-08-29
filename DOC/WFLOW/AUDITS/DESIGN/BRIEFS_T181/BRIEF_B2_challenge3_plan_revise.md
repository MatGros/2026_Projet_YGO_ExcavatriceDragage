# BRIEF B2 — Challenge #3 : attaquer le plan T181 RÉVISÉ

> À COLLER TEL QUEL. Joindre : `subagent_preamble.md` + `PLAN_GEL_TREUIL_T181_CONSOLIDE.md`.
> REVUE SEULEMENT — aucun fichier modifié, aucun commit.

---

## Préambule

Lis `subagent_preamble.md` (joint). Expert Senior Automatisme CODESYS 3.5 + sécurité machine +
conduite de projet industriel. FR, concis, priorisé. **Anti-yes-man : attaque, ne valide pas.**

## Contexte

Sous-système treuil d'une excavatrice de dragage (M1 retenue + M2 benne, câble commun, benne
portée par M2). MainTask 10 ms. CI = tests unitaires STruCpp (pas de HIL, pas de banc). Code ST
appliqué **manuellement** dans CODESYS par l'humain.

Chaîne : `PRG_03` (décision cycle) → `PRG_04` (orchestration paire) → `FB_Winch` ×2 +
`FB_Safety_Winch` ×2 + `FB_WinchSync` → `PRG_06` / `FB_WinchOutputInterlock` (barrière finale).

Le plan joint (`PLAN_GEL_TREUIL_T181_CONSOLIDE.md`) est **déjà le produit de 2 challenges** :
- Challenge #1 (séquencement) → verdict BLOCK, a imposé : harness d'intégration Phase -1,
  corrections C4 **avant** refactor d'API, extraction sous-FB après interface stable,
  contrat formel d'autorité des 2 interlocks, plan FAT/rollback.
- Challenge #2 (interconnexion Grafcets/joystick/IHM) → `DriveRequest` couvre ~80 %,
  4 amendements bloquants (clamp par instance vs commun, précédence Min/Max, producteur
  `MinStepDescent` inexistant à créer, `MinStepNumber` sur la cible).

Objectif utilisateur, mot pour mot : **« un winch qui fonctionne du premier coup »** — zéro
aller-retour, zéro régression, pas de big-bang.

## Ta mission — 3ᵉ passe, sur ce qui reste

Ne répète PAS les constats des challenges 1 et 2 (ils sont intégrés). Cherche ce qu'ils ont
manqué. Points d'attaque imposés :

1. **Le phasage −1 → 0 → 0b → A → C → B → D tient-il vraiment ?**
   - Y a-t-il encore un big-bang caché ? (regarde §6 Phase A : A1→A9, chaque pas = 1 commit —
     est-ce honnête, ou A3/A5 restent-ils énormes ?)
   - Phase 0 corrige 5 défauts C4 « à interface inchangée » : est-ce réellement possible sans
     toucher l'API, ou certains fixes (D02 inversion Fwd/Rev, D07 ContactorStuck) forcent-ils déjà
     une touche d'interface ?
   - `bloque_par` : dépendances cachées non écrites ? (ex. D06 survitesse a besoin de
     `Sensors.MeasuredSpeedBand` qui n'arrive qu'en Phase A — or D06 est en Phase B/T181-16,
     `bloque_par: 10,14,15` : cohérent ?)

2. **Shadow comparison (A3/A8)** : le plan fait tourner ancien + nouveau calcul de clamp en //,
   compare, bascule. Sur une machine sécurité, MainTask 10 ms : coût CPU acceptable ? combien de
   cycles de recouvrement avant bascule ? que fait-on si un écart apparaît **après** bascule
   (rollback runtime prévu) ? le shadow masque-t-il les vecteurs jamais exercés ?

3. **Preuve `FinalInterlockGoverned = FALSE` en nominal SANS HIL** (§4) : les 4 critères
   d'acceptation proposés sont-ils suffisants pour signer une mise en service sécurité ?
   Qu'est-ce qu'un test unitaire STruCpp ne pourra jamais prouver ici ? Le « test d'injection »
   (forcer une cadence > safety en stubant l'instance FB_Winch) est-il réaliste en STruCpp ?

4. **Interconnexion — trous résiduels après challenge #2** :
   - Amendement C : créer le producteur `MinStepDescent` dans `FB_DiveSearch`. Le flux
     `FB_DiveSearch → PRG_03.ReqProgram → PRG_04 → DriveRequest` traverse 3 POU et 3 tâches :
     latence, cohérence inter-cycle, que se passe-t-il au front de sortie de plongée ?
   - Continuité gestuelle plongée (§3-C) : plancher palier 3 discret, joystick effleuré →
     montée lissée par `FB_WinchStepShaper`. Acceptable pour l'opérateur ? risque de sur-course
     benne pendant la rampe 0→3 ?
   - L'override benne (`instBucket.Busy` prend la main sur M2) : le plan dit « à ré-exprimer
     proprement, où dans la construction du DriveRequest » — mais ne tranche pas. Tranche.

5. **Ce qui manque encore** pour un premier tir réussi : mise en service, ordre d'essais site,
   rollback Git par phase, non-régression du **reste** de la machine (PRG_02/PRG_07/Troubleshooting
   consomment des diags treuil), campagne d'apprentissage charge/vide (combien de passes ?
   comment valider que la table RETAIN est « complète » ?).

6. **Sur/sous-découpage** : 20 tâches T181-00→19. Lesquelles fusionner ? scinder encore ?
   Y en a-t-il une qui est un piège (trop de surface, critère d'acceptation non mesurable) ?

7. **Verdict** : le plan révisé donne-t-il « un winch qui fonctionne du premier coup » ?
   Sinon → les **3 à 5 changements structurants** restants, priorisés.

## Restitution

FR, tableaux, `fichier:ligne` quand tu cites du code (tu peux lire `CODE/`). Sépare clairement :
faits avérés / hypothèses / incertitudes. Termine par le verdict + la liste priorisée.
Aucune écriture, aucun commit.
