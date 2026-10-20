#!/usr/bin/env python3
"""Synthesizes the soundtrack for the launch video, timed to its scenes.

Everything is generated here (no samples, no licensed music), so the result
is free to publish. Timings match Sources/OpenToolbeltApp/Promo.swift.

    python3 scripts/promo-audio.py dist/promo-audio.wav
    ffmpeg -i dist/opentoolbelt-promo.mp4 -i dist/promo-audio.wav \\
        -c:v copy -c:a aac -b:a 192k -shortest dist/opentoolbelt-promo-sound.mp4
"""

import sys
import wave

import numpy as np

SR = 48000
LENGTH = 30.0
N = int(SR * LENGTH)
rng = np.random.default_rng(7)
left = np.zeros(N)
right = np.zeros(N)


def add(signal, start, gain=1.0, pan=0.0):
    """Mixes a mono signal in at `start` seconds; pan -1 (left) to 1 (right)."""
    i = int(start * SR)
    if i >= N:
        return
    signal = signal[: N - i] * gain
    left[i:i + len(signal)] += signal * np.sqrt((1 - pan) / 2)
    right[i:i + len(signal)] += signal * np.sqrt((1 + pan) / 2)


def envelope(n, attack, release):
    a, r = max(int(attack * SR), 1), max(int(release * SR), 1)
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env[-r:] *= np.linspace(1, 0, r)
    return env


def tone(freq, dur, harmonics=6, bright=1.0, detune=0.0):
    """Additive tone: a warm, band-limited saw-like sound without filters."""
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for h in range(1, harmonics + 1):
        if freq * h > 14000:
            break
        amp = (1 / h) * bright ** (h - 1)
        out += amp * (np.sin(2 * np.pi * freq * h * t * (1 + detune)) + np.sin(2 * np.pi * freq * h * t * (1 - detune)))
    return out / 2


def pad(freqs, start, dur, gain=0.06, bright=0.45):
    for f in freqs:
        sound = tone(f, dur, harmonics=8, bright=bright, detune=0.0025) * envelope(int(dur * SR), 0.8, 1.2)
        add(sound, start, gain, pan=rng.uniform(-0.4, 0.4))


def pluck(freq, start, gain=0.08, pan=0.0, decay=3.5):
    dur = 1.4
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for h in range(1, 7):
        out += (1 / h) * np.sin(2 * np.pi * freq * h * t) * np.exp(-t * decay * h ** 0.7)
    out *= envelope(len(t), 0.003, 0.05)
    add(out, start, gain, pan)


def ping(freq, start, gain=0.16, pan=0.0):
    """Sonar ping with a short echo, for agents lighting up on the radar."""
    dur = 2.0
    t = np.arange(int(dur * SR)) / SR
    out = (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2.01 * t)) * np.exp(-t * 2.8)
    out *= envelope(len(t), 0.004, 0.1)
    for k, g in enumerate([1.0, 0.35, 0.15]):
        add(out, start + k * 0.27, gain * g, pan=pan * (1 if k % 2 == 0 else -1))


def noise_band(n, low, high):
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spectrum[(freqs < low) | (freqs > high)] = 0
    out = np.fft.irfft(spectrum, n)
    return out / (np.abs(out).max() + 1e-9)


def whoosh(start, dur=0.9, gain=0.06, rising=True):
    """A filtered-noise sweep, built by crossfading noise bands."""
    n = int(dur * SR)
    bands = [noise_band(n, 200, 800), noise_band(n, 800, 2500), noise_band(n, 2500, 7000)]
    x = np.linspace(0, 1, n) if rising else np.linspace(1, 0, n)
    weights = [np.clip(1 - np.abs(x * 2 - c), 0, 1) for c in (0, 1, 2)]
    out = sum(w * b for w, b in zip(weights, bands))
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    add(out * shape, start, gain, pan=-0.2)
    add(out[::-1] * shape, start, gain * 0.6, pan=0.3)


def tick(start, gain=0.05, freq=2600):
    t = np.arange(int(0.012 * SR)) / SR
    add(np.sin(2 * np.pi * freq * t) * np.hanning(len(t)), start, gain, pan=rng.uniform(-0.3, 0.3))


def kick(start, gain=0.22):
    t = np.arange(int(0.35 * SR)) / SR
    freq = 45 + 75 * np.exp(-t * 30)
    out = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 9)
    add(out, start, gain)


def click(start, gain=0.12):
    for k, f in enumerate([1800, 1200]):
        t = np.arange(int(0.02 * SR)) / SR
        add(np.sin(2 * np.pi * f * t) * np.exp(-t * 250), start + k * 0.045, gain)


def sweep_down(start, dur=1.3, gain=0.06):
    t = np.arange(int(dur * SR)) / SR
    freq = 880 * np.exp(-t * 1.6)
    out = np.sin(2 * np.pi * np.cumsum(freq) / SR) * envelope(len(t), 0.05, 0.6)
    add(out, start, gain)


def cut(start, gain=0.22, bright=1.0):
    """A clean hit for a cut: a tight noise transient, a short low thump, and a
    small high tick. Every scene change and headline lands on one."""
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    transient = noise_band(n, 3000, 12000) * np.exp(-t * 90) * 0.5 * bright
    thump = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 60)) * t) * np.exp(-t * 32)
    tink = np.sin(2 * np.pi * 3520 * t) * np.exp(-t * 70) * 0.18 * bright
    add(transient + thump + tink, start, gain)
    add(transient * 0.6, start + 0.012, gain * 0.5, pan=0.4)  # a hair of width


