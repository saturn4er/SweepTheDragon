"""Synthesises the game's music in pure Python (no numpy).

Run: python3 tools/compose_music.py
Writes assets/audio/music/theme.wav (the dungeon theme) and battle.wav (an upbeat alternate),
then encode with:
  ffmpeg -y -i theme.wav -ac 2 -c:a vorbis -strict -2 -q:a 5 theme.ogg
"""
import math
import random
import wave
import array

SR = 22050
NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name):
    if name == "R":
        return None
    return 12 * (int(name[-1]) + 1) + NOTE_INDEX[name[:-1]]


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def pulse(duty):
    return lambda p: 1.0 if (p % 1.0) < duty else -1.0


def triangle(p):
    return 4.0 * abs((p % 1.0) - 0.5) - 1.0


def sine(p):
    return math.sin(2 * math.pi * p)


def bell(p):
    return math.sin(2 * math.pi * p) * 0.85 + math.sin(2 * math.pi * p * 2.76) * 0.08 + math.sin(2 * math.pi * p * 4.07) * 0.03


## Highest lead note allowed. Bars that reach above it are dropped a whole octave.
LEAD_CAP = midi("F5") if False else 77


OUT_DIR = "assets/audio/music"


class Song:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.total = int(bars * beats_per_bar * self.beat * SR)
        self.buffers = {}

    def buf(self, name):
        if name not in self.buffers:
            self.buffers[name] = array.array("d", [0.0]) * (self.total + 4 * SR)
        return self.buffers[name]

    def play(self, track, start_beat, dur_beats, m, gain, wave_fn, attack=0.004, decay=0.05, sustain=0.75, release=0.03, vibrato=0.0):
        if m is None:
            return
        buf = self.buf(track)
        f = freq(m)
        s0 = int(start_beat * self.beat * SR)
        length = dur_beats * self.beat
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
            if vibrato and t > 0.15:
                ff = f * (1.0 + vibrato * math.sin(2 * math.pi * 5.0 * t))
            phase += ff / SR
            buf[s0 + i] += wave_fn(phase) * env * gain

    def kick(self, track, start_beat, gain=0.9, length=0.14):
        buf = self.buf(track)
        s0 = int(start_beat * self.beat * SR)
        ns = int(length * SR)
        phase = 0.0
        for i in range(ns):
            t = i / SR
            f = 40.0 + 120.0 * math.exp(-t * 28.0)
            phase += f / SR
            buf[s0 + i] += math.sin(2 * math.pi * phase) * math.exp(-t * 18.0) * gain

    def noise(self, track, start_beat, gain, length, damp, tone=0.0):
        buf = self.buf(track)
        s0 = int(start_beat * self.beat * SR)
        ns = int(length * SR)
        prev = 0.0
        for i in range(ns):
            t = i / SR
            env = math.exp(-t * damp)
            r = random.uniform(-1, 1)
            hp = r - prev * 0.6
            prev = r
            v = hp
            if tone:
                v = hp * 0.6 + math.sin(2 * math.pi * tone * t) * math.exp(-t * 40.0) * 0.6
            buf[s0 + i] += v * env * gain

    def echo(self, track, delay_beats, feedback, taps=3):
        buf = self.buf(track)
        d = int(delay_beats * self.beat * SR)
        src = array.array("d", buf)
        for k in range(1, taps + 1):
            g = feedback ** k
            off = d * k
            for i in range(off, len(buf)):
                buf[i] += src[i - off] * g

    def melody(self, track, bars, gain, wave_fn, legato=0.92, cap=None, **kw):
        cap = LEAD_CAP if cap is None else cap
        beat = 0.0
        for bar in bars:
            notes = [(midi(t.split(":")[0]), float(t.split(":")[1])) for t in bar.split()]
            highest = max((m for m, _ in notes if m is not None), default=0)
            shift = -12 if highest > cap else 0
            for m, dur in notes:
                self.play(track, beat, dur * legato, None if m is None else m + shift, gain, wave_fn, **kw)
                beat += dur
        assert abs(beat - self.bars * self.bpb) < 1e-6, beat

    def lowpass(self, track, cutoff_hz):
        buf = self.buf(track)
        a = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / SR)
        y = 0.0
        for i in range(len(buf)):
            y += a * (buf[i] - y)
            buf[i] = y

    def render(self, path, gains):
        for track, cutoff in (("lead", 1800.0), ("arp", 1600.0), ("drums", 4500.0), ("pad", 1200.0)):
            if track in self.buffers:
                self.lowpass(track, cutoff)
        mix = array.array("d", [0.0]) * self.total
        for name, buf in self.buffers.items():
            g = gains.get(name, 1.0)
            for i in range(len(buf)):
                j = i % self.total
                mix[j] += buf[i] * g
        peak = max(abs(v) for v in mix) or 1.0
        out = array.array("h")
        for v in mix:
            y = math.tanh(v / peak * 1.5) / math.tanh(1.5) * 0.9
            out.append(int(y * 32767))
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(out.tobytes())
        print("wrote", path, round(self.total / SR, 2), "seconds")


