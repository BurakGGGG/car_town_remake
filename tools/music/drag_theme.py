#!/usr/bin/env python3
"""DRAG YARIŞI TEMASI — yarış ekranının özgün müziği: sert, hızlı rock (distortion gitar riff'i, synth bas,
testere dişi lead, tam davul). Garaj temasının tersine swing yok, La minör, 150 BPM.

Beste bu dosyadadır; MIDI yazımı ve döngü basımı music_lib.py'de.
Kullanım: tools/music/drag_theme.py [çıktı.wav]   (varsayılan assets/audio/music/drag_theme.wav)
"""
from music_lib import DRUMS, Song, n, render_loop

BPM = 150
BARS = 24                 # döngü uzunluğu (ölçü): RIFF + HOOK + DRIVE
SWING = 0.5               # düz sekizlik

DIST, OVERDRIVE, BASS, LEAD = 0, 1, 2, 3
MIX = {
    DIST: {"program": 30, "volume": 88, "pan": 30, "reverb": 18},        # Distortion Guitar
    OVERDRIVE: {"program": 29, "volume": 78, "pan": 98, "reverb": 18},   # Overdriven Guitar (genişlik)
    BASS: {"program": 38, "volume": 100, "pan": 64, "reverb": 8},        # Synth Bass 1
    LEAD: {"program": 81, "volume": 82, "pan": 64, "reverb": 35},        # Lead 2 (sawtooth)
    DRUMS: {"volume": 100, "pan": 64, "reverb": 20},
}

# Güç akorları (kök + beşli + oktav) ve bas kökleri
POWER = {"A": "A2", "C": "C3", "D": "D3", "E": "E2", "F": "F2", "G": "G2"}
BASS_ROOT = {"A": "A1", "C": "C2", "D": "D2", "E": "E1", "F": "F1", "G": "G1"}

RIFF = ["A", "A", "F", "G", "A", "A", "F/G", "E"]          # 1. bölüm: yalnız riff
HOOK = ["F", "G", "A", "A", "F", "G", "E", "E"]            # 2. bölüm: lead melodisi
DRIVE = ["A", "A", "F", "G", "A", "A", "F", "E"]           # 3. bölüm: vurucu motif; E → döngü A'ya döner
FORM = RIFF + HOOK + DRIVE

MELODY_HOOK = [
    [(0, .5, "A5"), (.5, .5, "C6"), (1, .5, "A5"), (1.5, .5, "G5"), (2, 1, "F5"), (3, 1, "A5")],
    [(0, .5, "G5"), (.5, .5, "B5"), (1, 1, "D6"), (2, .5, "B5"), (2.5, .5, "G5"), (3, 1, "D6")],
    [(0, 1.5, "E6"), (1.5, .5, "D6"), (2, 1, "C6"), (3, 1, "B5")],
    [(0, 3, "A5"), (3, 1, "E5")],
    [(0, .5, "A5"), (.5, .5, "C6"), (1, 1, "F6"), (2, .5, "E6"), (2.5, .5, "C6"), (3, 1, "A5")],
    [(0, .5, "B5"), (.5, .5, "D6"), (1, 1, "G6"), (2, .5, "F6"), (2.5, .5, "D6"), (3, 1, "B5")],
    [(0, 1, "E6"), (1, 1, "D6"), (2, 1, "C6"), (3, 1, "B5")],
    [(0, 2, "G#5"), (2, 1, "B5"), (3, 1, "E6")],
]
_STAB = [(0, .5, "A5"), (.5, .5, "A5"), (1, .5, "C6"), (1.5, .5, "A5"), (2, .5, "D6"), (2.5, .5, "C6"), (3, 1, "E6")]
_FALL = [(0, .5, "E6"), (.5, .5, "D6"), (1, .5, "C6"), (1.5, .5, "A5"), (2, 1, "G5"), (3, 1, "A5")]
MELODY_DRIVE = [
    _STAB, _FALL,
    [(0, .5, "A5"), (.5, .5, "A5"), (1, .5, "C6"), (1.5, .5, "A5"), (2, .5, "F6"), (2.5, .5, "E6"), (3, 1, "C6")],
    [(0, .5, "D6"), (.5, .5, "B5"), (1, .5, "G5"), (1.5, .5, "B5"), (2, 1, "D6"), (3, 1, "G6")],
    _STAB, _FALL,
    [(0, 1, "F6"), (1, 1, "E6"), (2, 1, "C6"), (3, 1, "A5")],
    [(0, 2, "G#5"), (2, 2, "B5")],
]


