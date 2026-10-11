#!/usr/bin/env python3
"""HURDALIK TEMASI — hurdalığın özgün müziği (docs/HURDALIK_TASARIM.md §7): ağır blues shuffle, çelik telli
gitar boogie'si, yürüyen kontrbas, mızıka ezgisi; ikinci turda hafif kirli gitar solosu. Arkada fırçalı
davul, ara ara metal tıngırtısı (hurda) ve uzaktan pres gümbürtüsü.

Form: E'de 12 ölçülük blues × 2 tur (24 ölçü, ~70 sn döngü). Son ölçü B7 (turnaround) → döngü E7'ye döner.
Beste bu dosyadadır; MIDI yazımı ve döngü basımı music_lib.py'de.
Kullanım: tools/music/junkyard_theme.py [çıktı.wav]   (varsayılan assets/audio/music/junkyard_theme.wav)
"""
from music_lib import DRUMS, Song, n, render_loop

BPM = 82
BARS = 24
SWING = 2.0 / 3.0         # shuffle: ikinci sekizlik üçlemenin sonuna

RHYTHM, HARP, LEAD, BASS, CLANK = 0, 1, 2, 3, 4
MIX = {
    RHYTHM: {"program": 25, "volume": 88, "pan": 40, "reverb": 35},    # çelik telli akustik gitar
    HARP: {"program": 22, "volume": 92, "pan": 72, "reverb": 50},      # mızıka
    LEAD: {"program": 29, "volume": 66, "pan": 84, "reverb": 55},      # hafif kirli elektro gitar
    BASS: {"program": 32, "volume": 100, "pan": 64, "reverb": 15},     # kontrbas
    CLANK: {"program": 113, "volume": 46, "pan": 30, "reverb": 90},    # agogo: metal tıngırtısı
    DRUMS: {"volume": 70, "pan": 64, "reverb": 35},
}

# 12 ölçülük blues (E): I I I I · IV IV I I · V IV I V
TWELVE = ["E7", "E7", "E7", "E7", "A7", "A7", "E7", "E7", "B7", "A7", "E7", "B7"]
FORM = TWELVE + TWELVE
ROOT = {"E7": "E2", "A7": "A2", "B7": "B2"}
# Yürüyen bas: kök, büyük üçlü, beşli, altılı (shuffle'da çeyrekler)
WALK = {"E7": ["E2", "G#2", "B2", "C#3"], "A7": ["A1", "C#2", "E2", "F#2"], "B7": ["B1", "D#2", "F#2", "G#2"]}

# Mızıka ezgisi: E blues dizisinden (E G A A# B D), soru-cevap. Her eleman bir ölçü: (vuruş, süre, nota)
HARP_MELODY = [
    [(0, 1.5, "B4"), (1.5, .5, "D5"), (2, 1, "E5"), (3, .5, "D5"), (3.5, .5, "B4")],
    [(0, 2.5, "G4"), (3, 1, "E4")],
    [(0, .5, "E4"), (.5, .5, "G4"), (1, 1, "A4"), (2, .5, "A#4"), (2.5, .5, "B4"), (3, 1, "D5")],
    [(0, 3, "E5")],
    [(0, 1.5, "E5"), (1.5, .5, "C#5"), (2, 1, "A4"), (3, 1, "G4")],
    [(0, .5, "A4"), (.5, .5, "C#5"), (1, 1, "E5"), (2, 2, "C#5")],
    [(0, 1, "B4"), (1, .5, "G4"), (1.5, .5, "A4"), (2, 1, "B4"), (3, 1, "E4")],
    [(0, 3, "E4")],
    [(0, 1, "F#5"), (1, 1, "D#5"), (2, 1, "B4"), (3, 1, "A4")],
    [(0, 1, "E5"), (1, .5, "C#5"), (1.5, .5, "A4"), (2, 2, "G4")],
    [(0, .5, "E4"), (.5, .5, "G4"), (1, .5, "A4"), (1.5, .5, "B4"), (2, 2, "E5")],
    [(0, 1, "D#5"), (1, 1, "F#5"), (2, 2, "B4")],
]
# İkinci tur: gitar solosu (aynı iskelet, daha hareketli), mızıka yalnız uzun notalarla eşlik eder
LEAD_MELODY = [
    [(0, .5, "B4"), (.5, .5, "D5"), (1, .5, "E5"), (1.5, .5, "G5"), (2, 1, "E5"), (3, 1, "D5")],
    [(0, 1, "B4"), (1, .5, "A4"), (1.5, .5, "G4"), (2, 2, "E4")],
    [(0, .5, "G4"), (.5, .5, "A4"), (1, .5, "A#4"), (1.5, .5, "B4"), (2, .5, "D5"), (2.5, .5, "E5"), (3, 1, "G5")],
    [(0, 2, "E5"), (2, 1, "D5"), (3, 1, "B4")],
    [(0, .5, "A4"), (.5, .5, "C#5"), (1, .5, "E5"), (1.5, .5, "G5"), (2, 1, "E5"), (3, 1, "C#5")],
    [(0, 1, "A4"), (1, 1, "G4"), (2, 2, "E4")],
    [(0, .5, "E5"), (.5, .5, "D5"), (1, .5, "B4"), (1.5, .5, "A4"), (2, 1, "G4"), (3, 1, "E4")],
    [(0, 2, "B4"), (2, 2, "E5")],
    [(0, .5, "F#5"), (.5, .5, "D#5"), (1, .5, "B4"), (1.5, .5, "A4"), (2, 1, "F#4"), (3, 1, "B4")],
    [(0, .5, "E5"), (.5, .5, "C#5"), (1, 1, "A4"), (2, 1, "G4"), (3, 1, "E4")],
    [(0, .5, "G4"), (.5, .5, "A4"), (1, .5, "B4"), (1.5, .5, "D5"), (2, 2, "E5")],
    [(0, 1, "B4"), (1, 1, "D#5"), (2, 2, "F#5")],
]