def dungeon_theme():
    """Slow, curious exploration theme in D dorian with a cavernous echo."""
    random.seed(11)
    song = Song(bpm=84, bars=16)
    melody = [
        "D4:1 F4:.5 A4:1.5 R:1",
        "B4:.5 A4:.5 G4:1 R:.5 D5:.5 B4:1",
        "A4:1 F4:.5 D4:1.5 R:.5 E4:.5",
        "C5:1 B4:.5 A4:.5 E4:1 R:1",
        "F4:.5 A4:.5 D5:1 C5:.5 A4:.5 R:1",
        "B4:1 G4:.5 E4:1 R:.5 G4:.5 A4:.5",
        "B4:1.5 D5:.5 G5:1 R:1",
        "F5:.5 E5:.5 D5:1 A4:1 R:1",
        "A4:.5 C5:.5 F5:1 E5:.5 C5:.5 R:1",
        "D5:1 B4:.5 G4:.5 A4:1 B4:1",
        "D5:.5 F5:.5 A5:1 G5:.5 F5:.5 D5:1",
        "E5:1.5 C5:.5 A4:1 R:1",
        "F4:.5 A4:.5 C5:1 A4:.5 F4:.5 R:1",
        "E4:.5 G4:.5 B4:1.5 A4:.5 G4:1",
        "A4:.5 B4:.5 D5:1 G5:.5 B5:.5 A5:1",
        "F5:1 E5:.5 D5:1.5 R:1",
    ]
    chords = ["Dm", "G", "Dm", "Am", "Dm", "Em", "G", "Dm", "F", "G", "Dm", "Am", "F", "Em", "G", "Dm"]
    defs = {
        "Dm": (62, [0, 3, 7, 9], 38),
        "G": (67, [0, 4, 7, 12], 43),
        "Am": (69, [0, 3, 7, 10], 45),
        "Em": (64, [0, 3, 7, 10], 40),
        "F": (65, [0, 4, 7, 12], 41),
    }
    song.melody("lead", melody, 0.34, triangle, legato=0.9, attack=0.01, decay=0.12, sustain=0.7, release=0.06, vibrato=0.004)
    song.echo("lead", 0.75, 0.38)
    pluck = pulse(0.125)
    for b, chord in enumerate(chords):
        root, iv, bass_root = defs[chord]
        start = b * 4.0
        tones = [root + i for i in iv]
        pattern = [0, 1, 2, 3, 2, 1, 3, 1]
        for k in range(8):
            swing = 0.07 if k % 2 else 0.0
            song.play("arp", start + k * 0.5 + swing, 0.32, tones[pattern[k]] - 12, 0.075, pluck, decay=0.04, sustain=0.35, release=0.03)
        song.play("bass", start, 2.9, bass_root, 0.26, triangle, attack=0.02, decay=0.2, sustain=0.8, release=0.1)
        song.play("bass", start + 3.0, 0.9, bass_root + (7 if b % 2 else 12), 0.2, triangle, attack=0.02, sustain=0.8, release=0.08)
        for offset, g in ((7, 0.045), (12, 0.04), (16 if chord in ("G", "F") else 15, 0.03)):
            song.play("pad", start, 4.0, root + offset - 12, g, triangle, attack=0.35, decay=0.1, sustain=1.0, release=0.4)
        if b % 2 == 0:
            song.kick("drums", start, 0.35, 0.16)
        song.noise("drums", start + 1.0, 0.09, 0.03, 120.0, 900.0)
        song.noise("drums", start + 3.0, 0.11, 0.03, 120.0, 700.0)
        for k in range(8):
            if k % 2 == 1:
                song.noise("drums", start + k * 0.5 + 0.07, 0.035, 0.02, 160.0)
    song.echo("arp", 0.5, 0.25, taps=2)
    song.render(OUT_DIR + "/theme.wav", {})


