#!/usr/bin/env python3
"""Import real CC0 / CC-BY recordings into assets/audio.

Sources (download and unpack next to this script, or pass --src):

  <src>/guns/sounds/{sks,cz,mosin,shotty}.wav
      https://opengameart.org/content/gunshot-sounds
      Vincent Sevedge, CC BY 3.0

  <src>/steps/footsteps/{grass,water}/*.ogg
      https://opengameart.org/content/footsteps-on-different-surfaces
      congusbongus, CC BY 3.0 (derived from Freesound recordings)

  <src>/fantozzi/Fantozzi-footsteps/ogg/*.ogg
      https://opengameart.org/content/fantozzis-footsteps-grasssand-stone
      Fantozzi, CC0

  <src>/reload/{clipload1,clipload2,singlebullet1}.wav
      https://opengameart.org/content/gun-reload-sound-effects
      BMacZero, CC0

Run:
    python3 tools/import_real_sfx.py --src /tmp/opencode

The script only replaces the files it owns; UI sounds, ambient loops, birds and
the synthesized fallback generator stay in tools/gen_sfx.py.
"""
import argparse
import math
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, lfilter, resample_poly, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    x = data.astype(np.float32) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch)[:, 0]
    return x, sr


def resample(x, sr_in, sr_out=SR):
    if sr_in == sr_out:
        return x
    g = math.gcd(int(sr_in), int(sr_out))
    return resample_poly(x, sr_out // g, sr_in // g).astype(np.float32)


def pitch(x, factor):
    if abs(factor - 1.0) < 1e-4:
        return x
    n = max(2, int(round(len(x) / factor)))
    src = np.linspace(0.0, len(x) - 1.0, len(x), dtype=np.float64)
    dst = np.linspace(0.0, len(x) - 1.0, n, dtype=np.float64)
    return np.interp(dst, src, x).astype(np.float32)


def normalize(x, peak=0.9):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    if m < 1e-6:
        return x
    return (x * (peak / m)).astype(np.float32)


def trim_onset(x, threshold=0.04, pre_ms=4.0):
    """Drop the silent pre-roll so the transient starts immediately."""
    if not len(x):
        return x
    m = float(np.max(np.abs(x)))
    if m < 1e-6:
        return x
    idx = np.nonzero(np.abs(x) > m * threshold)[0]
    if not len(idx):
        return x
    start = max(0, int(idx[0] - SR * pre_ms / 1000.0))
    return x[start:]


def fade(x, fin_ms=3.0, fout_ms=50.0):
    n = len(x)
    fi = min(n, int(SR * fin_ms / 1000.0))
    fo = min(n, int(SR * fout_ms / 1000.0))
    if fi:
        x[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)
    if fo:
        x[-fo:] *= np.linspace(1.0, 0.0, fo, dtype=np.float32)
    return x


def highpass(x, freq, order=2):
    sos = butter(order, freq / (SR * 0.5), btype="highpass", output="sos")
    return sosfilt(sos, x).astype(np.float32)


def peaking(x, freq, gain_db, q):
    a = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * freq / SR
    alpha = math.sin(w0) / (2.0 * q)
    b = np.array([1.0 + alpha * a, -2.0 * math.cos(w0), 1.0 - alpha * a])
    ca = np.array([1.0 + alpha / a, -2.0 * math.cos(w0), 1.0 - alpha / a])
    return lfilter(b, ca, x).astype(np.float32)


def shape_gun(x, variant):
    """Make a field recording punchy and game-ready.

    The source is a distant field recording (dark, ~2 kHz centroid). Add
    presence, remove boxiness, and reinforce the transient with a short
    high-frequency crack and a sub thump. This keeps the real texture while
    restoring the snap the old synth had.
    """
    x = x.copy()
    x = highpass(x, 55.0, 2)
    x = peaking(x, 350.0, -4.5, 1.0)
    x = peaking(x, 3200.0, 5.5, 0.9)
    x = peaking(x, 9000.0, 3.0, 0.7)

    rng = np.random.default_rng(700 + variant)
    n = int(0.006 * SR)
    t = np.arange(n, dtype=np.float32) / SR
    crack = rng.normal(0.0, 1.0, n).astype(np.float32) * np.exp(-t * 520.0)
    x[:n] += highpass(crack, 2400.0) * 0.34

    m = int(0.10 * SR)
    t = np.arange(m, dtype=np.float32) / SR
    f = 92.0 * (1.0 + 0.9 * np.exp(-t * 25.0))
    sub = np.sin(np.cumsum(2.0 * math.pi * f / SR)) * np.exp(-t * 22.0) * 0.30
    x[:m] += sub

    x = np.tanh(x * 1.12) / np.tanh(1.12)
    x = fade(x, 1.0, 70.0)
    return normalize(x, 0.95)


def write_wav(name, x):
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype(np.int16).tobytes()
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    print("%-24s %.2fs" % (name, len(x) / SR))


def extract(path, onset, duration, pitch_factor=1.0, variant=0):
    x, sr = read_wav(path)
    x = resample(x, sr)
    start = max(0, int((onset - 0.02) * SR))
    n = int(duration * SR)
    seg = x[start:start + n]
    if len(seg) < n:
        seg = np.pad(seg, (0, n - len(seg)))
    seg = trim_onset(seg, 0.08)
    seg = pitch(seg, pitch_factor)
    seg = seg - float(np.mean(seg))
    return shape_gun(seg, variant)


# ---------------------------------------------------------------- gunshots
GUNS = {
    # id: (source file, onsets, duration, pitch per variant)
    "rifle":   ("sks.wav",   [0.41, 2.33, 4.23], 0.95, [1.00, 1.00, 1.00]),
    "smg":     ("cz.wav",    [0.28, 2.83, 4.13], 0.62, [1.10, 1.08, 1.12]),
    "sniper":  ("mosin.wav", [0.47, 6.01, 8.88], 1.40, [1.00, 0.98, 1.02]),
    "shotgun": ("shotty.wav", [0.25], 0.46, [1.00, 0.96, 1.04]),
}


def import_guns(src):
    base = os.path.join(src, "guns", "sounds")
    for weapon, (fn, onsets, dur, pitches) in GUNS.items():
        path = os.path.join(base, fn)
        variants = []
        for i, p in enumerate(pitches):
            onset = onsets[i % len(onsets)]
            variants.append(extract(path, onset, dur, p, i))
        for i, data in enumerate(variants, 1):
            write_wav("shot_%s_%d" % (weapon, i), data)
        write_wav("shot_%s" % weapon, variants[0])


# ---------------------------------------------------------------- footsteps
def decode(path):
    """Decode ogg/flac/wav to a temp 44.1k mono wav and read it."""
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", path,
             "-ac", "1", "-ar", str(SR), "-c:a", "pcm_s16le", tmp],
            check=True,
        )
        return read_wav(tmp)[0]
    finally:
        os.unlink(tmp)


