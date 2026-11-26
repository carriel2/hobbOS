#!/usr/bin/env bash
# Gera os PNGs do perfil a partir dos SVGs desta pasta.
# Precisa de rsvg-convert (pacote librsvg) e da fonte DejaVu (ttf-dejavu).
set -euo pipefail
cd "$(dirname "$0")"
P=../profile

install -d "$P/airootfs/usr/share/backgrounds/hobbos" "$P/airootfs/usr/share/pixmaps"
rsvg-convert -w 1920 -h 1080 wallpaper.svg -o "$P/airootfs/usr/share/backgrounds/hobbos/hobbos-colina.png"
install -m 644 hobbos-start.svg "$P/airootfs/usr/share/pixmaps/hobbos-start.svg"
rsvg-convert -w 640 -h 480 splash.svg -o "$P/syslinux/splash.png"
echo "PNGs gerados em $P"