def battle_theme():
    """Upbeat chiptune in A minor, kept as an alternate track."""
    random.seed(7)
    song = Song(bpm=116, bars=16)
    melody = [
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
    chords = ["Am", "F", "C", "G", "Am", "F", "E", "E", "Dm", "Am", "Dm", "Am", "F", "G", "E", "E"]
    defs = {
        "Am": (69, [0, 3, 7], 45), "F": (65, [0, 4, 7], 41), "C": (60, [0, 4, 7], 48),
        "G": (67, [0, 4, 7], 43), "E": (64, [0, 4, 7], 40), "Dm": (62, [0, 3, 7], 38),
    }
    song.melody("lead", melody, 0.24, pulse(0.25), vibrato=0.005)
    for b, chord in enumerate(chords):
        root, iv, bass_root = defs[chord]
        start = b * 4.0
        tones = [root + iv[0], root + iv[1], root + iv[2], root + 12]
        pattern = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3]
        section_b = b >= 8
        for k in range(16):
            song.play("arp", start + k * 0.25, 0.22, tones[pattern[k]] - 12, 0.1 if section_b else 0.085, pulse(0.5), decay=0.03, sustain=0.5, release=0.02)
        offsets = [0, 12, 0, 0, 12, 0, 7, 12] if section_b else [0, 0, 12, 0, 0, 12, 0, 7]
        for k in range(8):
            song.play("bass", start + k * 0.5, 0.45, bass_root + offsets[k], 0.3, triangle, decay=0.04, sustain=0.85, release=0.03)
        for k in range(16):
            t = start + k * 0.25
            if k in (0, 8):
                song.kick("drums", t)
            if k == 10 and b % 2 == 1:
                song.kick("drums", t, 0.6)
            if k in (4, 12):
                song.noise("drums", t, 0.5, 0.13, 26.0, 190.0)
            if k % 2 == 0:
                song.noise("drums", t, 0.16 if k % 4 else 0.22, 0.035, 90.0)
    song.render(OUT_DIR + "/battle.wav", {})


