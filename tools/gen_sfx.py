#!/usr/bin/env python3
"""Generate placeholder SFX for Island Royale.

Pure stdlib. Outputs 16-bit mono 44.1kHz WAVs.
Replace any file with a real sample of the same name.
"""
import math
import os
import random
import struct
import wave

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "audio")
os.makedirs(OUT, exist_ok=True)
random.seed(11)


def fade_in(x, n=48):
    for i in range(min(n, len(x))):
        x[i] *= i / n
    return x


def fade_out(x, n=256):
    total = len(x)
    for i in range(min(n, total)):
        x[total - 1 - i] *= i / n
    return x


def write_wav(name, data, peak=0.9):
    m = max(1e-9, max(abs(v) for v in data))
    k = peak / m
    buf = bytearray()
    for v in data:
        s = int(max(-1.0, min(1.0, v * k)) * 32767)
        buf += struct.pack("<h", s)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(buf))
    print(f"{name:14s} {len(data)/SR:.2f}s  {len(buf)/1024:.0f} KB")


def shot(dur, decay, tone, noise=1.0, crack=0.7):
    """Transient crack + noisy body + low thump + filtered tail."""
    n = int(SR * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        e = math.exp(-t * decay)
        body = noise * random.uniform(-1, 1) * e
        thump = 0.8 * math.sin(2 * math.pi * tone * t) * math.exp(-t * decay * 0.55)
        cr = crack * random.uniform(-1, 1) * math.exp(-t * 260)
        lp += (random.uniform(-1, 1) - lp) * 0.09
        tail = 0.40 * lp * math.exp(-t * 6.5)
        out.append(body + thump + cr + tail)
    return fade_in(out, 24)


def sweep(f0, f1, dur, decay, amp=1.0, tremolo=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / SR
        e = math.exp(-t * decay)
        m = 1.0 + tremolo * math.sin(2 * math.pi * 24 * t)
        out.append(amp * math.sin(phase) * e * m)
    return fade_in(out, 64)


def click(freq=1800, dur=0.035, decay=140):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        s = math.sin(2 * math.pi * freq * t) * math.exp(-t * decay)
        s += 0.5 * random.uniform(-1, 1) * math.exp(-t * decay * 1.5)
        out.append(s)
    return fade_in(out, 16)


def mix(total_dur, parts):
    n = int(SR * total_dur)
    buf = [0.0] * n
    for start, data in parts:
        off = int(start * SR)
        for i, v in enumerate(data):
            j = off + i
            if 0 <= j < n:
                buf[j] += v
    return fade_in(buf, 32)


def lowpass(data, k=4):
    out = []
    acc = 0.0
    for v in data:
        acc += (v - acc) / k
        out.append(acc)
    return out


# ---------------------------------------------------------------- weapons
write_wav("shot_rifle", shot(0.20, 26, 105, 1.0, 0.8))
write_wav("shot_smg", shot(0.12, 42, 165, 0.9, 0.6))
write_wav("shot_shotgun", shot(0.38, 13, 68, 1.25, 0.9))
write_wav("shot_sniper", shot(0.62, 8, 56, 1.35, 1.0))

# ---------------------------------------------------------------- feedback
write_wav("hit", sweep(1600, 1150, 0.06, 70, 0.8))
write_wav("kill", mix(0.26, [
    (0.00, sweep(880, 880, 0.08, 22, 0.9)),
    (0.09, sweep(1320, 1320, 0.14, 16, 0.9)),
]))
write_wav("hurt", mix(0.20, [
    (0.0, lowpass([math.sin(2 * math.pi * 82 * i / SR) * math.exp(-(i / SR) * 20)
                   + 0.55 * random.uniform(-1, 1) * math.exp(-(i / SR) * 28)
                   for i in range(int(SR * 0.20))], 3)),
]))
write_wav("death", sweep(300, 65, 0.72, 4.0, 0.9))

# ---------------------------------------------------------------- actions
write_wav("reload", mix(0.42, [
    (0.00, click(1400, 0.04, 110)),
    (0.06, lowpass([random.uniform(-1, 1) * math.exp(-(i / SR) * 40)
                    for i in range(int(SR * 0.09))], 6)),
    (0.16, click(850, 0.05, 85)),
    (0.24, sweep(2200, 1500, 0.06, 60, 0.35)),
    (0.30, click(2000, 0.03, 150)),
]))
write_wav("empty", click(760, 0.03, 180))
write_wav("pickup", sweep(600, 1450, 0.14, 11, 0.8))
write_wav("heal", mix(0.45, [
    (0.00, sweep(520, 520, 0.45, 4.2, 0.5)),
    (0.02, sweep(780, 780, 0.42, 4.8, 0.45)),
    (0.05, sweep(1040, 1040, 0.34, 6.0, 0.30)),
]))
write_wav("scan", sweep(280, 1900, 0.50, 2.6, 0.8, tremolo=0.18))
write_wav("zone_warn", mix(0.38, [
    (0.00, sweep(880, 880, 0.12, 14, 0.8)),
    (0.19, sweep(880, 880, 0.12, 14, 0.8)),
]))

# ---------------------------------------------------------------- explosion
boom = []
v = 0.0
for i in range(int(SR * 0.9)):
    t = i / SR
    v += random.uniform(-1, 1) * 0.05
    v *= 0.998
    low = math.sin(2 * math.pi * 55 * t) * math.exp(-t * 4.0) * 1.2
    rumble = v * 4.0 * math.exp(-t * 2.5)
    crack = random.uniform(-1, 1) * math.exp(-t * 22) * 0.6
    boom.append(low + rumble + crack)
write_wav("explosion", boom, peak=1.0)

# ---------------------------------------------------------------- movement
for idx in range(3):
    k = [3.0, 5.0, 7.0][idx]
    dur = [0.09, 0.08, 0.07][idx]
    step = lowpass([random.uniform(-1, 1) * math.exp(-(i / SR) * 52)
                    for i in range(int(SR * dur))], k)
    write_wav(f"footstep_{idx + 1}", step, peak=0.55)

# ---------------------------------------------------------------- ambience
wind = []
v = 0.0
for i in range(int(SR * 5.0)):
    t = i / SR
    v += random.uniform(-1, 1) * 0.02
    v *= 0.996
    amp = 0.45 + 0.35 * math.sin(2 * math.pi * 0.09 * t) + 0.20 * math.sin(2 * math.pi * 0.031 * t)
    wind.append(v * amp)
fade_in(wind, int(SR * 0.4))
fade_out(wind, int(SR * 0.4))
write_wav("ambient_wind", wind, peak=0.7)