# Chords (Hz). D major, a simple I - vi - IV - V loop.
D2, A2 = 73.42, 110.0
DMAJ9 = [146.83, 185.0, 220.0, 277.18, 329.63]
BM9 = [123.47, 146.83, 185.0, 220.0, 277.18]
GMAJ7 = [98.0, 146.83, 185.0, 246.94, 293.66]
A69 = [110.0, 164.81, 185.0, 246.94, 277.18]
LOOP = [DMAJ9, BM9, GMAJ7, A69]
BAR = 2.4  # 100 BPM, 4/4

# 0-4s: the radar. A low drone, and a ping for each agent lighting up.
pad([D2, A2], 0.0, 4.6, gain=0.07, bright=0.3)
for i, f in enumerate([587.33, 659.25, 739.99, 880.0, 987.77, 1174.66]):
    ping(f, 0.5 + i * 0.32, pan=np.cos(i / 6 * 2 * np.pi - np.pi / 2) * 0.7)
whoosh(3.5, 0.9, rising=True)

# 4-13s: skills pile up. Chords with an eighth-note arpeggio, and soft pops per chip.
for k, chord in enumerate(LOOP):
    start = 4.0 + k * BAR
    pad(chord, start, BAR + 0.6)
    quiet = start >= 8.8  # most of it never runs: the arpeggio thins out
    for step in range(8):
        if quiet and step % 2:
            continue
        note = chord[(step * 2) % len(chord)] * 2
        pluck(note, start + step * BAR / 8, gain=0.045 if quiet else 0.07, pan=(-0.5 if step % 2 else 0.5))
scale = [587.33, 659.25, 739.99, 880.0, 987.77]
for i in range(20):
    pluck(scale[i % 5] * 2, 4.3 + i * 0.11 + 0.08, gain=0.025, pan=rng.uniform(-0.8, 0.8), decay=9)
for f in [587.33, 739.99, 880.0]:  # the three skills that do get used
    ping(f * 2, 9.3, gain=0.05)

# 13-17s: the cost. A dark pulse, and ticks that slow down as the counter eases out.
whoosh(12.7, 0.8, rising=False)
pad([61.74, 123.47, 185.0], 13.0, 4.4, gain=0.07, bright=0.25)
for beat in range(7):
    kick(13.2 + beat * 0.6, gain=0.12)
for k in range(1, 40):
    x = k / 40
    # Invert the counter's ease-out so each tick lands on an equal step of the number.
    t = 13.6 + 1.8 * (1 - (1 - x) ** (1 / 3))
    tick(t, gain=0.035)
pluck(1174.66, 15.4, gain=0.08)

# 17-26s: the app. Full groove with a kick, a click on Review, and the token count falling.
whoosh(16.7, 0.8, rising=True)
for k, chord in enumerate(LOOP):
    start = 17.0 + k * BAR
    pad(chord, start, BAR + 0.6, gain=0.065)
    for step in range(8):
        note = chord[(step * 3) % len(chord)] * 2
        pluck(note, start + step * BAR / 8, gain=0.06, pan=(-0.4 if step % 2 else 0.4))
for beat in range(15):
    kick(17.0 + beat * 0.6, gain=0.16)
click(23.4)
sweep_down(23.6)

# 26-30s: end card. A warm resolve that rings out.
pad(DMAJ9 + [440.0, 587.33], 26.0, 4.0, gain=0.08, bright=0.5)
pad([D2, 146.83], 26.0, 4.0, gain=0.08, bright=0.3)
ping(1174.66, 26.2, gain=0.08)
for i, f in enumerate([587.33, 739.99, 880.0, 1174.66]):
    pluck(f, 26.4 + i * 0.15, gain=0.05, pan=(i - 1.5) / 2)

# Cuts: scene changes and every headline.
for at, gain, bright in [
    (3.8, 0.24, 1.0),   # radar to grid
    (4.9, 0.14, 0.7),   # "Your agents carry a lot."
    (9.3, 0.16, 0.8),   # "Most of it never runs."
    (13.0, 0.24, 1.0),  # to the cost
    (13.2, 0.12, 0.6),  # "It still costs you."
    (15.0, 0.10, 0.6),  # the line under the number
    (17.0, 0.24, 1.0),  # to the app
    (17.5, 0.14, 0.7),  # "See it all."
    (21.6, 0.20, 0.9),  # to the trim card
    (21.8, 0.12, 0.6),  # "Trim in one click."
    (26.0, 0.26, 1.0),  # end card
    (26.4, 0.12, 0.6),  # the name
    (27.0, 0.09, 0.5),  # the tagline
]:
    cut(at, gain, bright)

# Room: a short synthetic reverb, then a gentle limiter and a fade-out.
def reverb(x, seconds=2.2, mix=0.22):
    ir_n = int(seconds * SR)
    ir = rng.standard_normal(ir_n) * np.exp(-np.linspace(0, 6, ir_n))
    size = 1 << int(np.ceil(np.log2(len(x) + ir_n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    wet /= np.abs(wet).max() + 1e-9
    return x + mix * wet * np.abs(x).max()


left, right = reverb(left), reverb(right)
mix = np.stack([left, right], axis=1)
mix = np.tanh(mix / (np.abs(mix).max() + 1e-9) * 1.6) * 0.89
fade_in, fade_out = int(0.05 * SR), int(1.6 * SR)
mix[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
mix[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]

out = sys.argv[1] if len(sys.argv) > 1 else "promo-audio.wav"
with wave.open(out, "wb") as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes((mix * 32767).astype(np.int16).tobytes())
print(f"Wrote {out}")