def lydian_wonder():
    """F lydian: the raised fourth gives a sense of wonder. Floating lead, plucked arps."""
    random.seed(21)
    song = Song(bpm=88, bars=16)
    melody = [
        "F4:1 A4:.5 C5:1 B4:.5 A4:1",
        "G4:.5 B4:.5 D5:1.5 R:.5 B4:1",
        "A4:1 C5:.5 E5:1 D5:.5 C5:1",
        "G5:1 E5:.5 C5:1 R:.5 B4:.5 C5:.5",
        "A4:.5 C5:.5 F5:1 E5:.5 C5:.5 A4:1",
        "B4:1 D5:.5 G5:1 R:.5 A5:.5 G5:.5",
        "E5:1.5 C5:.5 A4:1 R:1",
        "G4:.5 B4:.5 C5:1 R:.5 E5:.5 G5:1",
        "D5:1 F5:.5 A5:1 G5:.5 F5:1",
        "B4:.5 D5:.5 G5:1 R:.5 B5:.5 A5:1",
        "F5:1 E5:.5 C5:1 A4:.5 R:1",
        "E5:.5 G5:.5 C6:1 B5:.5 G5:.5 E5:1",
        "D5:1 A4:.5 F4:1 R:.5 A4:.5 D5:.5",
        "E5:1 B4:.5 G4:1.5 R:1",
        "B4:.5 D5:.5 G5:1 A5:.5 B5:.5 D6:1",
        "C6:1 A5:.5 F5:1.5 R:1",
    ]
    chords = ["F", "G", "F", "C", "F", "G", "Am", "C", "Dm", "G", "F", "C", "Dm", "Em", "G", "F"]
    defs = {
        "F": (65, [0, 4, 7, 12], 41), "G": (67, [0, 4, 7, 12], 43), "C": (60, [0, 4, 7, 12], 48),
        "Am": (69, [0, 3, 7, 12], 45), "Dm": (62, [0, 3, 7, 12], 38), "Em": (64, [0, 3, 7, 12], 40),
    }
    song.melody("lead", melody, 0.32, triangle, legato=0.9, attack=0.012, decay=0.15, sustain=0.7, release=0.08, vibrato=0.004)
    song.echo("lead", 0.75, 0.36)
    pluck = pulse(0.125)
    for b, chord in enumerate(chords):
        root, iv, bass_root = defs[chord]
        start = b * 4.0
        tones = [root + i for i in iv]
        pattern = [0, 2, 1, 3, 2, 0, 3, 1]
        for k in range(8):
            song.play("arp", start + k * 0.5, 0.3, tones[pattern[k]] - 12, 0.07, pluck, decay=0.04, sustain=0.35, release=0.03)
        song.play("bass", start, 3.9, bass_root, 0.24, triangle, attack=0.02, decay=0.3, sustain=0.75, release=0.12)
        for offset, g in ((7, 0.04), (12, 0.035), (16, 0.025)):
            song.play("pad", start, 4.0, root + offset - 12, g, triangle, attack=0.4, decay=0.1, sustain=1.0, release=0.5)
        song.kick("drums", start, 0.3, 0.15)
        song.noise("drums", start + 1.0, 0.07, 0.03, 130.0, 1100.0)
        song.noise("drums", start + 3.0, 0.09, 0.03, 130.0, 900.0)
        for k in range(8):
            if k % 2 == 1:
                song.noise("drums", start + k * 0.5, 0.03, 0.02, 160.0)
    song.echo("arp", 0.5, 0.22, taps=2)
    song.render(OUT_DIR + "/lydian_wonder.wav", {})


