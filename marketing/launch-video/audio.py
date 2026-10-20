"""Generates the soundtrack from the animation's own event list.

Reads out/events.json (written by render.cjs from window.EVENTS) and builds a
120 bpm pop-electronic track whose hits land on the visual beats: a four-on-
the-floor groove, a pumping bass and pad under I-V-vi-IV in D, a lead hook
that repeats every two bars, a riser into the end card, and one blip per pop.
Music stops at 28 s so the end card holds in silence, like the reference.
Pure numpy, every sound synthesized here, so the track is free to publish.
"""
import json
import os
import wave

import numpy as np

SR = 48000
BPM = 120
BEAT = 60 / BPM
DUR = 30.0
STOP = 28.0
N = int(SR * DUR)
root = os.path.dirname(os.path.abspath(__file__))
events = json.load(open(os.path.join(root, "out", "events.json")))
rng = np.random.default_rng(7)


def t2i(t):
    return int(round(t * SR))


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (SR * tau))


def add(buf, start, sig, gain=1.0):
    i = t2i(start)
    if i >= len(buf):
        return
    sig = sig[: len(buf) - i]
    buf[i: i + len(sig)] += sig * gain


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / np.sqrt(1 + (f / cutoff) ** 2), n=len(x))


def hp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * (f / cutoff) / np.sqrt(1 + (f / cutoff) ** 2), n=len(x))


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


# ---------- instruments ----------
def kick(vel=1.0):
    n = int(SR * 0.42)
    t = np.arange(n) / SR
    f = 42 + 150 * np.exp(-t / 0.045)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.16)
    click = rng.standard_normal(int(SR * 0.008)) * env_exp(int(SR * 0.008), 0.002)
    body[: len(click)] += click * 0.25
    return np.tanh(body * 1.6) * vel


def hat(open_=False, vel=1.0):
    n = int(SR * (0.16 if open_ else 0.05))
    return hp(rng.standard_normal(n) * env_exp(n, 0.045 if open_ else 0.012), 7000) * 0.5 * vel


def clap(vel=1.0):
    n = int(SR * 0.22)
    x = np.zeros(n)
    for d in (0, 0.011, 0.023):
        i, m = t2i(d), int(SR * 0.035)
        x[i: i + m] += rng.standard_normal(m) * env_exp(m, 0.012)
    x += rng.standard_normal(n) * env_exp(n, 0.07) * 0.6
    return hp(lp(x, 6500), 900) * 0.7 * vel


def pluck(note, dur=0.28, vel=1.0, bright=1.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = midi(note)
    sig = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.06) * bright
           + 0.18 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.04))
    return sig * env_exp(n, 0.09) * 0.42 * vel


