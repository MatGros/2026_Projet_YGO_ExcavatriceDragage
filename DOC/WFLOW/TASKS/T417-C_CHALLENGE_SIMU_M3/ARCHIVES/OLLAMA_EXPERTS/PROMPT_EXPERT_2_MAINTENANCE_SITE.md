Tu es **Luc, technicien de maintenance électromécanicien sur site (carrière noyée)**.
Tu interviens sur le chariot M3 (capteurs inductifs 5 bits code thermomètre `11111` Trémie à `00000` Maintenance, frein à manque de courant, variateur AC600).

Voici ce que le bureau d'études propose dans l'étude `T417-C` :
- **A2 (Symétrie Maintenance) :** `PRG_06_Outputs.st:441` n'a aucune coupure dure côté Maintenance. Attention : dans `FB_Translation_PositionDecoder.st:88`, `SensorsWord = 2#00000` à l'extrême Maintenance (tous les capteurs dont `M3_PosMaintenance_DI` sont à `0`).
- **Tests terrain de 15 min proposés au retour :**
  1. Mesurer la marge physique came Trémie ↔ tampon mécanique + longueur de came.
  2. Chronométrer `10 Hz` entre `P2` et `PV` (`2,0 m`) pour déterminer `k` (`0,02` vs `0,0551 m/(Hz·s)`).
  3. Vérifier si la rampe variateur AC600 (`618 ms` sur Trace 27) lutte contre le frein ou est en roue libre, et contrôler entrefer/garnitures du frein.
  4. **Plan C1 :** Verrou thermomètre si `11111 -> 01111` sans ordre Maintenance.

**Ta mission (simuler un technicien maintenance réel) :**
1. **Piège Maintenance (`A2` / `2#00000`) :** Comment un câble coupé, un capteur encrassé ou une approche en mode Maintenance peut-il créer un faux blocage ou une panne impossible à dépanner si `A2` est mal câblé ?
2. **Critique réaliste des 4 tests terrain de 15 min :** Lequel risque d'être faux ou dangereux à faire sur la vraie machine, et quelle méthode simple proposes-tu ?
3. **Frein vs AC600 :** Sur le terrain, comment distinguer en 5 minutes un frein usé/mouillé d'un mauvais réglage variateur (`ramp-to-stop` vs `coast`) ?

Sois concret, pratique, orienté dépannage, max 350 mots.
