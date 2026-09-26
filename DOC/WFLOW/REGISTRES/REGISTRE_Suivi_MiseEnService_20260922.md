# 🧾 Mise en service — Journal du 22/09/2026 (Essais Cycle & Treuils)

> **Date :** 2026-09-22  
> **Branche / Commits :** `main`  
> **Contexte :** Passage sur l'alimentation électrique définitive du réseau. Campagne d'essais en cycle semi-auto et recherche des blocages réels en conditions de dragage.

---

## 1. Faits marquants & Constats terrain

| Heure / Réf | Système / Étape | Problème constaté | Diagnostic établi | Action engagée |
|---|---|---|---|---|
| Matin | **Treuils M1/M2**<br>`AX10 → AX10B → AX11` | Arrêt brutal / trou de synchronisation de ~800 ms lors de la fermeture benne au fond. M2 retombe et coupe M1. | Temporisation d'inversion `T#800ms` non créditée. Suspicion forte de croisement des retours contacteurs M1/M2. Traces `Suivi_83` / `Suivi_84` relevées. | Fiche troubleshooting dédiée + préparation de la trace d'isolation des DI. |
| 11h14 | **Benne**<br>`AX10` / Fermeture haut | Timeout [BENNE] ErrorID:03 lors de la fermeture en zone haute. | M2 doit monter par rapport à M1 pour fermer la benne. Le FDC haut physique coupait `AscentPermit` sur les deux treuils. | Tâche T387 : relaxation de la butée haute pour M2 lors d'une commande benne seule avec M1 maintenu. |
| Après-midi | **Translation M3**<br>`AX14_TRANSLATE_DUMP` | Chariot M3 bloqué à l'étape P1 en route vers la trémie. Permis 100% verts mais consigne vitesse à 0. | `ArrivalLock` dans `FB_Translation.st` s'est armé sur l'arrêt intermédiaire P1 et ne se libère pas vers la trémie. | Déblocage temporaire en MAINT_N1/N2 + cadrage T392 pour correction logicielle. |
| Fin d'après-midi | **Cycle Vidage**<br>`AX15B_DUMP_OPEN` | Lors du vidage à la trémie, une action inverse sur le joystick (tirer) provoque un saut intempestif vers `AX10_CLOSE_BUCKET`. | Régression introduite par le repli T331 (`IF DeadmanArmed AND JoystickPull THEN State := AX10`). Danger majeur : la benne suspendue à la trémie tente de fermer comme au fond de l'eau. | Décision ferme exploitant : interdiction absolue de tout saut vers AX10. Remplacement par modulation sur place AX15D ou maintien trémie. |

---

## 2. Décisions de fin de journée du 22/09

1. **Interdiction du saut AX15B ➔ AX10** : Le grafcet ne doit jamais quitter la trémie pour aller au fond ; la seule sortie de cycle est le retour à P1 via `AX18_DONE_SYNC` ou le passage en mode manuel.
2. **Priorité absolue du 23/09** :
   - Confirmer et corriger le câblage/mapping des contacteurs M1/M2.
   - Corriger le verrou `ArrivalLock` de la translation M3 à P1.
   - Sécuriser l'étape AX15B.
