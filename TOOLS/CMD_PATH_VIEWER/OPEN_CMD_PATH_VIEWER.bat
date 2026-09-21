@echo off
REM ═══════════════════════════════════════════════════════════════════════════════════════════
REM  T353 — CMD_PATH_VIEWER · MODE LIVE
REM  Lance un serveur de FICHIERS statique (python -m http.server) à la racine du dépôt, puis
REM  ouvre la page. AUCUNE logique métier côté serveur : il ne fait que servir des octets.
REM  C'est ce mode qui permet au navigateur de RECALCULER les blobs SHA des fichiers cités
REM  (impossible en file://). Aucun fichier n'est écrit par ce serveur : il est en lecture seule
REM  du point de vue de l'outil (le protocole HTTP ne propose aucune écriture).
REM ═══════════════════════════════════════════════════════════════════════════════════════════
setlocal
set PORT=8765
set PAGE=http://127.0.0.1:%PORT%/TOOLS/CMD_PATH_VIEWER/index.html

REM Racine du dépôt = deux niveaux au-dessus de ce fichier .bat
pushd "%~dp0..\.."

echo ============================================================
echo  CMD_PATH_VIEWER - MODE LIVE (serveur de fichiers statique)
echo ============================================================
echo  Racine servie : %CD%
echo  Page          : %PAGE%
echo  Port          : %PORT%   (zéro logique métier côté serveur)
echo.
echo  Pour le MODE STATIQUE (sans serveur) : ouvrez directement
echo    %~dp0index.html
echo  ... les badges de fraicheur y seront FIGES et horodates.
echo.
echo  Fermez cette fenetre (ou Ctrl+C) pour arreter le serveur.
echo ============================================================
echo.

start "" "%PAGE%"
python -m http.server %PORT% --bind 127.0.0.1
popd
endlocal
