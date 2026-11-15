#!/usr/bin/env python3
"""Build the game's sounds: CC0 Kenney foley converted to mono, plus a few
synthesized ambiences. Needs ffmpeg, oggenc (vorbis-tools) and numpy.
    python3 tools/make_sounds.py [path to "Kenney Game Assets All-in-1"/Audio]
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mods/bc/sounds"
OUT.mkdir(parents=True, exist_ok=True)
KENNEY = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads/Kenney Game Assets All-in-1 3.5.0/Audio"
RATE = 32000

IMPACT, RPG, FOLEY = "Impact Sounds/Audio", "RPG Audio/Audio", "Foley Sounds/Audio"
COPY = {
    "step_grass": [f"{IMPACT}/footstep_grass_00{i}.ogg" for i in range(3)],
    "step_dirt": [f"{IMPACT}/footstep_carpet_00{i}.ogg" for i in range(3)],
    "step_sand": [f"{IMPACT}/footstep_carpet_003.ogg", f"{IMPACT}/footstep_carpet_004.ogg"],
    "step_snow": [f"{IMPACT}/footstep_snow_00{i}.ogg" for i in range(3)],
    "step_stone": [f"{IMPACT}/footstep_concrete_00{i}.ogg" for i in range(3)],
    "step_wood": [f"{IMPACT}/footstep_wood_00{i}.ogg" for i in range(3)],
    "dig_soft": [f"{IMPACT}/impactSoft_medium_00{i}.ogg" for i in range(3)],
    "dig_stone": [f"{IMPACT}/impactMining_00{i}.ogg" for i in range(3)],
    "dig_wood": [f"{IMPACT}/impactWood_medium_00{i}.ogg" for i in range(3)],
    "dig_leaves": [f"{RPG}/cloth1.ogg", f"{RPG}/cloth2.ogg"],
    "place": [f"{IMPACT}/impactGeneric_light_000.ogg", f"{IMPACT}/impactGeneric_light_001.ogg"],
    "place_stone": [f"{FOLEY}/Rocks/stoneHit1.ogg", f"{FOLEY}/Rocks/stoneHit2.ogg"],
    "place_wood": [f"{IMPACT}/impactPlank_medium_000.ogg", f"{IMPACT}/impactPlank_medium_001.ogg"],
    "page": [f"{RPG}/bookFlip1.ogg", f"{RPG}/bookFlip2.ogg"],
    "butcher": [f"{RPG}/knifeSlice.ogg", f"{RPG}/knifeSlice2.ogg"],
    "woosh": [f"{FOLEY}/Woosh/woosh1.ogg", f"{FOLEY}/Woosh/woosh2.ogg"],
    "bow": [f"{FOLEY}/Woosh/woosh5.ogg"],
    "hit": [f"{IMPACT}/impactPunch_medium_000.ogg", f"{IMPACT}/impactPunch_medium_001.ogg"],
    "hurt": [f"{IMPACT}/impactPunch_heavy_000.ogg", f"{IMPACT}/impactPunch_heavy_001.ogg"],
    "break": [f"{IMPACT}/impactWood_heavy_000.ogg"],
    "door": [f"{RPG}/doorOpen_1.ogg", f"{RPG}/doorClose_1.ogg"],
    "cloth": [f"{RPG}/cloth3.ogg", f"{RPG}/clothBelt.ogg"],
    "splash": [f"{FOLEY}/Water/drip1.ogg", f"{FOLEY}/Water/drip2.ogg"],
}


def encode(src, dst):
    """Any audio file -> mono Ogg Vorbis (ffmpeg decodes, oggenc encodes)."""
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "mono.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-ac", "1", "-ar", str(RATE), str(wav)],
                       check=True)
        subprocess.run(["oggenc", "-Q", "-q", "3", "-o", str(dst), str(wav)], check=True)


def copy_kenney():
    if not KENNEY.exists():
        print(f"Kenney audio not found at {KENNEY}; keeping existing copied sounds.")
        return
    for name, files in COPY.items():
        for i, rel in enumerate(files):
            dst = OUT / (f"bc_{name}.{i}.ogg" if len(files) > 1 else f"bc_{name}.ogg")
            encode(KENNEY / rel, dst)


def write(name, samples):
    samples = np.clip(samples, -1, 1)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "s.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((samples * 32000).astype(np.int16).tobytes())
        encode(wav, OUT / f"bc_{name}.ogg")


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def loopable(x, fade):
    """Crossfade the tail into the head so the clip loops without a click."""
    n = len(x) - fade
    ramp = np.linspace(0, 1, fade)
    out = x[:n].copy()
    out[:fade] = out[:fade] * ramp + x[n:] * (1 - ramp)
    return out


def synth():
    rng = np.random.default_rng(7)
    t = lambda secs: np.arange(int(RATE * secs)) / RATE

    # rain: bright hiss with a little texture
    n = rng.standard_normal(int(RATE * 4.5))
    hiss = n - lowpass(n, 0.25)
    patter = lowpass(rng.standard_normal(len(n)) * (rng.random(len(n)) > 0.985) * 6, 0.3)
    write("rain", loopable((hiss * 0.22 + patter * 0.5) * 0.8, RATE // 2))

    # wind: low noise with slow swells
    n = rng.standard_normal(int(RATE * 6.5))
    low = lowpass(lowpass(n, 0.02), 0.05) * 14
    tt = np.arange(len(low)) / RATE
    swell = 0.55 + 0.3 * np.sin(2 * np.pi * tt / 6.0) + 0.15 * np.sin(2 * np.pi * tt / 2.0 + 1)
    write("wind", loopable(low * swell * 0.7, RATE // 2))

    # fire: soft roar and crackles
    n = rng.standard_normal(int(RATE * 2.2))
    roar = lowpass(n, 0.03) * 3
    crack = np.zeros(len(n))
    for _ in range(14):
        i = rng.integers(0, len(n) - 800)
        ln = rng.integers(60, 500)
        crack[i:i + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 5)) * rng.uniform(0.3, 1.0)
    x = roar * 0.35 + crack * 0.5
    env = np.minimum(1, np.minimum(np.arange(len(x)), len(x) - np.arange(len(x))) / (RATE * 0.15))
    write("fire", x * env)

    # ignite: a rising whoosh
    tt = t(0.9)
    n = lowpass(rng.standard_normal(len(tt)), 0.12) * 3
    write("ignite", n * np.sin(np.pi * tt / 0.9) ** 2 * 0.7)

    # eat: three crunches
    x = np.zeros(int(RATE * 0.6))
    for start in (0.02, 0.2, 0.38):
        i = int(start * RATE)
        ln = int(0.09 * RATE)
        x[i:i + ln] += lowpass(rng.standard_normal(ln), 0.5) * np.exp(-np.arange(ln) / (ln / 3)) * 0.9
    write("eat", x)

    # drink: gulps
    x = np.zeros(int(RATE * 0.9))
    for start in (0.05, 0.35, 0.62):
        i = int(start * RATE)
        ln = int(0.16 * RATE)
        tt = np.arange(ln) / RATE
        x[i:i + ln] += np.sin(2 * np.pi * (220 - 500 * tt) * tt) * np.sin(np.pi * tt / 0.16) ** 2 * 0.5
    write("drink", x)

    # howl: a long rising and falling note with a second voice
    tt = t(3.4)
    f = 310 + 190 * np.sin(np.pi * np.clip(tt / 3.4, 0, 1)) ** 0.6 + 6 * np.sin(2 * np.pi * 5 * tt)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    voice = np.sin(phase) * 0.6 + np.sin(2 * phase) * 0.22 + np.sin(3 * phase) * 0.1
    env = np.sin(np.pi * tt / 3.4) ** 0.8
    x = voice * env
    echo = np.zeros(len(x) + RATE // 3)
    echo[:len(x)] += x
    echo[RATE // 3:] += x * 0.3
    write("howl", echo * 0.6)

    # growl
    tt = t(0.7)
    saw = ((tt * 82) % 1.0) * 2 - 1
    x = lowpass(saw + rng.standard_normal(len(tt)) * 0.5, 0.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 27 * tt))
    write("growl", x * np.sin(np.pi * tt / 0.7) * 1.4)


if __name__ == "__main__":
    copy_kenney()
    synth()
    print(f"{len(list(OUT.glob('*.ogg')))} sound files")
