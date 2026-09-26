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


class Song:
    def __init__(self, bpm, bars):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.total = int(bars * 4 * self.beat * SR)
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

    def melody(self, track, bars, gain, wave_fn, legato=0.92, **kw):
        beat = 0.0
        for bar in bars:
            for token in bar.split():
                name, dur = token.split(":")
                dur = float(dur)
                self.play(track, beat, dur * legato, midi(name), gain, wave_fn, **kw)
                beat += dur
        assert abs(beat - self.bars * 4) < 1e-6, beat

    def render(self, path, gains):
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
    song.render("assets/audio/music/theme.wav", {"lead": 1.0, "arp": 1.0, "bass": 1.0, "pad": 1.0, "drums": 1.0})


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
    song.render("assets/audio/music/battle.wav", {})


if __name__ == "__main__":
    dungeon_theme()
    battle_theme()