def trim_step(x, peak=0.68, max_dur=0.36):
    if not len(x):
        return x
    m = float(np.max(np.abs(x)))
    if m < 1e-6:
        return x
    idx = np.nonzero(np.abs(x) > max(0.008, m * 0.12))[0]
    if not len(idx):
        return normalize(fade(x.copy(), 4, 40), peak)
    start = max(0, int(idx[0] - 0.012 * SR))
    end = min(len(x), start + int(max_dur * SR))
    seg = x[start:end].copy()
    return normalize(fade(seg, 4, 45), peak)


def import_steps(src):
    maps = {
        "grass": [
            os.path.join(src, "steps", "footsteps", "grass", f)
            for f in ("0.ogg", "2.ogg", "4.ogg")
        ],
        "water": [
            os.path.join(src, "steps", "footsteps", "water", f)
            for f in ("0.ogg", "1.ogg", "2.ogg")
        ],
        "concrete": [
            os.path.join(src, "fantozzi", "Fantozzi-footsteps", "ogg", f)
            for f in ("Fantozzi-StoneL1.ogg", "Fantozzi-StoneR1.ogg", "Fantozzi-StoneR2.ogg")
        ],
        "sand": [
            os.path.join(src, "fantozzi", "Fantozzi-footsteps", "ogg", f)
            for f in ("Fantozzi-SandL1.ogg", "Fantozzi-SandL2.ogg", "Fantozzi-SandR3.ogg")
        ],
    }
    max_durs = {"grass": 0.30, "water": 0.34, "concrete": 0.36, "sand": 0.38}
    for surface, paths in maps.items():
        variants = []
        for path in paths:
            variants.append(trim_step(decode(path), max_dur=max_durs[surface]))
        for i, data in enumerate(variants, 1):
            write_wav("footstep_%s_%d" % (surface, i), data)
    # Legacy fallback names used by older calls.
    for i in range(1, 4):
        write_wav("footstep_%d" % i, trim_step(decode(maps["grass"][i - 1]), max_dur=0.30))


# ---------------------------------------------------------------- reload
def import_reload(src):
    base = os.path.join(src, "reload")
    clips = {}
    for name in ("clipload1", "clipload2", "singlebullet1"):
        x, sr = read_wav(os.path.join(base, name + ".wav"))
        clips[name] = trim_onset(resample(x, sr), 0.03)

    total = int(1.15 * SR)
    out = np.zeros(total, dtype=np.float32)
    # Magazine out, new magazine in, round seated, bolt released.
    for name, at, gain in [
        ("clipload2", 0.00, 0.8),
        ("singlebullet1", 0.30, 0.7),
        ("clipload1", 0.62, 0.9),
        ("clipload2", 0.90, 0.6),
    ]:
        x = clips[name] * gain
        off = int(at * SR)
        n = min(len(x), total - off)
        out[off:off + n] += x[:n]
    out = normalize(fade(out, 2, 80), 0.82)
    write_wav("reload", out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/opencode",
                    help="directory containing guns/, steps/, fantozzi/, reload/")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    import_guns(args.src)
    import_steps(args.src)
    import_reload(args.src)
    print("done; run: godot --headless --editor --path . --quit")


if __name__ == "__main__":
    main()
