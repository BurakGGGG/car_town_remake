#!/usr/bin/env python3
"""GARAJ TEMASI — oyunun özgün arka plan müziği (Car Town havasında: neşeli, tatlı, swing'li).

Beste bu dosyadadır; MIDI yazımı ve döngü basımı music_lib.py'de.
Kullanım: tools/music/garage_theme.py [çıktı.wav]   (varsayılan assets/audio/music/garage_theme.wav)
"""
from music_lib import DRUMS, Song, n, render_loop

BPM = 112
BARS = 32                 # döngü uzunluğu (ölçü)
SWING = 2.0 / 3.0         # vuruş içi ikinci sekizlik buraya kayar (0.5 = düz)

# --- Kanallar (GM program numaraları) ---------------------------------------------------------
GUITAR, MARIMBA, GLOCK, WHISTLE, BASS, PIZZ = 0, 1, 2, 3, 4, 5
MIX = {
    GUITAR: {"program": 24, "volume": 92, "pan": 44, "reverb": 40},
    MARIMBA: {"program": 12, "volume": 110, "pan": 64, "reverb": 45},
    GLOCK: {"program": 9, "volume": 62, "pan": 80, "reverb": 60},
    WHISTLE: {"program": 78, "volume": 84, "pan": 60, "reverb": 55},
    BASS: {"program": 32, "volume": 104, "pan": 64, "reverb": 15},
    PIZZ: {"program": 45, "volume": 70, "pan": 88, "reverb": 45},
    DRUMS: {"volume": 78, "pan": 64, "reverb": 25},
}

# --- Armoni: her ölçü bir akor (yarım ölçülük akorlar "A/B" biçiminde) ---------------------------
CHORDS = {
    "C": ["C4", "E4", "G4", "C5"], "Am": ["A3", "E4", "A4", "C5"], "F": ["F3", "C4", "F4", "A4"],
    "G": ["G3", "D4", "G4", "B4"], "Dm": ["D4", "F4", "A4", "D5"], "Em": ["E4", "G4", "B4", "E5"],
    "G7": ["G3", "D4", "F4", "B4"], "Dm7": ["D4", "F4", "A4", "C5"],
}
ROOTS = {"C": "C2", "Am": "A1", "F": "F1", "G": "G1", "Dm": "D2", "Em": "E2", "G7": "G1", "Dm7": "D2"}
FIFTHS = {"C": "G2", "Am": "E2", "F": "C2", "G": "D2", "Dm": "A2", "Em": "B2", "G7": "D2", "Dm7": "A2"}

SECTION_A = ["C", "Am", "F", "G", "C", "Am", "Dm", "G"]          # G'de biter: devam eder
SECTION_A2 = ["C", "Am", "F", "G", "C", "Am", "Dm/G", "C"]       # C'de kapanır
SECTION_B = ["F", "G", "Em", "Am", "Dm", "G", "C", "C/G7"]       # G7: başa dönüş hazırlığı
FORM = SECTION_A + SECTION_A2 + SECTION_B + SECTION_A            # son A G'de biter → döngü C'ye döner

# --- Melodiler: (vuruş, süre, nota) ölçü içinde --------------------------------------------------
MELODY_A = [
    [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "C6"), (3, .5, "G5"), (3.5, .5, "E5")],
    [(0, 1.5, "A5"), (1.5, .5, "G5"), (2, 1, "E5"), (3, 1, "C5")],
    [(0, .5, "F5"), (.5, .5, "A5"), (1, 1, "C6"), (2, .5, "A5"), (2.5, .5, "F5"), (3, 1, "G5")],
    [(0, 1, "D5"), (1, 1, "G5"), (2, 1.5, "B4")],
    [(0, .5, "E5"), (.5, .5, "F5"), (1, 1, "G5"), (2, .5, "E5"), (2.5, .5, "G5"), (3, 1, "C6")],
    [(0, 1.5, "E6"), (1.5, .5, "D6"), (2, 1, "C6"), (3, 1, "A5")],
    [(0, 1, "F5"), (1, 1, "A5"), (2, .5, "D6"), (2.5, .5, "C6"), (3, 1, "A5")],
    [(0, 1, "G5"), (1, .5, "F5"), (1.5, .5, "D5"), (2, 1, "B4"), (3, 1, "G4")],
]
MELODY_A2 = MELODY_A[:6] + [
    [(0, 1, "F5"), (1, 1, "A5"), (2, 1, "B5"), (3, 1, "D6")],
    [(0, 3, "C6")],
]
MELODY_B = [
    [(0, 1, "A5"), (1, .5, "A5"), (1.5, .5, "G5"), (2, 1, "A5"), (3, 1, "C6")],
    [(0, 1.5, "B5"), (1.5, .5, "A5"), (2, 2, "G5")],
    [(0, .5, "G5"), (.5, .5, "G5"), (1, 1, "E5"), (2, 1, "G5"), (3, 1, "B5")],
    [(0, 3, "A5")],
    [(0, 1, "F5"), (1, .5, "A5"), (1.5, .5, "F5"), (2, 1, "D6"), (3, 1, "C6")],
    [(0, 1, "B5"), (1, 1, "A5"), (2, 1, "G5"), (3, 1, "D5")],
    [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "C6"), (3, 1, "E6")],
    [(0, 2, "D6"), (2, 1, "B5"), (3, 1, "G5")],
]


