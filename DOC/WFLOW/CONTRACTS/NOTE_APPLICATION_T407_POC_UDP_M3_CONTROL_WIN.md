# T407 — Liaison UDP M3 Control Win : phase 1 shadow

## Etat

**Preuve locale et shadow Control Win OK.** Aucune phase d ecriture ne suit
automatiquement ce resultat.

| Element | Etat | Preuve |
|---|---|---|
| Port UDP | OK | `127.0.0.1:29030` fixe, aucune autre adresse dans le protocole |
| Plante | OK | FMU M3 OpenModelica chargee puis reponse `M3_PlantImage` |
| Image retour | OK | 5 capteurs, frein, Hz, statut et butee dans une trame complete |
| Ecriture PLC | Interdite | le script shadow ne contient ni API d ecriture ni bit de selection |
| Mesure Control Win | OK | 138/138 reponses, 0 timeout, 0 rejet |

Test local execute le 2026-09-28 : `M3_CommandImage` sequence 0, mot 0,
0 Hz, frein ferme -> `M3_PlantImage` OpenModelica coherent. Temps de calcul
plante observe : **1,377 ms** pour cet echantillon. Ce nombre n est ni un RTT
CODESYS ni une garantie temps reel Windows.

## Resultat humain Control Win

Le script shadow a ete joue sur la copie Control Win ONLINE le 2026-09-28 :

```text
envoyees=138 reponses=138 timeout=0 rejets=0
rtt_ms p50=3.777 p95=11.047 p99=25.040 max=519.836
```

Verdict : **connectivite UDP loopback validee** ; le paquet n a subi ni perte
ni rejet. En revanche, la boucle ScriptEngine obtient environ `30 s / 138 =
217 ms` par echange effectif, avec un pic de 519,836 ms. L API ScriptEngine
est donc acceptable comme outil de probe et de diagnostic, **pas comme pont
cyclique cible a 50 ms**. Cette observation interdit de passer a une ecriture
de l image M3 sur la base de T407 seul.

## Test unique a jouer

Precondition : ouvrir **la copie TwinBench** et etre ONLINE sur **CODESYS
Control Win local**, jamais sur le PLC reel.

1. Dans PowerShell, lancer :

   ```powershell
   & 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\udp_m3_link\Start_T407_UdpPlant.ps1'
   ```

   Le lanceur attend la confirmation puis rend automatiquement la main. La
   plante tourne en arriere-plan pendant 5 minutes.

2. Dans CODESYS, `Tools > Scripting`, choisir :

   ```text
   C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_m3_udp_shadow.py
   ```

3. Le resultat attendu est : `PASS T407 SHADOW` et les deux rapports de
latence. La seule information a copier ici est la ligne `[T407] RAPPORT shadow`.

Le script CODESYS ne fait qu une lecture de `GVL_Troubleshooting` et echange des
datagrammes loopback. Il n ecrit ni dans l image OM, ni dans `SimM3...`, ni dans
une commande ou une sortie PLC.

## Apres ce test

Un nouveau contrat separera une future phase de transport plus rapide de toute
eventuelle ecriture atomique de l image M3. Cette ecriture demandera un GO
humain distinct et ne peut pas reutiliser ScriptEngine comme cadence cible.
