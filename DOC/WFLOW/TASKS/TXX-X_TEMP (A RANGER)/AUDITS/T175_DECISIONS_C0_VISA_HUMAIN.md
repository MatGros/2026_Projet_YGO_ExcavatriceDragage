# T175 — visas humains C0 avant patch

> Source : `CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md` · 2026-08-30
> Statut : **PENDING** — aucun patch ST des T175-01 / T175-02 avant décisions.

| Visa | Décision exacte à prendre | Options sûres à départager | Lot |
|---|---|---|---|
| V1 | Conflit axe pendant manoeuvre benne | M1_Busy entrant = arrêt/latch ; M2_Busy propre à la benne = jamais abortif. | T175-02 |
| V2 | `CoherenceLimitM` au boot | Une valeur site unique, consommée pour la cohérence position↔état ; ou retrait explicite + mise à jour AF-10. | T175-02 |
| V3 | Classe du slip M2 | SafeStop puis escalade confirmée, ou PowerCutOff immédiat. Le challenge recommande SafeStop + escalade pour éviter un faux AU à l'inertie. | T175-01 |
| V4 | Arrêt quand M1_Busy apparaît en cours de manoeuvre | Sémantique SafeStop / rampe / latch et réarmement opérateur à valider. | T175-02 |
| V5 | Interface du nouveau diagnostic slip M2 | Sortie dédiée `M2SlipDetected` recommandée, ou migration `ErrorId` en DWORD. WORD actuel : 16/16 bits consommés. | T175-01 |
| V6 | Risque cinématique câble | Note géométrie M1/M2 (offset, course, torsion) et validation terrain avant attribution d'une fonction sécurité. | T175-01/02 |
| V7 | RETAIN contre position physique au boot | Essai terrain / capteur disponible ; confirmer la procédure de re-confirmation avant reprise synchro. | T175-02 |

## Contraintes déjà décidées par les faits

- `IsOpen=TRUE` et `IsClosed=TRUE` doit être incohérent, sans `ActiveOffsetValid` ni commande.
- Le contrôle de cohérence doit avoir une sortie dédiée `BucketStateCoherent` : ne pas détourner `ActiveOffsetValid`, qui inclut aussi les défauts de benne.
- Tout refus au BusyEdge désarme `OpenReq`/`CloseReq` : aucun engagement différé.
- Une seule source décide la coupure M2 ; la détection slip doit être masquée pendant la décélération initiée par un défaut M1.
- Les TC bloquants avant clôture : inertie au lâcher joystick, boot TRUE/TRUE, divergence position↔RETAIN, M1_Busy entrant, reset sans redémarrage auto, absence de double coupure, timing multi-tâche.
