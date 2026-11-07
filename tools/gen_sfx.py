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
random.seed(7)


def fade_in(x, n=48):
    for i in range(min(n, len(x))):
        x[i] *= i / n
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
    print(f"{name:12s} {len(data)/SR:.2f}s  {len(buf)/1024:.0f} KB")


def shot(dur, decay, tone, noise=1.0, crack=0.6):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        e = math.exp(-t * decay)
        s = noise * random.uniform(-1, 1) * e
        s += 0.7 * math.sin(2 * math.pi * tone * t) * math.exp(-t * decay * 0.6)
        s += crack * math.sin(2 * math.pi * 2600 * t) * math.exp(-t * 180)
        out.append(s)
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
    """parts: list of (start_seconds, samples)."""
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
write_wav("shot_rifle", shot(0.17, 30, 110, 1.0, 0.65))
write_wav("shot_smg", shot(0.10, 46, 170, 0.9, 0.5))
write_wav("shot_shotgun", shot(0.32, 15, 70, 1.25, 0.8))
write_wav("shot_sniper", shot(0.52, 9, 58, 1.35, 0.9))

# ---------------------------------------------------------------- feedback
write_wav("hit", sweep(1500, 1100, 0.06, 70, 0.8))
write_wav("kill", mix(0.26, [
    (0.00, sweep(880, 880, 0.08, 22, 0.9)),
    (0.09, sweep(1320, 1320, 0.14, 16, 0.9)),
]))
write_wav("hurt", mix(0.18, [
    (0.0, lowpass([math.sin(2 * math.pi * 85 * i / SR) * math.exp(-(i / SR) * 22)
                   + 0.5 * random.uniform(-1, 1) * math.exp(-(i / SR) * 30)
                   for i in range(int(SR * 0.18))], 3)),
]))
write_wav("death", sweep(320, 70, 0.65, 4.5, 0.9))

# ---------------------------------------------------------------- actions
write_wav("reload", mix(0.34, [
    (0.00, click(1500, 0.04, 110)),
    (0.13, click(900, 0.05, 90)),
    (0.22, click(2100, 0.03, 160)),
]))
write_wav("empty", click(800, 0.03, 180))
write_wav("pickup", sweep(600, 1400, 0.13, 12, 0.8))
write_wav("heal", mix(0.40, [
    (0.00, sweep(520, 520, 0.40, 5.0, 0.5)),
    (0.02, sweep(780, 780, 0.38, 5.5, 0.45)),
    (0.05, sweep(1040, 1040, 0.32, 6.5, 0.30)),
]))
write_wav("scan", sweep(300, 1800, 0.45, 3.0, 0.8, tremolo=0.15))
write_wav("zone_warn", mix(0.36, [
    (0.00, sweep(880, 880, 0.12, 14, 0.8)),
    (0.18, sweep(880, 880, 0.12, 14, 0.8)),
]))

# ---------------------------------------------------------------- movement
step = lowpass([random.uniform(-1, 1) * math.exp(-(i / SR) * 55)
                for i in range(int(SR * 0.08))], 5)
write_wav("footstep", step, peak=0.6)
