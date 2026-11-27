#!/usr/bin/env bash
# Gera os PNGs do perfil a partir dos SVGs desta pasta, e os sons do sistema.
# Precisa de rsvg-convert (pacote librsvg), da fonte DejaVu (ttf-dejavu) e de python3.
set -euo pipefail
cd "$(dirname "$0")"
P=../profile
BG=$P/airootfs/usr/share/backgrounds/hobbos

install -d "$BG" "$P/airootfs/usr/share/pixmaps" "$P/airootfs/usr/share/sounds/hobbos"
rsvg-convert -w 1920 -h 1080 wallpaper.svg -o "$BG/hobbos-colina.png"
python3 wallpaper-noite.py > wallpaper-noite.svg
for w in por-do-sol lago noite; do
  rsvg-convert -w 1920 -h 1080 "wallpaper-$w.svg" -o "$BG/hobbos-$w.png"
done
install -m 644 hobbos-start.svg "$P/airootfs/usr/share/pixmaps/hobbos-start.svg"
rsvg-convert -w 640 -h 480 splash.svg -o "$P/syslinux/splash.png"
T=$P/airootfs/usr/share/plymouth/themes/hobbos
install -d "$T"
rsvg-convert plymouth-logo.svg -o "$T/logo.png"
rsvg-convert plymouth-barra.svg -o "$T/barra.png"
rsvg-convert plymouth-bloco.svg -o "$T/bloco.png"
python3 startup-sound.py "$P/airootfs/usr/share/sounds/hobbos/inicio.wav"
python3 system-sounds.py "$P/airootfs/usr/share/sounds/hobbos"
echo "PNGs e sons gerados em $P"
