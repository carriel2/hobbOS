#!/usr/bin/env bash
# Gera os PNGs do perfil a partir dos SVGs desta pasta, e o som de inicialização.
# Precisa de rsvg-convert (pacote librsvg) e da fonte DejaVu (ttf-dejavu).
set -euo pipefail
cd "$(dirname "$0")"
P=../profile

install -d "$P/airootfs/usr/share/backgrounds/hobbos" "$P/airootfs/usr/share/pixmaps" "$P/airootfs/usr/share/sounds/hobbos"
rsvg-convert -w 1920 -h 1080 wallpaper.svg -o "$P/airootfs/usr/share/backgrounds/hobbos/hobbos-colina.png"
install -m 644 hobbos-start.svg "$P/airootfs/usr/share/pixmaps/hobbos-start.svg"
rsvg-convert -w 640 -h 480 splash.svg -o "$P/syslinux/splash.png"
T=$P/airootfs/usr/share/plymouth/themes/hobbos
install -d "$T"
rsvg-convert plymouth-logo.svg -o "$T/logo.png"
rsvg-convert plymouth-barra.svg -o "$T/barra.png"
rsvg-convert plymouth-bloco.svg -o "$T/bloco.png"
python3 startup-sound.py "$P/airootfs/usr/share/sounds/hobbos/inicio.wav"
echo "PNGs e som gerados em $P"
