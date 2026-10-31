# -*- coding: utf-8 -*-
"""T423_TC01_sim_emergency_banner — Test stimulus chaîne AU et guidage opérateur.

Scénario :
  1. Lecture initiale (Power ON).
  2. Injection SimChainOk := FALSE (1.0 s).
  3. Vérification de la bascule vers '[PUPITRE] Boucle urgence ouverte - réarmer'.
  4. Restauration de la chaîne physique (SimChainOk := TRUE).
  5. Réarmement automatique de la puissance (BtnEmergencyArming) pour laisser la machine au repos.

A exécuter dans CODESYS : Tools > Scripting > Execute Script File...
"""

import os
import time

ENGINE_PATH = os.path.join(os.path.dirname(__file__), "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())

online_app = get_online_app()
if online_app is not None:
    with online_app:
        print("\n>>> Demarrage T423_TC01_sim_emergency_banner ...")
        
        # 1. Avant
        b_before = read_banner(online_app)
        print_banner("1. AVANT TEST", b_before)

        injected = False
        try:
            # 2. Injection
            print("\n--- INJECTION : GVL_Simulation.SimChainOk := FALSE ---")
            write_var(online_app, "GVL_Simulation.SimChainOk", "FALSE")
            injected = True
            time.sleep(1.0)

            # 3. Pendant
            b_during = read_banner(online_app)
            print_banner("2. PENDANT LE STIMULUS", b_during)
            
            act_text = str(b_during.get("GVL_IHM.Banner.OperatorActionText", ""))
            if "Boucle urgence" in act_text or "PUPITRE" in act_text:
                print("\n>>> VERDICT TC01 : [PASS] Bascule reactive confirmee : " + act_text)
            else:
                print("\n>>> VERDICT TC01 : [FAIL] Texte inattendu : " + act_text)

        finally:
            if injected:
                # 4. Restauration & Réarmement
                print("\n--- RESTAURATION & REARMEMENT AUTOMATIQUE ---")
                rearm_emergency(online_app)

        # 5. Après
        b_after = read_banner(online_app)
        print_banner("3. APRES REARMEMENT COMPLET", b_after)
        print("[OK] Test TC01 termine : machine restauree au nominal.")
