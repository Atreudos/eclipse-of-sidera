#!/usr/bin/env python3
"""Geçici (placeholder) ses efektlerini sıfırdan üretir -> assets/sfx/*.wav
Çalıştırma:  python3 tools/make_sfx.py
Sadece standart kütüphane kullanır. Sayıları değiştirip tekrar çalıştırarak sesleri ayarlayabilirsin.
Gerçek sesler gelince aynı dosya adlarıyla üzerine yazman yeterli.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
random.seed(7)


def write(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / top * peak)) * 32767)) for s in samples
    )
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def render(seconds, fn):
    n = int(seconds * SR)
    return [fn(i / SR, i) for i in range(n)]


def noise():
    return random.uniform(-1.0, 1.0)


def decay(t, tau):
    return math.exp(-t / tau)


def attack(t, a=0.0008):
    return min(1.0, t / a)


def sine(f, t):
    return math.sin(2.0 * math.pi * f * t)


class Lowpass:
    def __init__(self):
        self.y = 0.0

    def __call__(self, x, alpha):
        self.y += alpha * (x - self.y)
        return self.y


def parry():
    # Keskin metalik "ting": gürültü tıkı + uyumsuz tonlar + alçak bir tok vuruş
    partials = [(1568, 1.0, 0.16), (2350, 0.7, 0.12), (3136, 0.55, 0.09), (4700, 0.3, 0.05), (1046, 0.5, 0.2)]

    def f(t, _i):
        s = noise() * decay(t, 0.004) * 0.9
        for freq, amp, tau in partials:
            s += amp * sine(freq, t) * decay(t, tau)
        s += sine(95, t) * decay(t, 0.07) * 0.9
        return s * attack(t)

    return render(0.55, f)


def hit():
    lp = Lowpass()

    def f(t, _i):
        s = lp(noise(), 0.35) * decay(t, 0.05) * 1.2
        s += sine(170, t) * decay(t, 0.05) + sine(85, t) * decay(t, 0.08) * 0.7
        return s * attack(t)

    return render(0.22, f)


def hurt():
    phase = [0.0]

    def f(t, _i):
        freq = 260.0 - 180.0 * min(t / 0.3, 1.0)
        phase[0] += 2.0 * math.pi * freq / SR
        saw = (phase[0] / math.pi) % 2.0 - 1.0
        s = (saw * 0.6 + math.sin(phase[0]) * 0.4) * decay(t, 0.16)
        s += noise() * decay(t, 0.03) * 0.8
        return s * attack(t)

    return render(0.4, f)


def dash():
    lp = Lowpass()
    dur = 0.2

    def f(t, _i):
        env = math.sin(math.pi * min(t / dur, 1.0)) ** 1.5
        alpha = 0.04 + 0.5 * (t / dur)
        return lp(noise(), alpha) * env * 2.0

    return render(dur, f)


def whiff():
    lp = Lowpass()

    def f(t, _i):
        freq = 150.0 - 60.0 * min(t / 0.18, 1.0)
        s = sine(freq, t) * decay(t, 0.06) + lp(noise(), 0.15) * decay(t, 0.05) * 0.5
        return s * attack(t, 0.002)

    return render(0.2, f)


def shoot():
    phase = [0.0]

    def f(t, _i):
        freq = 900.0 - 650.0 * min(t / 0.12, 1.0)
        phase[0] += 2.0 * math.pi * freq / SR
        sq = 1.0 if math.sin(phase[0]) > 0 else -1.0
        return (sq * 0.5 + math.sin(phase[0]) * 0.5) * decay(t, 0.05) * attack(t)

    return render(0.16, f)


def kill():
    lp = Lowpass()
    phase = [0.0]

    def f(t, _i):
        freq = 320.0 - 260.0 * min(t / 0.3, 1.0)
        phase[0] += 2.0 * math.pi * freq / SR
        s = math.sin(phase[0]) * decay(t, 0.12) + lp(noise(), 0.4) * decay(t, 0.07) * 1.1
        return s * attack(t)

    return render(0.38, f)


def tell_gold():
    # Parry'lenebilir uyarı: yumuşak iki notalı çın
    def f(t, _i):
        freq = 988.0 if t < 0.07 else 1319.0
        return (sine(freq, t) + 0.3 * sine(freq * 2.0, t)) * decay(t % 0.07, 0.05) * attack(t, 0.002) * 0.6

    return render(0.16, f)


def tell_red():
    # Parry'lenemez uyarı: alçak, tehditkâr vızıltı
    def f(t, _i):
        vib = 1.0 + 0.03 * sine(28, t)
        saw = (t * 110.0 * vib) % 1.0 * 2.0 - 1.0
        return (saw * 0.7 + sine(110 * vib, t) * 0.4) * (1.0 - t / 0.24) * attack(t, 0.004) * 0.8

    return render(0.24, f)


def slash():
    lp = Lowpass()
    dur = 0.13

    def f(t, _i):
        env = math.sin(math.pi * min(t / dur, 1.0))
        return lp(noise(), 0.25 + 0.4 * (t / dur)) * env * 1.4

    return render(dur, f)


if __name__ == "__main__":
    for name, gen in [
        ("parry", parry), ("hit", hit), ("hurt", hurt), ("dash", dash), ("whiff", whiff),
        ("shoot", shoot), ("kill", kill), ("tell_gold", tell_gold), ("tell_red", tell_red), ("slash", slash),
    ]:
        write(name, gen())
        print("yazıldı:", name + ".wav")
