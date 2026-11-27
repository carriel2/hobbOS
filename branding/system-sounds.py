#!/usr/bin/env python3
"""Gera o tema de sons do hobbOS (arte original, sintetizada do zero).

Sons curtos de sininho na mesma "família" do som de inicialização: erro, aviso,
informação, pergunta, pendrive conectado/removido, notificação e desligar.
Saem no formato do tema de sons freedesktop (índice + pasta stereo/), que o
libcanberra usa nos diálogos do GTK. Só usa a biblioteca padrão do Python.

Uso: branding/system-sounds.py PASTA_DO_TEMA   (ex.: .../usr/share/sounds/hobbos)
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 32000


def nota(nome):
    """'C5' ou 'F#4' -> frequência em Hz (lá 440)."""
    base = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}[nome[0]]
    if "#" in nome:
        base += 1
    return 440.0 * 2 ** ((base + 12 * (int(nome[-1]) - 4)) / 12)


class Mix:
    def __init__(self, dur):
        self.n = int(dur * RATE)
        self.l = [0.0] * self.n
        self.r = [0.0] * self.n

    def soma(self, ini, amostras, pan=0.5, ganho=1.0):
        i0 = int(ini * RATE)
        for k, v in enumerate(amostras):
            if i0 + k >= self.n:
                break
            self.l[i0 + k] += v * ganho * (1 - pan)
            self.r[i0 + k] += v * ganho * pan

    def eco(self, atraso=0.12, fb=0.25):
        a = int(atraso * RATE)
        for k in range(a, self.n):
            self.l[k] += fb * self.r[k - a]
            self.r[k] += fb * self.l[k - a]

    def salva(self, caminho, pico_db=-4.0):
        pico = max(max(map(abs, self.l)), max(map(abs, self.r))) or 1.0
        g = 10 ** (pico_db / 20) / pico
        fade = int(0.04 * RATE)
        random.seed(11)
        out = bytearray()
        for k in range(self.n):
            f = min(1.0, (self.n - k) / fade)
            for v in (self.l[k], self.r[k]):
                x = v * g * f + random.uniform(-1, 1) / 32768
                out += struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767))
        with wave.open(caminho, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(bytes(out))


def sino(freq, dur, decai=1.0, brilho=1.0):
    """Sininho: parciais com decaimento exponencial (os agudos somem antes)."""
    parciais = [(1.0, 1.0, 3.0), (2.0, 0.45 * brilho, 4.5), (3.01, 0.2 * brilho, 6.5), (4.2, 0.08 * brilho, 9.0)]
    out = []
    for k in range(int(dur * RATE)):
        t = k / RATE
        at = min(1.0, t / 0.004)
        out.append(at * sum(a * math.exp(-t * d * decai) * math.sin(2 * math.pi * freq * m * t)
                            for m, a, d in parciais))
    return out


def grave(freq, dur):
    """Nota grave e "abafada" (onda meio quadrada filtrada), para o erro."""
    out, y = [], 0.0
    for k in range(int(dur * RATE)):
        t = k / RATE
        x = math.tanh(3 * math.sin(2 * math.pi * freq * t))
        y += 0.08 * (x - y)  # passa-baixa simples
        out.append(y * math.exp(-t * 5) * min(1.0, t / 0.005))
    return out


def pad(freq, dur, ataque=0.05):
    out = []
    for k in range(int(dur * RATE)):
        t = k / RATE
        env = min(1.0, t / ataque) * max(0.0, min(1.0, (dur - t) / (dur * 0.7)))
        out.append(env * (math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 1.004 * t)))
    return out


def sons():
    s = {}

    m = Mix(0.75)  # erro: duas notas graves descendo
    m.soma(0.0, grave(nota("E3"), 0.35), 0.45)
    m.soma(0.0, sino(nota("E5"), 0.35, decai=2, brilho=0.4), 0.45, 0.25)
    m.soma(0.16, grave(nota("C3"), 0.55), 0.55)
    m.soma(0.16, sino(nota("C5"), 0.5, decai=2, brilho=0.4), 0.55, 0.25)
    s["dialog-error"] = m

    m = Mix(0.9)  # aviso: um "ding" só
    m.soma(0.0, sino(nota("A4"), 0.9, decai=1.2), 0.5)
    m.soma(0.0, sino(nota("E5"), 0.9, decai=1.6, brilho=0.5), 0.5, 0.35)
    m.eco(0.13, 0.2)
    s["dialog-warning"] = m

    m = Mix(0.8)  # informação: duas notas subindo, suaves
    m.soma(0.0, sino(nota("C5"), 0.6, decai=1.6, brilho=0.6), 0.4)
    m.soma(0.11, sino(nota("G5"), 0.65, decai=1.6, brilho=0.6), 0.6)
    m.eco(0.12, 0.2)
    s["dialog-information"] = m

    m = Mix(0.8)  # pergunta: subindo com "interrogação" no fim
    m.soma(0.0, sino(nota("G4"), 0.5, decai=1.8, brilho=0.6), 0.4)
    m.soma(0.12, sino(nota("D5"), 0.6, decai=1.6, brilho=0.6), 0.6)
    m.soma(0.24, sino(nota("F#5"), 0.5, decai=2.0, brilho=0.5), 0.5, 0.7)
    s["dialog-question"] = m

    m = Mix(0.7)  # pendrive conectado: "plim" subindo
    for i, nm in enumerate(("C5", "E5", "G5", "C6")):
        m.soma(i * 0.06, sino(nota(nm), 0.45, decai=2.2), 0.3 + 0.13 * i, 0.8)
    m.eco(0.1, 0.18)
    s["device-added"] = m

    m = Mix(0.7)  # pendrive removido: descendo
    for i, nm in enumerate(("C6", "G5", "E5", "C5")):
        m.soma(i * 0.06, sino(nota(nm), 0.45, decai=2.2), 0.7 - 0.13 * i, 0.8)
    m.eco(0.1, 0.18)
    s["device-removed"] = m

    m = Mix(0.6)  # notificação: "plin" agudo
    m.soma(0.0, sino(nota("D6"), 0.5, decai=2.4), 0.45)
    m.soma(0.07, sino(nota("A6"), 0.45, decai=2.8, brilho=0.6), 0.55, 0.6)
    s["message-new-instant"] = m

    m = Mix(2.6)  # desligar: o acorde da inicialização, descendo e apagando
    for i, nm in enumerate(("D6", "G5", "E5", "C5")):
        m.soma(i * 0.16, sino(nota(nm), 2.0, decai=0.9), 0.65 - 0.1 * i, 0.9)
    for nm, g in (("C3", 0.22), ("G3", 0.16), ("E4", 0.10)):
        m.soma(0.0, pad(nota(nm), 2.4, ataque=0.4), 0.5, g)
    m.eco(0.21, 0.28)
    s["desktop-logout"] = m
    return s


INDEX = """[Sound Theme]
Name=hobbOS
Comment=Sons do hobbOS, sintetizados por branding/system-sounds.py
Inherits=freedesktop
Directories=stereo

[stereo]
OutputProfile=stereo
"""

if __name__ == "__main__":
    pasta = sys.argv[1]
    os.makedirs(os.path.join(pasta, "stereo"), exist_ok=True)
    with open(os.path.join(pasta, "index.theme"), "w") as f:
        f.write(INDEX)
    for nome, mix in sons().items():
        mix.salva(os.path.join(pasta, "stereo", nome + ".wav"))
        print("gerado:", nome)