def compose(song: Song, offset_bars: int) -> None:
    for bar, chord in enumerate(FORM):
        base = (offset_bars + bar) * 4
        chorus = bar // 12
        root = n(ROOT[chord])
        # RİTİM GİTAR: boogie (kök + beşli, kök + altılı), shuffle sekizlik
        for beat in range(4):
            for half, interval in ((0.0, 7), (0.5, 9 if beat % 2 else 7)):
                vel = 64 if half == 0 else 50
                song.note(RHYTHM, base + beat + half, 0.42, root, vel)
                song.note(RHYTHM, base + beat + half, 0.42, root + interval, vel - 6, 0.02)
        # BAS: yürüyen çeyrekler
        for beat, name in enumerate(WALK[chord]):
            song.note(BASS, base + beat, 0.9, n(name), 88 if beat == 0 else 74)
        # EZGİ
        if chorus == 0:
            for beat, dur, name in HARP_MELODY[bar % 12]:
                song.note(HARP, base + beat, dur, n(name), 92)
        else:
            for beat, dur, name in LEAD_MELODY[bar % 12]:
                song.note(LEAD, base + beat, dur, n(name), 84)
            if bar % 2 == 0:   # mızıka uzun notalarla arkada
                song.note(HARP, base, 3.5, n(HARP_MELODY[bar % 12][0][2]) - 12, 48)
        # DAVUL: yumuşak bas davul, 2 ve 4'te rim, shuffle hi-hat
        song.note(DRUMS, base, 0.3, 36, 66)
        song.note(DRUMS, base + 2, 0.3, 36, 52)
        for hit in (1, 3):
            song.note(DRUMS, base + hit, 0.2, 37, 60)
        for k in range(8):
            song.note(DRUMS, base + k * 0.5, 0.2, 42, 40 if k % 2 == 0 else 28)
        # HURDA: iki ölçüde bir metal tıngırtısı (alçak agogo), dört ölçüde bir uzaktan pres gümbürtüsü
        if bar % 2 == 1:
            song.note(CLANK, base + 3.5, 0.3, n("E3") if bar % 4 == 1 else n("G3"), 60)
        if bar % 4 == 0:
            song.note(DRUMS, base + 0.02, 0.6, 41, 44)   # alçak yer tomu
            song.note(DRUMS, base + 0.04, 0.6, 35, 50)
        if bar % 12 == 11:   # turnaround dolgusu
            song.note(DRUMS, base + 3, 0.25, 45, 52)
            song.note(DRUMS, base + 3.5, 0.25, 43, 50)


if __name__ == "__main__":
    render_loop(Song(BPM, SWING, MIX), compose, BARS, "assets/audio/music/junkyard_theme.wav")