def _bar_chords(symbol: str) -> list[tuple[float, float, str]]:
    """Ölçünün akorları: [(vuruş, süre, akor)]."""
    if "/" in symbol:
        a, b = symbol.split("/")
        return [(0, 2, a), (2, 2, b)]
    return [(0, 4, symbol)]


def compose(song: Song, offset_bars: int) -> None:
    melodies = MELODY_A + MELODY_A2 + MELODY_B + MELODY_A
    for bar, symbol in enumerate(FORM):
        base = (offset_bars + bar) * 4
        section = bar // 8           # 0: A  1: A'  2: B  3: A (son)
        # GİTAR (ukulele havası): swing'li tıngırtı; aşağı vuruşlar güçlü, yukarı vuruşlar hafif
        for start, length, chord in _bar_chords(symbol):
            for hit, vel in [(0, 70), (1, 56), (1.5, 44), (2.5, 46), (3, 54), (3.5, 40)]:
                if not (start <= hit < start + length):
                    continue
                voicing = [n(p) for p in CHORDS[chord]]
                upstroke = hit % 1 != 0
                if upstroke:
                    voicing = list(reversed(voicing))
                for i, pitch in enumerate(voicing):   # teller sırayla (strum)
                    song.note(GUITAR, base + hit, 0.45, pitch, vel - i * 3, i * 0.025)
            # BAS: kök + beşli, ölçü sonunda bir sonraki köke yaklaşma
            root, fifth = n(ROOTS[chord]), n(FIFTHS[chord])
            if length == 4:
                song.note(BASS, base, 1.4, root, 92)
                song.note(BASS, base + 2, 1.0, fifth, 80)
                song.note(BASS, base + 3, 0.5, root + 12 if bar % 2 else fifth, 68)
                song.note(BASS, base + 3.5, 0.5, root, 72)
            else:
                song.note(BASS, base + start, 1.4, root, 90)
                song.note(BASS, base + start + 1.5, 0.5, fifth, 70)
        # MELODİ
        for beat, dur, name in melodies[bar]:
            pitch = n(name)
            if section == 2:
                song.note(WHISTLE, base + beat, dur, pitch - 12, 92)       # köprü: ıslık
                song.note(GLOCK, base + beat, min(dur, 0.5), pitch, 34)    # ıslığa ince parıltı
            elif section == 3:
                song.note(MARIMBA, base + beat, dur, pitch, 92)
                song.note(WHISTLE, base + beat, dur, pitch - 12, 58)       # son tur: ıslık eşliği
                song.note(GLOCK, base + beat, min(dur, 0.5), pitch + 12, 40)
            else:
                song.note(MARIMBA, base + beat, dur, pitch, 96 if section == 0 else 90)
                song.note(GLOCK, base + beat, min(dur, 0.5), pitch + 12, 46)
        # PİZZİKATO karşı ezgi (A' ve son A): akor seslerinden ikinci ve dördüncü vuruşta
        if section in (1, 3):
            for start, length, chord in _bar_chords(symbol):
                tones = [n(p) for p in CHORDS[chord]]
                for k, hit in enumerate([1, 3]):
                    if start <= hit < start + length:
                        song.note(PIZZ, base + hit, 0.4, tones[1 + k] + 12, 64)
        # DAVUL: yumuşak bas davul, rim, swing'li shaker; köprüde el çırpma
        song.note(DRUMS, base, 0.3, 36, 72)
        song.note(DRUMS, base + 2, 0.3, 36, 60)
        song.note(DRUMS, base + 2.5, 0.3, 36, 40)
        for hit in (1, 3):
            song.note(DRUMS, base + hit, 0.2, 39 if section == 2 else 37, 62 if section == 2 else 70)
        for k in range(8):
            song.note(DRUMS, base + k * 0.5, 0.2, 70, 46 if k % 2 == 0 else 32)
        if bar % 8 == 7:   # bölüm sonu: küçük dolgu
            song.note(DRUMS, base + 3, 0.25, 76, 60)
            song.note(DRUMS, base + 3.5, 0.25, 77, 56)


if __name__ == "__main__":
    render_loop(Song(BPM, SWING, MIX), compose, BARS, "assets/audio/music/garage_theme.wav")
