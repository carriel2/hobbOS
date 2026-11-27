#!/usr/bin/env python3
"""Gera branding/wallpaper-noite.svg (arte original): céu estrelado, lua e as
mesmas colinas do wallpaper principal, à noite. As estrelas saem de uma semente
fixa, então o SVG é sempre igual. Uso: branding/wallpaper-noite.py > wallpaper-noite.svg"""
import random

random.seed(1987)
estrelas = []
for _ in range(170):
    x, y = random.uniform(0, 1920), random.uniform(0, 640) ** 1.0
    r = random.choice([0.9, 1.1, 1.3, 1.6, 2.2])
    a = random.uniform(0.45, 1.0)
    estrelas.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" opacity="{a:.2f}"/>')
brilhantes = []
for x, y in [(310, 140), (980, 90), (1500, 210), (700, 300), (1760, 80)]:
    brilhantes.append(
        f'<g transform="translate({x} {y})"><path d="M0 -12 L2 -2 L12 0 L2 2 L0 12 L-2 2 L-12 0 L-2 -2 Z"/>'
        f'<circle r="2.4"/></g>')

print(f"""<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <!-- Wallpaper "Noite" do hobbOS: arte original (gerado por wallpaper-noite.py) -->
  <defs>
    <linearGradient id="ceu" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#050b26"/>
      <stop offset="0.6" stop-color="#0d2257"/>
      <stop offset="1" stop-color="#1f3f86"/>
    </linearGradient>
    <radialGradient id="lua" cx="0.4" cy="0.4" r="0.6">
      <stop offset="0" stop-color="#fffdf0"/>
      <stop offset="1" stop-color="#d9dcc4"/>
    </radialGradient>
    <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#cfe0ff" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#cfe0ff" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="morro1" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1b4a3a"/>
      <stop offset="1" stop-color="#0e2c24"/>
    </linearGradient>
    <linearGradient id="morro2" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#256148"/>
      <stop offset="1" stop-color="#123a2c"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#ceu)"/>
  <g fill="#ffffff">
    {chr(10).join('    ' + e for e in estrelas)}
  </g>
  <g fill="#fff7d6">
    {chr(10).join('    ' + b for b in brilhantes)}
  </g>
  <circle cx="1480" cy="260" r="260" fill="url(#halo)"/>
  <circle cx="1480" cy="260" r="92" fill="url(#lua)"/>
  <g fill="#c9ccb2" opacity="0.6">
    <circle cx="1450" cy="235" r="14"/><circle cx="1510" cy="290" r="10"/><circle cx="1500" cy="220" r="7"/>
  </g>
  <path d="M0 760 C 300 650 640 640 960 700 C 1280 760 1600 700 1920 640 L1920 1080 L0 1080 Z" fill="url(#morro1)"/>
  <path d="M0 860 C 420 760 860 800 1240 860 C 1520 904 1760 880 1920 850 L1920 1080 L0 1080 Z" fill="url(#morro2)"/>
  <path d="M0 900 C 420 800 860 840 1240 900" fill="none" stroke="#3f8f66" stroke-width="6" opacity="0.45"/>
</svg>""")
