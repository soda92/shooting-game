#!/usr/bin/env python3
"""Generate layered placeholder SFX for Island Royale.

Pure stdlib. Outputs 16-bit mono 44.1kHz WAVs (ambience is stereo).
Replace any file with a real CC0 recording of the same name for the biggest
realism jump; the filenames are the integration contract.
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


def write_wav(name, data, peak=0.9, channels=1):
    if channels == 2:
        left, right = data
        m = max(1e-9, max(max(abs(v) for v in left), max(abs(v) for v in right)))
        k = peak / m
        buf = bytearray()
        for a, b in zip(left, right):
            buf += struct.pack("<h", int(max(-1.0, min(1.0, a * k)) * 32767))
            buf += struct.pack("<h", int(max(-1.0, min(1.0, b * k)) * 32767))
        frames = len(left)
    else:
        m = max(1e-9, max(abs(v) for v in data))
        k = peak / m
        buf = bytearray()
        for v in data:
            buf += struct.pack("<h", int(max(-1.0, min(1.0, v * k)) * 32767))
        frames = len(data)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(buf))
    print(f"{name:22s} {frames/SR:.2f}s  {len(buf)/1024:.0f} KB")


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


# ---------------------------------------------------------------- weapons
def gunshot(dur, body_decay, thump_freq, crack_amt, tail_decay, variant):
    """Five layers: supersonic crack, resonant body, sub thump, room tail
    and a bolt/action click. Early reflections are folded in afterwards."""
    rng = random.Random(900 + variant * 31)
    n = int(SR * dur)
    out = [0.0] * n
    lp = 0.0
    tail_lp = 0.0
    phase = 0.0
    for i in range(n):
        t = i / SR
        v = rng.uniform(-1, 1)

        # body: noise through a closing low-pass -> punch then warmth
        k = 0.60 * math.exp(-t * 22.0) + 0.07
        lp += (v - lp) * k
        body = lp * math.exp(-t * body_decay) * 1.65

        # sub thump with a downward pitch sweep
        f = thump_freq * (1.0 + 1.7 * math.exp(-t * 25.0))
        phase += 2 * math.pi * f / SR
        thump = math.sin(phase) * math.exp(-t * 15.0) * 0.9

        # supersonic crack
        cr = v * math.exp(-t * 650.0) * crack_amt

        # diffuse tail
        tail_lp += (v - tail_lp) * 0.03
        tail = tail_lp * math.exp(-t * tail_decay) * 0.85

        # mechanical click 50 ms later
        act = 0.0
        if t > 0.05:
            ct = t - 0.05
            if ct < 0.03:
                act = rng.uniform(-1, 1) * math.exp(-ct * 220.0) * 0.20

        out[i] = math.tanh((body + thump + cr + tail + act) * 1.05)

    # early reflections imply open space / nearby walls
    snap = out[: int(0.06 * SR)]
    for delay, gain in [(0.027, 0.16), (0.049, 0.10), (0.083, 0.06), (0.127, 0.04)]:
        off = int(delay * SR)
        for i, sv in enumerate(snap):
            if off + i < n:
                out[off + i] += sv * gain
    return fade_in(out, 16)


WEAPONS = {
    "rifle":   (0.55, 24.0, 105.0, 0.85, 7.5),
    "smg":     (0.34, 38.0, 150.0, 0.70, 9.0),
    "shotgun": (0.78, 15.0, 72.0, 1.00, 5.5),
    "sniper":  (1.10, 9.0, 58.0, 1.00, 4.2),
}
for name, (dur, body, thump, crack, tail) in WEAPONS.items():
    first = None
    for v in range(3):
        jitter = random.Random(400 + v * 11 + len(name))
        d = dur * jitter.uniform(0.96, 1.04)
        data = gunshot(
            d,
            body * jitter.uniform(0.9, 1.1),
            thump * jitter.uniform(0.95, 1.05),
            crack * jitter.uniform(0.9, 1.1),
            tail * jitter.uniform(0.9, 1.1),
            v,
        )
        write_wav(f"shot_{name}_{v + 1}", data, 0.92)
        if v == 0:
            first = data
    write_wav(f"shot_{name}", first, 0.92)


# ---------------------------------------------------------------- impacts
def flesh_hit(seed):
    rng = random.Random(seed)
    n = int(SR * 0.18)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        v = rng.uniform(-1, 1)
        lp += (v - lp) * 0.25
        thud = math.sin(2 * math.pi * 90 * t) * math.exp(-t * 28) * 0.9
        wet = lp * math.exp(-t * 40) * 0.8
        out.append(thud + wet)
    return fade_in(out, 8)


write_wav("hit_flesh", flesh_hit(55), 0.8)
write_wav("hit", sweep(1600, 1150, 0.06, 70, 0.8))
write_wav("kill", mix(0.26, [
    (0.00, sweep(880, 880, 0.08, 22, 0.9)),
    (0.09, sweep(1320, 1320, 0.14, 16, 0.9)),
]))
write_wav("hurt", mix(0.24, [
    (0.0, sweep(90, 55, 0.22, 18, 0.9)),
    (0.0, [random.uniform(-1, 1) * math.exp(-(i / SR) * 28) * 0.35
           for i in range(int(SR * 0.22))]),
]))
write_wav("death", sweep(300, 65, 0.72, 4.0, 0.9))


# ---------------------------------------------------------------- actions
write_wav("reload", mix(0.46, [
    (0.00, click(1400, 0.04, 110)),
    (0.06, [random.uniform(-1, 1) * math.exp(-(i / SR) * 40) * 0.5
            for i in range(int(SR * 0.09))]),
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
def explosion():
    rng = random.Random(77)
    n = int(SR * 1.2)
    out = []
    rumble = 0.0
    phase = 0.0
    for i in range(n):
        t = i / SR
        v = rng.uniform(-1, 1)
        rumble += (v - rumble) * 0.035
        f = 68 * (1.0 + 1.4 * math.exp(-t * 18.0))
        phase += 2 * math.pi * f / SR
        sub = math.sin(phase) * math.exp(-t * 4.5) * 1.1
        body = rumble * math.exp(-t * 2.2) * 1.4
        crack = v * math.exp(-t * 20.0) * 0.55
        out.append(math.tanh((sub + body + crack) * 1.1))
    snap = out[: int(0.08 * SR)]
    for delay, gain in [(0.06, 0.18), (0.11, 0.12), (0.19, 0.08)]:
        off = int(delay * SR)
        for i, sv in enumerate(snap):
            if off + i < n:
                out[off + i] += sv * gain
    return fade_in(out, 24)


write_wav("explosion", explosion(), 1.0)


# ---------------------------------------------------------------- footsteps
SURFACE_K = {"grass": 0.35, "sand": 0.18, "concrete": 0.55, "water": 0.30}


def footstep(surface, variant):
    rng = random.Random(3000 + variant * 17 + len(surface) * 7)
    n = int(SR * 0.16)
    out = []
    lp = 0.0
    k = SURFACE_K[surface]
    for i in range(n):
        t = i / SR
        v = rng.uniform(-1, 1)
        lp += (v - lp) * k
        if surface == "grass":
            env = math.exp(-t * 36) + 0.5 * math.exp(-((t - 0.05) ** 2) / 0.0008)
            sig = lp * env * 0.85
        elif surface == "sand":
            sig = lp * math.exp(-t * 30) * 0.95
        elif surface == "concrete":
            sig = (v - lp) * math.exp(-t * 55) * 0.65 + lp * math.exp(-t * 55) * 0.35
        else:
            rise = (1.0 - math.exp(-t * 90.0)) * math.exp(-t * 14.0)
            sig = (lp * 0.8 + v * 0.25) * rise * 1.25
        sig += math.sin(2 * math.pi * 78 * t) * math.exp(-t * 32) * 0.22
        out.append(sig)
    return fade_in(out, 8)


for surface in ["grass", "sand", "concrete", "water"]:
    for v in range(3):
        write_wav(f"footstep_{surface}_{v + 1}", footstep(surface, v), 0.55)

# Legacy names used by older builds.
for v in range(3):
    write_wav(f"footstep_{v + 1}", footstep("grass", v), 0.55)

write_wav("land", mix(0.30, [
    (0.0, sweep(95, 48, 0.30, 18, 0.9)),
    (0.0, [random.uniform(-1, 1) * math.exp(-(i / SR) * 34) * 0.45
           for i in range(int(SR * 0.18))]),
]), 0.85)


# ---------------------------------------------------------------- ambience
def make_loop(left, right, fade):
    n = len(left) - fade
    out_l = left[:n]
    out_r = right[:n]
    for i in range(fade):
        w = i / fade
        out_l[i] = left[i] * w + left[n + i] * (1.0 - w)
        out_r[i] = right[i] * w + right[n + i] * (1.0 - w)
    return out_l, out_r


def wind_loop(seconds=12.0):
    fade = int(SR * 2.0)
    n = int(SR * seconds) + fade
    rng = random.Random(123)
    l, r = [], []
    al = ar = 0.0
    for i in range(n):
        t = i / SR
        al += (rng.uniform(-1, 1) - al) * 0.012
        ar += (rng.uniform(-1, 1) - ar) * 0.012
        amp = 0.55 + 0.30 * math.sin(2 * math.pi * 0.09 * t) + 0.15 * math.sin(2 * math.pi * 0.031 * t + 1.1)
        l.append(al * amp)
        r.append(ar * amp)
    return make_loop(l, r, fade)


def surf_loop(seconds=10.0):
    fade = int(SR * 2.0)
    n = int(SR * seconds) + fade
    rng = random.Random(321)
    l, r = [], []
    al = ar = 0.0
    for i in range(n):
        t = i / SR
        al += (rng.uniform(-1, 1) - al) * 0.028
        ar += (rng.uniform(-1, 1) - ar) * 0.028
        swell = 0.5 + 0.35 * math.sin(2 * math.pi * 0.11 * t) + 0.15 * math.sin(2 * math.pi * 0.043 * t + 0.7)
        l.append(al * swell)
        r.append(ar * swell)
    return make_loop(l, r, fade)


write_wav("ambient_wind", wind_loop(), 0.7, channels=2)
write_wav("ambient_surf", surf_loop(), 0.65, channels=2)


def chirp(f0, f1, dur, seed):
    rng = random.Random(seed)
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / SR
        env = math.sin(math.pi * t / dur) ** 2
        out.append((math.sin(phase) + 0.25 * rng.uniform(-1, 1)) * env * 0.65)
    return fade_in(out, 8)


write_wav("bird_1", mix(0.52, [
    (0.00, chirp(3100, 2400, 0.11, 1)),
    (0.16, chirp(2900, 2100, 0.10, 2)),
    (0.31, chirp(3400, 2600, 0.13, 3)),
]), 0.65)
write_wav("bird_2", mix(0.38, [
    (0.00, chirp(2200, 3000, 0.13, 4)),
    (0.19, chirp(2600, 1900, 0.12, 5)),
]), 0.65)

print("done")
