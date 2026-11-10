# T154 — Couverture AF / Fonctions / TC / Tests CI

> Export déterministe DOC-only. Sources : AF actives, matrice fraîche et `registry.yaml`.
> `✅ CI` = ID trouvé dans un titre `TEST` d'un fichier référencé par le registre ; `🟡` = couverture explicitement hors CI.

## Matrice fonctionnelle

| AF | Fonction | TC couvrants | Couverture |
|---|---|---|---|
| AF-01 | `F01.01` | `TC-P01-001` | TC-P01-001 🟡 SITE |
| AF-01 | `F01.02` | `TC-P01-002` | TC-P01-002 ✅ CI |
| AF-01 | `F01.03` | `TC-P01-003`, `TC-P01-005` | TC-P01-003 ✅ CI<br>TC-P01-005 🟡 Hors CI (registre) |
| AF-01 | `F01.04` | `TC-P01-004`, `TC-P01-009` | TC-P01-004 ✅ CI<br>TC-P01-009 ✅ CI |
| AF-01 | `F01.05` | `TC-P01-006` | TC-P01-006 ✅ CI |
| AF-01 | `F01.06` | `TC-P01-007` | TC-P01-007 ✅ CI |
| AF-01 | `F01.07` | `TC-P01-008` | TC-P01-008 ✅ CI |
| AF-01 | `F01.08` | `TC-P01-010` | TC-P01-010 ✅ CI |
| AF-02 | `F02.01` | `TC-P02-004` | TC-P02-004 ❌ absent |
| AF-02 | `F02.02` | `TC-P02-002` | TC-P02-002 ❌ absent |
| AF-02 | `F02.03` | `TC-P02-001` | TC-P02-001 ❌ absent |
| AF-02 | `F02.04` | `TC-P02-003` | TC-P02-003 ❌ absent |
| AF-02 | `F02.05` | `TC-P02-004` | TC-P02-004 ❌ absent |
| AF-02 | `F02.06` | `TC-P02-005` | TC-P02-005 ❌ absent |
| AF-06 | `F06.01` | `TC-P06-007` | TC-P06-007 ❌ absent |
| AF-08 | `F08.01` | `TC-P08-010` | TC-P08-010 ❌ absent |
| AF-08 | `F08.02` | `TC-P08-010` | TC-P08-010 ❌ absent |
| AF-08 | `F08.03` | `TC-P08-020` | TC-P08-020 ❌ absent |
| AF-08 | `F08.04` | `TC-P08-020` | TC-P08-020 ❌ absent |
| AF-08 | `F08.05` | `TC-P08-030` | TC-P08-030 ❌ absent |
| AF-08 | `F08.06` | `TC-P08-040` | TC-P08-040 ❌ absent |
| AF-08 | `F08.07` | `TC-P08-050` | TC-P08-050 ❌ absent |
| AF-08 | `F08.08` | `TC-P08-060` | TC-P08-060 ❌ absent |
| AF-09 | `F09.01` | `TC-P09-010` | TC-P09-010 ✅ CI |
| AF-09 | `F09.02` | `TC-P09-020` | TC-P09-020 ❌ absent |
| AF-09 | `F09.03` | `TC-P09-020` | TC-P09-020 ❌ absent |
| AF-09 | `F09.04` | `TC-P09-030` | TC-P09-030 ❌ absent |
| AF-09 | `F09.05` | `TC-P09-030` | TC-P09-030 ❌ absent |
| AF-09 | `F09.06` | `TC-P09-040` | TC-P09-040 ❌ absent |
| AF-09 | `F09.07` | `TC-P09-050` | TC-P09-050 ✅ CI |
| AF-10 | `F10.01` | `TC-P10-011` | TC-P10-011 ✅ CI |
| AF-10 | `F10.02` | `TC-P10-001` | TC-P10-001 ✅ CI |
| AF-10 | `F10.03` | `TC-P10-014` | TC-P10-014 ❌ absent |
| AF-10 | `F10.04` | `TC-P10-012` | TC-P10-012 ❌ absent |
| AF-10 | `F10.05` | `TC-P10-023` | TC-P10-023 ✅ CI |
| AF-10 | `F10.06` | — | ❌ Sans TC |
| AF-10 | `F10.07` | — | ❌ Sans TC |
| AF-10 | `F10.08` | — | ❌ Sans TC |
| AF-10 | `F10.09` | — | ❌ Sans TC |
| AF-11 | `F11.01` | `TC-P11-001` | TC-P11-001 ✅ CI |
| AF-11 | `F11.02` | `TC-P11-002` | TC-P11-002 ❌ absent |
| AF-11 | `F11.03` | `TC-P11-003` | TC-P11-003 ❌ absent |
| AF-11 | `F11.04` | `TC-P11-006` | TC-P11-006 ❌ absent |
| AF-11 | `F11.05` | — | ❌ Sans TC |
| AF-12 | `F12.01` | `TC-P12-010` | TC-P12-010 ✅ CI |
| AF-12 | `F12.02` | `TC-P12-010` | TC-P12-010 ✅ CI |
| AF-12 | `F12.03` | `TC-P12-050` | TC-P12-050 ❌ absent |

## Écarts à traiter

### Fonctions sans TC
- ❌ AF-10 F10.06
- ❌ AF-10 F10.07
- ❌ AF-10 F10.08
- ❌ AF-10 F10.09
- ❌ AF-11 F11.05

### TC non trouvés dans les tests CI déclarés
- ❌ AF-02 F02.01 → TC-P02-004
- ❌ AF-02 F02.02 → TC-P02-002
- ❌ AF-02 F02.03 → TC-P02-001
- ❌ AF-02 F02.04 → TC-P02-003
- ❌ AF-02 F02.05 → TC-P02-004
- ❌ AF-02 F02.06 → TC-P02-005
- ❌ AF-06 F06.01 → TC-P06-007
- ❌ AF-08 F08.01 → TC-P08-010
- ❌ AF-08 F08.02 → TC-P08-010
- ❌ AF-08 F08.03 → TC-P08-020
- ❌ AF-08 F08.04 → TC-P08-020
- ❌ AF-08 F08.05 → TC-P08-030
- ❌ AF-08 F08.06 → TC-P08-040
- ❌ AF-08 F08.07 → TC-P08-050
- ❌ AF-08 F08.08 → TC-P08-060
- ❌ AF-09 F09.02 → TC-P09-020
- ❌ AF-09 F09.03 → TC-P09-020
- ❌ AF-09 F09.04 → TC-P09-030
- ❌ AF-09 F09.05 → TC-P09-030
- ❌ AF-09 F09.06 → TC-P09-040
- ❌ AF-10 F10.03 → TC-P10-014
- ❌ AF-10 F10.04 → TC-P10-012
- ❌ AF-11 F11.02 → TC-P11-002
- ❌ AF-11 F11.03 → TC-P11-003
- ❌ AF-11 F11.04 → TC-P11-006
- ❌ AF-12 F12.03 → TC-P12-050

## Limites explicites

- Le rapport ne prétend pas prouver l'exécution d'un test : il vérifie la traçabilité déclarée AF → TC → titre de test enregistré.
- Les preuves SITE restent hors CI ; elles doivent être qualifiées terrain.
- Les exceptions `af_ignore` du registre sont visibles comme `Hors CI (registre)`, jamais masquées.
