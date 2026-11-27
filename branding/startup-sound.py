#!/usr/bin/env python3
"""Gera o som de inicialização do hobbOS (arte original, sintetizada do zero).

Um acorde suave que cresce (pad) com um arpejo de "sininhos" por cima e um eco
que alterna entre os lados. Só usa a biblioteca padrão do Python.

Uso: branding/startup-sound.py SAIDA.wav
"""
import math
import random
import struct
import sys
import wave

RATE = 32000
DUR = 4.2
N = int(RATE * DUR)


def nota(nome):
    """'C4' -> frequência em Hz (lá 440)."""
    idx = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}[nome[0]]
    return 440.0 * 2 ** ((idx + 12 * (int(nome[-1]) - 4)) / 12)


esq = [0.0] * N
dir_ = [0.0] * N


def soma(buf, inicio, amostras, ganho):
    i0 = int(inicio * RATE)
    for k, v in enumerate(amostras):
        if i0 + k >= N:
            break
        buf[i0 + k] += v * ganho


def pad(freq, inicio, dur, vol):
    """Nota de fundo: senoides levemente desafinadas, ataque e saída lentos."""
    n = int(dur * RATE)
    out = []
    for k in range(n):
        t = k / RATE
        env = min(1.0, t / 0.9) * min(1.0, (dur - t) / 1.4)
        v = (math.sin(2 * math.pi * freq * t)
             + 0.6 * math.sin(2 * math.pi * freq * 1.003 * t + 1.0)
             + 0.25 * math.sin(2 * math.pi * freq * 2.001 * t))
        out.append(v * max(env, 0.0) * vol)
    return out


def sino(freq, dur, vol):
    """Sininho: parciais com decaimento exponencial, os agudos somem antes."""
    n = int(dur * RATE)
    parciais = [(1.0, 1.0, 2.2), (2.0, 0.45, 3.5), (3.01, 0.22, 5.0), (4.2, 0.10, 7.0)]
    out = []
    for k in range(n):
        t = k / RATE
        ataque = min(1.0, t / 0.006)
        v = sum(a * math.exp(-t * d) * math.sin(2 * math.pi * freq * m * t)
                for m, a, d in parciais)
        out.append(v * ataque * vol)
    return out


# Acorde de fundo (Dó com sétima e nona maiores) e uma quinta grave
for nome, vol in [("C3", 0.20), ("G3", 0.16), ("E4", 0.12), ("B4", 0.08), ("D5", 0.06)]:
    p = pad(nota(nome), 0.0, 3.9, vol)
    soma(esq, 0.0, p, 1.0)
    soma(dir_, 0.0, p, 1.0)

# Arpejo subindo, alternando de lado, e um acorde final de sinos
arpejo = [("G4", 0.10), ("C5", 0.28), ("E5", 0.46), ("G5", 0.64), ("D6", 0.86)]
for i, (nome, ini) in enumerate(arpejo):
    s = sino(nota(nome), 2.6, 0.30)
    lado = 0.75 if i % 2 else 0.35
    soma(esq, ini, s, 1.0 - lado)
    soma(dir_, ini, s, lado)
for nome in ("C5", "E5", "B5"):
    s = sino(nota(nome), 3.0, 0.16)
    soma(esq, 1.25, s, 0.5)
    soma(dir_, 1.25, s, 0.5)

# Eco pingue-pongue
atraso = int(0.21 * RATE)
for k in range(atraso, N):
    esq[k] += 0.32 * dir_[k - atraso]
    dir_[k] += 0.32 * esq[k - atraso]

# Normaliza a -3 dB, fade-out no fim e um pouquinho de dither
pico = max(max(abs(v) for v in esq), max(abs(v) for v in dir_))
ganho = 0.707 / pico
fade = int(0.5 * RATE)
random.seed(7)
frames = bytearray()
for k in range(N):
    f = min(1.0, (N - k) / fade)
    for v in (esq[k], dir_[k]):
        x = v * ganho * f + random.uniform(-1, 1) / 32768
        frames += struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767))

with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(bytes(frames))
