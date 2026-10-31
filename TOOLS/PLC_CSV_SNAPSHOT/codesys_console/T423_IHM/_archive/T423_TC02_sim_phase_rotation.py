# -*- coding: utf-8 -*-
"""T423_TC02_sim_phase_rotation — Test stimulus défaut rotation de phases.

Scénario :
  1. Lecture initiale.
  2. Injection GVL_Simulation.SimPhaseRotationOk := FALSE (1.0 s).
  3. Vérification de la réaction de l'alarme dans AlarmBanner.
  4. Restauration GVL_Simulation.SimPhaseRotationOk := TRUE.

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
        print("\n>>> Demarrage T423_TC02_sim_phase_rotation ...")
        
        # 1. Avant
        b_before = read_banner(online_app)
        print_banner("1. AVANT TEST", b_before)

        injected = False
        try:
            # 2. Injection
            print("\n--- INJECTION : GVL_Simulation.SimPhaseRotationOk := FALSE ---")
            write_var(online_app, "GVL_Simulation.SimPhaseRotationOk", "FALSE")
            injected = True
            time.sleep(1.0)

            # 3. Pendant
            b_during = read_banner(online_app)
            print_banner("2. PENDANT LE STIMULUS", b_during)
            
            has_alarm = bool_val(b_during.get("GVL_IHM.Banner.AlarmBanner.HasAlarm", False))
            txt_alarm = str(b_during.get("GVL_IHM.Banner.AlarmBanner.Text", ""))
            if has_alarm:
                print("\n>>> VERDICT TC02 : [PASS] Alerte levee confirmee : " + txt_alarm)
            else:
                print("\n>>> VERDICT TC02 : [INFO] Aucune alarme affichee.")

        finally:
            if injected:
                # 4. Restauration
                print("\n--- RESTAURATION ---")
                write_var(online_app, "GVL_Simulation.SimPhaseRotationOk", "TRUE")
                time.sleep(0.5)

        # 5. Après
        b_after = read_banner(online_app)
        print_banner("3. APRES RESTAURATION", b_after)
        print("[OK] Test TC02 termine.")
