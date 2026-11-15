**1 · Piège A2 / `2#00000`**

`00000` veut dire « extrême Maintenance » **et** « chaîne capteurs morte ». Câble sectionné en chaîne porte-câbles, cam engluée (boue, calcaire), capteur en condensation : le décodeur voit l'extrême, A2 coupe — chariot immobilisé en pleine voie, diagnostic « en Maintenance » faux. Impasse : dépanner exige d'approcher, A2 refuse : panne verrouillée. Si l'alim 24 V capteurs partage le fusible d'A2, un fusible sauté verrouille tout → descente en fosse pour un fil. Si A2 est câblé « sous tension = autorisé », un fil cassé bloque pour de bon. Et en mode Maintenance avec `00000` fantôme : marche à l'aveugle, seul le tampon protège. Le thermomètre inverse le fail-safe (position prouvée par absence). À réclamer au BE : came entaillée + capteur de référence, seul à `1` près du tampon — `00000` seul ne doit jamais signifier Maintenance.

**2 · Les quatre tests terrain**

- **1 :** sain — consignation, mètre, rien à redire.
- **2 :** faisable, mais chronomètre et comptage simultanés attirent l'erreur. Mieux : mètre ruban pour les 2,0 m, Hz et compteur lus à l'IHM, filmé au téléphone. Rouler libre suppose d'inhiber décodeur/A2 — pas sans périmètre écrit.
- **3 :** le dangereux. Contrôler l'entrefer = capot ouvert, souvent sous tension ; le plateau plaque en 50 ms au réarmement. Consignation stricte + jeu de cales, jamais à l'œil.
- **4 (C1) :** faux par conception. `11111 → 01111` est le premier pas de tout départ Trémie normal : le verrou coupera chaque mouvement commandé, le test ne prouvera rien. Signature à viser : `00000` sans ordre — fiable seulement avec le bit de référence du point 1. Valider : forcer `SensorsWord` sous l'outil de programmation, variateur inhibé, chariot stationnaire ; cinq minutes, zéro risque, verrou et reset éprouvés.

**3 · Frein ou variateur : cinq minutes**

1. Consigné : tourner l'hélice moteur à la main. Ça tourne → frein mort (garnitures usées, eau/huile, entrefer). Suspect classé.
2. Arrêt normal, petite vitesse : décélération lisse calée sur la cible = ramp-to-stop ; roue libre, arrêt long avec à-coup = coast.
3. Même trajectoire en E-stop (frein seul) : arrêt sec, clac, maintien = frein sain ; glisse ou reprise de flèche = frein usé/mouillé. Capot : odeur de brûlé, plateau rouillé = confirmation.

Repère : distance E-stop > arrêt normal → variateur aide, frein limite ; distances égales → frein fait tout, variateur en coast.