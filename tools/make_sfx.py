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
    """Mono (sayı listesi) ya da stereo ((sol, sağ) çiftleri listesi) yazar. Tepe değeri `peak`e göre ölçekler."""
    stereo = bool(samples) and isinstance(samples[0], tuple)
    flat = [v for pair in samples for v in pair] if stereo else samples
    top = max(1e-9, max(abs(s) for s in flat))
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / top * peak)) * 32767)) for s in flat
    )
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2 if stereo else 1)
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
    """Zengin parry sesi (stereo, ~0.95 sn). Katmanlar:
    tık (anlık his) + tok vuruş (gövde) + metal çarpışma + çan "ting" (beşli/oktavlı, sarı-altın tını)
    + yükselen parıltı süpürmesi + hafif yankı. Pentatonik perdeyle uyumlu: oyun içinde art arda
    parry'ler perdeyi yükseltir (autoload/sfx.gd: PARRY_STEPS)."""
    rnd = random.Random(11)
    dur = 0.9
    n = int(dur * SR)
    f0 = 1318.5  # E6
    # (frekans çarpanı, genlik, sönüm süresi sn, sağ kanal faz kayması)
    bell = [
        (1.0, 0.55, 0.30, 0.0), (1.0035, 0.28, 0.34, 0.9),   # ayarsız ikiz: yavaş parıltı titreşimi
        (1.5, 0.34, 0.24, 0.5), (2.0, 0.26, 0.20, 1.3),       # beşli, oktav (uyumlu çekirdek)
        (2.76, 0.18, 0.13, 0.2), (4.07, 0.12, 0.085, 0.8),    # metalik (uyumsuz) tonlar
        (5.43, 0.08, 0.06, 1.7), (7.1, 0.05, 0.04, 0.4),
    ]
    sweep_t = 0.12
    f_a, f_b = 2200.0, 6400.0
    # tek kutuplu süzgeç durumları (sol, sağ için ayrı gürültü)
    hp_prev = [0.0, 0.0]
    hp_y = [0.0, 0.0]
    bp_lo = [0.0, 0.0]
    bp_hi = [0.0, 0.0]
    spark_hp_prev = [0.0, 0.0]
    spark_hp_y = [0.0, 0.0]
    thump_phase = 0.0
    dry = [[0.0] * n, [0.0] * n]
    send = [[0.0] * n, [0.0] * n]  # yankıya giden kısım (gürültüsüz)
    for i in range(n):
        t = i / SR
        thump_f = 55.0 + 70.0 * math.exp(-t / 0.02)
        thump_phase += 2.0 * math.pi * thump_f / SR
        thump = math.sin(thump_phase) * math.exp(-t / 0.05) * 0.9
        for ch in (0, 1):
            x = rnd.uniform(-1.0, 1.0)
            # tık: yüksek geçiren gürültü
            hp_y[ch] = 0.97 * (hp_y[ch] + x - hp_prev[ch])
            hp_prev[ch] = x
            click = hp_y[ch] * math.exp(-t / 0.0012) * 0.8
            # metal çarpışma: ~1.5-4.5 kHz bandında gürültü
            bp_lo[ch] += 0.45 * (x - bp_lo[ch])
            bp_hi[ch] += 0.12 * (x - bp_hi[ch])
            clang = (bp_lo[ch] - bp_hi[ch]) * math.exp(-t / 0.05) * 1.6
            # çan
            b = 0.0
            for mult, amp, tau, ph in bell:
                phase = ph if ch == 1 else 0.0
                b += amp * math.sin(2.0 * math.pi * f0 * mult * t + phase) * math.exp(-t / tau)
            b *= min(1.0, t / 0.0006)
            # yükselen parıltı süpürmesi (kanallara hafif kaydırılmış)
            c = 0.0
            ts = t - (0.004 if ch == 1 else 0.0)
            if 0.0 <= ts < sweep_t:
                ph_sweep = 2.0 * math.pi * (f_a * ts + 0.5 * (f_b - f_a) / sweep_t * ts * ts)
                c = math.sin(ph_sweep) * math.sin(math.pi * ts / sweep_t) ** 2 * 0.2
            # parıltı gürültüsü (>5 kHz)
            y = rnd.uniform(-1.0, 1.0)
            spark_hp_y[ch] = 0.8 * (spark_hp_y[ch] + y - spark_hp_prev[ch])
            spark_hp_prev[ch] = y
            sparkle = spark_hp_y[ch] * math.exp(-t / 0.09) * 0.28
            dry[ch][i] = click + thump * 0.8 + clang + b * 0.62 + c + sparkle
            send[ch][i] = thump * 0.5 + b * 0.62 + c
    # yankı (Schroeder/Freeverb benzeri): 4 comb + 4 allpass, sağ kanalda biraz farklı gecikmeler
    def reverb(src, spread):
        combs = [(1116 + spread, 0.80), (1188 + spread, 0.79), (1277 + spread, 0.78), (1356 + spread, 0.77)]
        aps = [556 + spread, 441 + spread, 341 + spread, 225 + spread]
        pre = int(0.006 * SR)
        comb_buf = [[0.0] * d for d, _ in combs]
        comb_pos = [0] * len(combs)
        comb_lp = [0.0] * len(combs)
        ap_buf = [[0.0] * d for d in aps]
        ap_pos = [0] * len(aps)
        out = [0.0] * len(src)
        for i in range(len(src)):
            x = src[i - pre] * 0.5 if i >= pre else 0.0
            acc = 0.0
            for k, (d, fb) in enumerate(combs):
                buf = comb_buf[k]
                v = buf[comb_pos[k]]
                comb_lp[k] += 0.5 * (v - comb_lp[k])  # yüksek frekansları söndür
                buf[comb_pos[k]] = x + comb_lp[k] * fb
                comb_pos[k] = (comb_pos[k] + 1) % d
                acc += v
            for k in range(len(aps)):
                buf = ap_buf[k]
                v = buf[ap_pos[k]]
                buf[ap_pos[k]] = acc + v * 0.5
                acc = v - acc * 0.5
                ap_pos[k] = (ap_pos[k] + 1) % len(buf)
            out[i] = acc
        return out
    wet_l = reverb(send[0], 0)
    wet_r = reverb(send[1], 23)
    out = []
    fade_n = int(0.04 * SR)
    for i in range(n):
        l = dry[0][i] + wet_l[i] * 0.16
        r = dry[1][i] + wet_r[i] * 0.16
        # hafif doygunluk: tepe değerleri yumuşatır, sesi "dolgun" yapar
        l = math.tanh(1.3 * l)
        r = math.tanh(1.3 * r)
        if i >= n - fade_n:
            f = (n - i) / fade_n
            l *= f
            r *= f
        out.append((l, r))
    return out


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
    # (ad, üretici, tepe seviyesi)
    for name, gen, peak in [
        ("parry", parry, 0.78), ("hit", hit, 0.85), ("hurt", hurt, 0.85), ("dash", dash, 0.85), ("whiff", whiff, 0.85),
        ("shoot", shoot, 0.85), ("kill", kill, 0.85), ("tell_gold", tell_gold, 0.85), ("tell_red", tell_red, 0.85),
        ("slash", slash, 0.85),
    ]:
        write(name, gen(), peak)
        print("yazıldı:", name + ".wav")
