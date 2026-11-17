# -*- coding: utf-8 -*-
# POC lecture persistantes : LECTURE SEULE, projet deja EN LIGNE (aucun login ici).
# A lancer dans la console CODESYS (Tools > Scripting) :
#   execfile(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\variable_lists\poc_lecture_persistante.py")
app = online.create_online_application(projects.primary.active_application)
with app:
    print("en ligne : " + str(app.is_logged_in))
    if app.is_logged_in:
        for t in ["GVL_PERSISTENT._CalibM1.Homed",
                  "GVL_PERSISTENT._CalibM1.HomingRefRaw",
                  "Device.Application.GVL_PERSISTENT._CalibM1.HomingRefRaw",
                  "GVL_PERSISTENT._CalibM1",
                  "GVL_PERSISTENT._WinchSpeedStepTable.StepThreshold_Pct[1]",
                  "GVL_PERSISTENT._WinchLoadEstimateTable.LoadPctByStepAndSpeedBand[1][1]",
                  "GVL_PERSISTENT._WinchSpeedLearnTable.Cell[1,1,1,1].Valid",
                  "GVL_PERSISTENT._WinchSpeedLearnTable.Cell[1, 1, 1, 1].Valid"]:
            try:
                print(t + " = " + str(list(app.read_values((t,)))))
            except Exception as e:
                print(t + "  ERREUR : " + str(e))