def waltz():
    """A minor waltz in 3/4: whimsical, tiptoeing through the halls."""
    random.seed(33)
    song = Song(bpm=108, bars=24, beats_per_bar=3)
    melody = [
        "A4:1 C5:1 E5:1", "D5:1.5 C5:.5 B4:1", "F4:1 A4:1 D5:1", "C5:1.5 A4:.5 F4:1",
        "E4:1 G4:1 B4:1", "A4:1.5 G4:.5 E4:1", "A4:2 R:1", "R:1 E5:1 A5:1",
        "F5:1.5 E5:.5 C5:1", "A4:1 C5:1 F5:1", "D5:1.5 B4:.5 G4:1", "B4:1 D5:1 G5:1",
        "E5:2 C5:1", "A4:1.5 B4:.5 C5:1", "B4:1 G#4:1 E4:1", "R:1 G#4:1 B4:1",
        "C5:1 E5:1 A5:1", "F5:1.5 D5:.5 A4:1", "B4:1 D5:1 G5:1", "E5:1.5 G5:.5 C5:1",
        "A4:1 C5:1 F5:1", "D5:1.5 F5:.5 A5:1", "G#5:1 E5:1 B4:1", "B4:1 G#4:1 R:1",
    ]
    chords = ["Am", "Am", "Dm", "Dm", "Em", "Em", "Am", "Am", "F", "F", "G", "G", "Am", "Am", "E", "E",
              "Am", "Dm", "G", "C", "F", "Dm", "E", "E"]
    defs = {
        "Am": (69, [0, 3, 7], 45), "Dm": (62, [0, 3, 7], 38), "Em": (64, [0, 3, 7], 40),
        "F": (65, [0, 4, 7], 41), "G": (67, [0, 4, 7], 43), "E": (64, [0, 4, 7], 40), "C": (60, [0, 4, 7], 48),
    }
    song.melody("lead", melody, 0.3, triangle, legato=0.88, attack=0.01, decay=0.12, sustain=0.7, release=0.06, vibrato=0.005)
    song.echo("lead", 1.0, 0.3, taps=2)
    stab = pulse(0.125)
    for b, chord in enumerate(chords):
        root, iv, bass_root = defs[chord]
        start = b * 3.0
        song.play("bass", start, 0.9, bass_root, 0.3, triangle, decay=0.1, sustain=0.7, release=0.08)
        for beat in (1.0, 2.0):
            for i in iv:
                song.play("arp", start + beat, 0.4, root + i - 12, 0.05, stab, decay=0.05, sustain=0.3, release=0.04)
        song.kick("drums", start, 0.3, 0.14)
        song.noise("drums", start + 1.0, 0.05, 0.025, 150.0, 1200.0)
        song.noise("drums", start + 2.0, 0.05, 0.025, 150.0, 1200.0)
    song.render(OUT_DIR + "/waltz.wav", {})


def deep_halls():
    """Slow pentatonic bells over a drone, long echoes: a vast, quiet place worth exploring."""
    random.seed(44)
    song = Song(bpm=72, bars=12)
    melody = [
        "A4:2 R:1 C5:1", "E5:2 D5:1 R:1", "G4:1 A4:2 R:1", "R:2 E5:1 G5:1",
        "D5:2 F5:1 R:1", "A5:2 R:1 G5:1", "E5:1.5 C5:.5 A4:2", "R:2 B4:1 C5:1",
        "C5:2 A4:1 F4:1", "G4:1 B4:1 D5:2", "E5:2 R:1 A5:1", "G5:1 E5:1 A4:2",
    ]
    chords = ["Am", "Am", "Am", "Am", "Dm", "Dm", "Am", "Am", "F", "G", "Am", "Am"]
    defs = {"Am": (69, 45), "Dm": (62, 38), "F": (65, 41), "G": (67, 43)}
    song.melody("lead", melody, 0.5, bell, legato=1.0, attack=0.003, decay=1.6, sustain=0.0, release=0.05)
    song.echo("lead", 0.5, 0.45, taps=4)
    for b, chord in enumerate(chords):
        root, bass_root = defs[chord]
        start = b * 4.0
        song.play("bass", start, 4.0, bass_root - 12, 0.22, triangle, attack=0.3, decay=0.2, sustain=0.9, release=0.4)
        song.play("bass", start, 4.0, bass_root + 7 - 12, 0.1, triangle, attack=0.5, decay=0.2, sustain=0.9, release=0.4)
        for offset, g in ((0, 0.04), (7, 0.035), (12, 0.03)):
            song.play("pad", start, 4.0, root + offset - 12, g, triangle, attack=0.6, decay=0.1, sustain=1.0, release=0.6)
        song.kick("drums", start, 0.25, 0.18)
        song.noise("drums", start + 2.0, 0.06, 0.03, 120.0, 800.0)
        for k in range(8):
            song.noise("drums", start + k * 0.5 + 0.25, 0.025, 0.02, 200.0)
    song.render(OUT_DIR + "/deep_halls.wav", {})