def lead(note, dur, vel=1.0):
    """The hook: a bright, slightly detuned saw lead with a touch of vibrato."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = midi(note) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.15))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = sum(np.sin(k * ph) / k for k in range(1, 9)) + 0.6 * sum(np.sin(k * ph * 1.006) / k for k in range(1, 9))
    attack = np.minimum(1, t / 0.008)
    release = np.minimum(1, (n - np.arange(n)) / (SR * 0.06))
    return lp(saw * attack * release * env_exp(n, 0.5), 3800) * 0.16 * vel


def bass(note, dur=0.24, vel=1.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = midi(note)
    saw = sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, 7))
    return lp((saw * 0.45 + np.sin(2 * np.pi * f * t) * 0.7) * env_exp(n, 0.11), 520) * 0.9 * vel


def pad(notes, start, end):
    n = t2i(end) - t2i(start)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for nt in notes:
        f = midi(nt)
        for det in (-4, 3):
            ff = f * 2 ** (det / 1200)
            sig += np.sin(2 * np.pi * ff * t + rng.uniform(0, 6)) * 0.5 + 0.25 * np.sin(4 * np.pi * ff * t)
    a = np.minimum(1, t / 0.6)
    r = np.minimum(1, (n - np.arange(n)) / (SR * 0.6))
    return lp(sig, 1600) * a * r * 0.09


def blip(freq, vel=1.0):
    n = int(SR * 0.11)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) * env_exp(n, 0.03) + 0.35 * np.sin(2 * np.pi * freq * 1.5 * t) * env_exp(n, 0.015)
    tick = rng.standard_normal(int(SR * 0.004)) * env_exp(int(SR * 0.004), 0.001)
    sig[: len(tick)] += hp(tick, 4000) * 0.9
    return sig * 0.5 * vel


def key_click():
    n = int(SR * 0.03)
    return hp(rng.standard_normal(n) * env_exp(n, 0.004), 2500) * 0.35


def thud(vel=1.0):
    n = int(SR * 0.25)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * (70 + 90 * np.exp(-t / 0.03)) * t) * env_exp(n, 0.07) * 0.8 * vel


def swish(dur=0.28):
    """A short airy whoosh under each blur dissolve."""
    n = int(SR * dur)
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    return hp(rng.standard_normal(n), 1800) * shape * 0.22


def riser(start, end):
    n = t2i(end) - t2i(start)
    t = np.arange(n) / SR
    sweep = hp(rng.standard_normal(n), 600) * (t / t[-1]) ** 2.2
    tone = np.sin(2 * np.pi * np.cumsum(220 * 2 ** (3 * t / t[-1])) / SR) * (t / t[-1]) ** 2 * 0.25
    return (sweep * 0.35 + tone) * 0.6


def impact():
    n = int(SR * 1.8)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (36 + 120 * np.exp(-t / 0.05)) * t) * env_exp(n, 0.5)
    return np.tanh(boom * 1.4 + lp(rng.standard_normal(n), 3000) * env_exp(n, 0.25) * 0.5) * 0.9


# ---------- arrangement ----------
drums = np.zeros(N)
music = np.zeros(N)  # gets the sidechain pump
lead_bus = np.zeros(N)
fx = np.zeros(N)

# I - V - vi - IV in D: D, A, Bm, G. Bars are 2 s.
CHORDS = [[62, 66, 69], [61, 64, 69], [62, 66, 71], [62, 67, 71]]
BASS = [38, 45, 47, 43]
# A two-bar hook in D major pentatonic, (beat, note, length in beats).
HOOK = [(0, 78, 0.5), (0.75, 81, 0.5), (1.5, 78, 0.5), (2, 76, 1.0), (3, 74, 0.75),
        (4, 76, 0.5), (4.75, 78, 0.5), (5.5, 81, 0.75), (6.5, 83, 0.5), (7, 81, 1.0)]
BLIPS = [1174.7, 1318.5, 1480.0, 1760.0, 1975.5, 2349.3]

kick_times = []
for bar in range(15):
    t0 = bar * 4 * BEAT
    if t0 >= STOP:
        break
    ch, bs = CHORDS[bar % 4], BASS[bar % 4]
    full, groove = bar >= 2, bar >= 4
    for b in range(4):
        tb = t0 + b * BEAT
        if tb >= STOP:
            break
        if bar >= 1 and (full or b in (0, 2)):
            add(drums, tb, kick(1.0 if full else 0.38))
            kick_times.append(tb)
        if groove and b in (1, 3):
            add(drums, tb, clap(0.8))
        if full:
            add(drums, tb, hat(False, 0.55))
            add(drums, tb + BEAT / 2, hat(bar >= 12 and b == 3, 0.75))
            if bar >= 8:
                add(drums, tb + BEAT / 4, hat(False, 0.22))
                add(drums, tb + 3 * BEAT / 4, hat(False, 0.3))
            add(music, tb, bass(bs, 0.26, 0.95))
            if b in (1, 3):
                add(music, tb + BEAT / 2, bass(bs + 12, 0.18, 0.55))
        if groove:
            seq = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 24]
            step = BEAT / 2 if bar < 10 else BEAT / 4
            k, tt = 0, tb
            while tt < tb + BEAT - 1e-6:
                add(music, tt, pluck(seq[(b * 4 + k) % 4], 0.26, 0.55 if k % 2 == 0 else 0.35, bright=1.0 if bar >= 8 else 0.6))
                tt += step
                k += 1
    # The hook comes in at bar 4 and plays every two bars, louder from bar 8.
    if bar >= 4 and bar % 2 == 0:
        for beat_at, note, length in HOOK:
            at = t0 + beat_at * BEAT
            if at < STOP:
                add(lead_bus, at, lead(note, length * BEAT * 0.95, 0.8 if bar < 8 else 1.0))
for bar in range(2, 14):
    t0 = bar * 4 * BEAT
    add(music, t0, pad([n + 12 for n in CHORDS[bar % 4]], t0, min(t0 + 4 * BEAT + 0.3, STOP)))
add(fx, 24.0, riser(24.0, 26.5))

# Sidechain: duck the bass and pads on every kick so the track pumps.
pump = np.ones(N)
dk = np.arange(int(SR * 0.4)) / SR
duck = 1 - 0.55 * np.exp(-dk / 0.09)
for tk in kick_times:
    i = t2i(tk)
    m = min(len(duck), N - i)
    pump[i: i + m] = np.minimum(pump[i: i + m], duck[:m])
music *= pump

# Event-synced sounds
for e in events:
    t, ty = e["t"], e["type"]
    if ty == "pop":
        add(fx, t, blip(BLIPS[int(t * 7) % len(BLIPS)], 0.6))
    elif ty == "hit":
        add(fx, t, blip(BLIPS[(int(t * 3) + 2) % len(BLIPS)], 0.9))
        add(drums, t, thud(0.5))
    elif ty == "tick":
        add(fx, t, blip(BLIPS[-1], 0.35))
    elif ty == "key":
        add(fx, t, key_click())
    elif ty == "cut":
        if 0.1 < t < STOP:
            add(drums, t, thud(0.8))
            add(fx, t - 0.14, swish())
    elif ty == "impact":
        add(drums, t, impact())

# Hard stop at STOP for the groove; fx rings on.
stop_i = t2i(STOP)
fade = np.ones(N)
fade[stop_i:] = 0
fade[stop_i - int(SR * 0.04): stop_i] = np.linspace(1, 0, int(SR * 0.04))
drums *= fade
music *= fade
lead_bus *= fade
swell = np.ones(N)
sw = t2i(4.0)
swell[:sw] = np.linspace(0.45, 1.0, sw)
drums[:sw] *= np.linspace(0.5, 1.0, sw)
music *= swell


def write(path, x, gain):
    x = np.tanh(x * gain * 1.15) / np.tanh(1.15)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.column_stack([pcm, pcm]).ravel().tobytes())


out = os.path.join(root, "out")
write(os.path.join(out, "drums.wav"), drums, 0.9)
write(os.path.join(out, "music.wav"), music + lead_bus + fx, 0.8)
print("audio ok", len(events), "events")