def _bar_chords(symbol: str) -> list[tuple[float, float, str]]:
    if "/" in symbol:
        a, b = symbol.split("/")
        return [(0, 2, a), (2, 2, b)]
    return [(0, 4, symbol)]


def compose(song: Song, offset_bars: int) -> None:
    melodies = [None] * 8 + MELODY_HOOK + MELODY_DRIVE
    for bar, symbol in enumerate(FORM):
        base = (offset_bars + bar) * 4
        section = bar // 8           # 0: RIFF  1: HOOK  2: DRIVE
        last_of_section = bar % 8 == 7
        for start, length, chord in _bar_chords(symbol):
            root = n(POWER[chord])
            voicing = [root, root + 7, root + 12]
            # GİTAR: sekizlik "chug"; vurgulu vuruşlar açık ve uzun, diğerleri susturulmuş (kısa, kısık)
            for k in range(int(length * 2)):
                hit = start + k * 0.5
                accent = hit in (0, 1.5, 3) or (section == 1 and hit % 1 == 0)
                dur = 0.48 if accent else 0.22
                vel = 104 if accent else 74
                for i, pitch in enumerate(voicing):
                    song.note(DIST, base + hit, dur, pitch, vel - i * 4, i * 0.01)
                    song.note(OVERDRIVE, base + hit, dur, pitch, vel - 8 - i * 4, 0.012 + i * 0.01)
            # BAS: sekizlik kök, ikinci yarıda oktav sıçraması
            low = n(BASS_ROOT[chord])
            for k in range(int(length * 2)):
                hit = start + k * 0.5
                pitch = low + 12 if (hit % 2 == 1.5) else low
                song.note(BASS, base + hit, 0.42, pitch, 100 if hit % 1 == 0 else 84)
        # LEAD
        if melodies[bar]:
            for beat, dur, name in melodies[bar]:
                song.note(LEAD, base + beat, dur, n(name), 100 if section == 1 else 108)
                if section == 2:   # son bölüm: bir oktav altta ikiz (daha dolu)
                    song.note(LEAD, base + beat, dur, n(name) - 12, 70)
        # DAVUL: rock ritmi (bas 1 / 3 / 3½, trampet 2 / 4), sekizlik hi-hat; son bölümde açık hi-hat
        for hit in (0, 2, 2.5):
            song.note(DRUMS, base + hit, 0.3, 36, 112)
        if section == 2:
            song.note(DRUMS, base + 1.5, 0.3, 36, 90)
        for k in range(8):
            hat = 46 if (section == 2 and k % 2 == 1) else 42
            song.note(DRUMS, base + k * 0.5, 0.2, hat, 82 if k % 2 == 0 else 62)
        if bar % 4 == 0:
            song.note(DRUMS, base, 1.0, 49, 108)          # crash: her 4 ölçüde bir
        if last_of_section:
            song.note(DRUMS, base + 1, 0.3, 38, 112)
            # DOLGU: son iki vuruş onaltılık trampet + tomlar (son bölümde kreşendo trampet)
            fill = [38, 38, 50, 50, 47, 47, 45, 45] if section < 2 else [38] * 8
            for k, pitch in enumerate(fill):
                song.note(DRUMS, base + 2 + k * 0.25, 0.2, pitch, 84 + k * 5)
        else:
            for hit in (1, 3):
                song.note(DRUMS, base + hit, 0.3, 38, 112)


if __name__ == "__main__":
    render_loop(Song(BPM, SWING, MIX), compose, BARS, "assets/audio/music/drag_theme.wav", gain=0.42)