def clockwork():
    """E harmonic minor with a ticking ostinato: tense curiosity, something is turning."""
    random.seed(55)
    song = Song(bpm=96, bars=16)
    melody = [
        "E5:.5 R:.5 G5:.5 F#5:.5 E5:1 B4:1",
        "D#5:.5 E5:.5 F#5:1 G5:.5 F#5:.5 E5:1",
        "A4:.5 C5:.5 E5:1 D5:.5 C5:.5 B4:1",
        "D#5:1 F#5:.5 A5:.5 B5:1 R:1",
        "G5:.5 F#5:.5 E5:1 D#5:.5 E5:.5 B4:1",
        "C5:.5 E5:.5 G5:1 A5:.5 G5:.5 E5:1",
        "F#5:.5 D#5:.5 B4:1 R:.5 A4:.5 B4:1",
        "E5:2 R:2",
        "B4:.5 E5:.5 G5:1 B5:1 G5:1",
        "A5:.5 F#5:.5 D5:1 E5:.5 F#5:.5 A5:1",
        "G5:1 E5:.5 C5:1 R:.5 D5:.5 E5:.5",
        "F#5:1 D#5:.5 B4:1.5 R:1",
        "E5:.5 G5:.5 B5:1 A5:.5 G5:.5 F#5:1",
        "E5:.5 C5:.5 A4:1 B4:.5 C5:.5 D5:1",
        "D#5:1 F#5:1 A5:.5 B5:.5 D#6:1",
        "E6:1 B5:.5 G5:1 E5:1.5",
    ]
    chords = ["Em", "Em", "Am", "B7", "Em", "C", "B7", "Em", "Em", "D", "C", "B7", "Em", "Am", "B7", "Em"]
    defs = {
        "Em": (64, [0, 3, 7, 12], 40), "Am": (69, [0, 3, 7, 12], 45), "B7": (59, [0, 4, 7, 10], 47),
        "C": (60, [0, 4, 7, 12], 48), "D": (62, [0, 4, 7, 12], 38),
    }
    song.melody("lead", melody, 0.2, pulse(0.25), legato=0.9, vibrato=0.005)
    song.echo("lead", 0.75, 0.25, taps=2)
    tick = pulse(0.125)
    for b, chord in enumerate(chords):
        root, iv, bass_root = defs[chord]
        start = b * 4.0
        tones = [root + i for i in iv]
        pattern = [0, 2, 1, 3, 0, 2, 1, 3, 0, 2, 1, 3, 2, 3, 1, 2]
        for k in range(16):
            song.play("arp", start + k * 0.25, 0.14, tones[pattern[k]], 0.06, tick, decay=0.02, sustain=0.3, release=0.02)
        for k, offset in ((0, 0), (1.5, 0), (2.0, 7), (3.0, 12), (3.5, 0)):
            song.play("bass", start + k, 0.45, bass_root + offset, 0.28, triangle, decay=0.04, sustain=0.8, release=0.03)
        song.kick("drums", start, 0.6)
        song.kick("drums", start + 2.0, 0.5)
        song.noise("drums", start + 1.0, 0.12, 0.05, 90.0, 600.0)
        song.noise("drums", start + 3.0, 0.14, 0.05, 90.0, 600.0)
        for k in range(8):
            song.noise("drums", start + k * 0.5, 0.05 if k % 2 else 0.08, 0.03, 120.0)
    song.render(OUT_DIR + "/clockwork.wav", {})


PIECES = {
    "theme": dungeon_theme,
    "battle": battle_theme,
    "lydian_wonder": lydian_wonder,
    "waltz": waltz,
    "deep_halls": deep_halls,
    "clockwork": clockwork,
}

if __name__ == "__main__":
    import sys
    names = sys.argv[2:] or list(PIECES)
    if len(sys.argv) > 1:
        OUT_DIR = sys.argv[1]
    for name in names:
        PIECES[name]()
