"""Synthesises the game's chiptune theme into assets/audio/music/theme.wav (pure Python).

Run: python3 tools/compose_music.py && ffmpeg -y -i assets/audio/music/theme.wav -c:a vorbis -strict -2 -q:a 5 assets/audio/music/theme.ogg
"""
import math
import random
import wave
import array

SR = 22050
BPM = 116
BEAT = 60.0 / BPM
BARS = 16

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name):
    if name == "R":
        return None
    pitch = name[:-1]
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


MELODY = [
    "A4:.5 C5:.5 E5:1 D5:.5 C5:.5 B4:1",
    "A4:.5 C5:.5 F5:1 E5:.5 D5:.5 C5:1",
    "G4:.5 C5:.5 E5:1 G5:1 E5:1",
    "D5:.5 B4:.5 G4:1 B4:.5 D5:.5 G5:1",
    "E5:1 C5:.5 A4:.5 E5:1 C5:.5 A4:.5",
    "F5:1 C5:.5 A4:.5 F5:1 D5:.5 C5:.5",
    "B4:.5 E5:.5 G#5:1 E5:.5 B4:.5 G#4:1",
    "A4:.5 B4:.5 C5:.5 B4:.5 A4:1 R:1",
    "D5:.5 F5:.5 A5:1 F5:.5 D5:.5 A4:1",
    "C5:.5 E5:.5 A5:1 E5:.5 C5:.5 A4:1",
    "D5:.5 F5:.5 A5:.5 D6:.5 C6:.5 A5:.5 F5:1",
    "E5:.5 C5:.5 A4:.5 C5:.5 E5:2",
    "F5:1 E5:.5 F5:.5 A5:1 G5:.5 F5:.5",
    "G5:1 F5:.5 G5:.5 B5:1 A5:.5 G5:.5",
    "G#5:1 E5:.5 B4:.5 E5:1 G#4:.5 B4:.5",
    "A4:.5 E5:.5 A5:1 R:.5 E5:.5 A4:1",
]

CHORDS = ["Am", "F", "C", "G", "Am", "F", "E", "E", "Dm", "Am", "Dm", "Am", "F", "G", "E", "E"]
CHORD_DEF = {
    "Am": (69, [0, 3, 7], 45),
    "F": (65, [0, 4, 7], 41),
    "C": (60, [0, 4, 7], 48),
    "G": (67, [0, 4, 7], 43),
    "E": (64, [0, 4, 7], 40),
    "Dm": (62, [0, 3, 7], 38),
}

TOTAL = int(BARS * 4 * BEAT * SR)
mix = array.array("d", [0.0]) * (TOTAL + SR)


def pulse25(p):
    return 1.0 if (p % 1.0) < 0.25 else -1.0


def pulse50(p):
    return 1.0 if (p % 1.0) < 0.5 else -1.0


def triangle(p):
    return 4.0 * abs((p % 1.0) - 0.5) - 1.0


def play(start_beat, dur_beats, m, gain, wave_fn, attack=0.004, decay=0.05, sustain=0.75, release=0.03, vibrato=False, glide=0.0):
    if m is None:
        return
    f = freq(m)
    s0 = int(start_beat * BEAT * SR)
    length = dur_beats * BEAT
    ns = int(length * SR)
    phase = 0.0
    for i in range(ns):
        t = i / SR
        if t < attack:
            env = t / attack
        elif t < attack + decay:
            env = 1.0 - (1.0 - sustain) * (t - attack) / decay
        else:
            env = sustain
        rem = length - t
        if rem < release:
            env *= max(rem, 0.0) / release
        ff = f
        if vibrato and t > 0.1:
            ff = f * (1.0 + 0.005 * math.sin(2 * math.pi * 5.5 * t))
        phase += ff / SR
        mix[s0 + i] += wave_fn(phase) * env * gain


def kick(start_beat, gain=0.9):
    s0 = int(start_beat * BEAT * SR)
    ns = int(0.14 * SR)
    phase = 0.0
    for i in range(ns):
        t = i / SR
        f = 40.0 + 140.0 * math.exp(-t * 28.0)
        phase += f / SR
        env = math.exp(-t * 18.0)
        mix[s0 + i] += math.sin(2 * math.pi * phase) * env * gain


def snare(start_beat, gain=0.5):
    s0 = int(start_beat * BEAT * SR)
    ns = int(0.13 * SR)
    prev = 0.0
    for i in range(ns):
        t = i / SR
        env = math.exp(-t * 26.0)
        r = random.uniform(-1, 1)
        hp = r - prev * 0.5
        prev = r
        tone = math.sin(2 * math.pi * 190.0 * t) * math.exp(-t * 40.0)
        mix[s0 + i] += (hp * 0.7 + tone * 0.5) * env * gain


def hat(start_beat, gain=0.18, length=0.035):
    s0 = int(start_beat * BEAT * SR)
    ns = int(length * SR)
    prev = 0.0
    for i in range(ns):
        t = i / SR
        env = math.exp(-t * 90.0)
        r = random.uniform(-1, 1)
        hp = r - prev
        prev = r
        mix[s0 + i] += hp * env * gain


random.seed(7)

# lead
beat = 0.0
for bar in MELODY:
    for token in bar.split():
        name, dur = token.split(":")
        dur = float(dur)
        play(beat, dur * 0.92, midi(name), 0.24, pulse25, vibrato=True)
        beat += dur
assert abs(beat - BARS * 4) < 1e-6, beat

# arpeggio, bass and drums per bar
for bar_index, chord in enumerate(CHORDS):
    root, intervals, bass_root = CHORD_DEF[chord]
    bar_start = bar_index * 4.0
    tones = [root + intervals[0], root + intervals[1], root + intervals[2], root + 12]
    pattern = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3]
    section_b = bar_index >= 8
    for k in range(16):
        gain = 0.085 if not section_b else 0.1
        play(bar_start + k * 0.25, 0.22, tones[pattern[k]] - 12, gain, pulse50, decay=0.03, sustain=0.5, release=0.02)
    bass_offsets = [0, 0, 12, 0, 0, 12, 0, 7] if not section_b else [0, 12, 0, 0, 12, 0, 7, 12]
    for k in range(8):
        play(bar_start + k * 0.5, 0.45, bass_root + bass_offsets[k], 0.3, triangle, decay=0.04, sustain=0.85, release=0.03)
    for k in range(16):
        b = bar_start + k * 0.25
        if k in (0, 8):
            kick(b)
        if k == 10 and bar_index % 2 == 1:
            kick(b, 0.6)
        if k in (4, 12):
            snare(b)
        if k % 2 == 0:
            hat(b, 0.16 if k % 4 else 0.22)
        elif section_b and k in (7, 15):
            hat(b, 0.12)

# fold the tail (release of the last notes) back into the start so the loop is seamless
for i in range(TOTAL, len(mix)):
    mix[i - TOTAL] += mix[i]

peak = max(abs(v) for v in mix[:TOTAL]) or 1.0
out = array.array("h")
for i in range(TOTAL):
    v = math.tanh(mix[i] / peak * 1.6) / math.tanh(1.6) * 0.9
    out.append(int(v * 32767))

with wave.open("assets/audio/music/theme.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print("wrote theme.wav", TOTAL / SR, "seconds")
