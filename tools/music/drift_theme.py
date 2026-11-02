#!/usr/bin/env python3
"""DRIFT TEMASI — şehirde nadir görülen JAPON DRIFT OLAYININ özgün müziği (2026-11-02): Eurobeat enerjisi + Japon
rengi (koto, taiko). TEK SEFERLİK (döngü değil): olay başlarken çalar, araçlar ekrana DROP anında girer.

Zaman sözleşmesi (oyun arabaları buna göre zamanlar — örnek doğruluğunda):
  155 BPM, 4/4. Ölçü 1–4 GİRİŞ (0 → 6,193548 sn): 1–2 koto hirajoshi riff'i + taiko + kapalı süzgeçli pad şişmesi,
  3–4 Eurobeat yükselişi (16'lık hi-hat, hızlanan trampet, gürültü yükselişi, süzgeci açılan süpersaw arpeji, bas
  pedalı); 4. ölçünün son vuruşu BOŞLUK (yalnız ters zil). DROP tam 5. ölçünün ilk vuruşunda = 16 vuruş =
  6,193548 sn (orkestra vuruşu + zil + tam nakarat). Ölçü 5–10 NAKARAT (6 ölçü: Bb C Am Dm | Bb-C Gm-A; 9–10'da
  akorlar yarım ölçü, koto ezgiyi bir oktav üstten çiftler). Ölçü 11–12 ÇIKIŞ: 11. ölçünün ilk vuruşunda (40. vuruş,
  15,483871 sn) Dm'de son akor + orkestra vuruşu, sonra koto inişi + taiko, yankı kuyruğu (2026-11-02: araçlar
  ekranda drop'tan sonra ~5–7 sn kalıyor → nakarat 8 ölçüden 6'ya indi).

Ezgi ve akorlar ÖZGÜNDÜR (bilinen hiçbir Eurobeat şarkısından alınmadı). EDM bölümleri numpy ile sentezlenir
(synth_lib: polyBLEP süpersaw, SVF süzgeç zarfları, sentez davul, FFT oda yankısı, kick'ten sidechain); koto, taiko,
orkestra vuruşu ve brass FluidSynth + FluidR3 GM ile basılır.

Kullanım (sistem python'unda numpy yok → Blender'ın python'u):
  /snap/blender/current/5.2/python/bin/python3.13 -I tools/music/drift_theme.py [çıktı.wav]
  (varsayılan assets/audio/music/drift_theme.wav). Godot içe aktarımında edit/loop_mode=1 (döngü YOK).
"""
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from music_lib import ROOT, SOUNDFONT, Song, n  # noqa: E402
import synth_lib as S  # noqa: E402
from synth_lib import SR  # noqa: E402

BPM = 155
SPB = SR * 60.0 / BPM            # vuruş başına örnek (17070,97)
BARS = 12
BREAK_BEAT = 15                  # 4. ölçünün son vuruşu: boşluk
DROP_BEAT = 16                   # 5. ölçünün ilk vuruşu
END_BEAT = 40                    # 11. ölçü: son akor (15,483871 sn)
TAIL = 2.4                       # 12 ölçüden sonra yankı kuyruğu (sn)
LENGTH = int(round(BARS * 4 * SPB + TAIL * SR))
TARGET_MAIN_RMS = -22.8          # drag_theme.wav'ın RMS'i (dBFS): nakarat bununla eşlenir
CEILING = -1.0
rng = np.random.default_rng(1555)


def at(beat: float) -> int:
    return int(round(beat * SPB))


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def beats_to_s(beats: float) -> float:
    return beats * 60.0 / BPM


# --- Beste ----------------------------------------------------------------------------------------

# Nakarat akorları (başlangıç vuruşu, süre, akor) ve pad sesleri; bas kökü (8'lik oktav zıplaması: vuruşta kök,
# arada oktav). 9–10. ölçüde akorlar yarım ölçü: ezgi iki ölçüde çözülür.
CHORDS = [(16, 4, "Bb"), (20, 4, "C"), (24, 4, "Am"), (28, 4, "Dm"), (32, 2, "Bb"), (34, 2, "C"), (36, 2, "Gm"),
          (38, 2, "A")]
VOICING = {"Bb": ["F3", "Bb3", "D4", "F4"], "C": ["G3", "C4", "E4", "G4"], "Am": ["A3", "C4", "E4", "A4"],
           "Dm": ["A3", "D4", "F4", "A4"], "Gm": ["G3", "Bb3", "D4", "G4"], "A": ["A3", "C#4", "E4", "A4"]}
BASS_ROOT = {"Bb": "Bb1", "C": "C2", "Am": "A1", "Dm": "D2", "Gm": "G1", "A": "A1"}

# ANA EZGİ (ölçü → [(vuruş, süre, nota)]), yazılı oktav = çan / koto oktavı; süpersaw lead bir oktav aşağıda çalar.
MELODY = {
    5: [(0, .25, "A5"), (.25, .25, "Bb5"), (.5, .5, "D6"), (1, .5, "C6"), (1.5, .5, "Bb5"), (2, 1, "C6"),
        (3, .5, "A5"), (3.5, .5, "F5")],
    6: [(0, .25, "G5"), (.25, .25, "A5"), (.5, .5, "C6"), (1, .5, "Bb5"), (1.5, .5, "A5"), (2, 1, "G5"),
        (3, .5, "E5"), (3.5, .5, "G5")],
    7: [(0, .5, "A5"), (.5, .5, "E5"), (1, .5, "A5"), (1.5, .5, "C6"), (2, .5, "E6"), (2.5, .5, "D6"),
        (3, .5, "C6"), (3.5, .5, "A5")],
    8: [(0, 1.5, "D6"), (1.5, .5, "E6"), (2, .5, "F6"), (2.5, .5, "E6"), (3, .25, "D6"), (3.25, .25, "E6"),
        (3.5, .25, "D6"), (3.75, .25, "C6")],
    9: [(0, .25, "A5"), (.25, .25, "Bb5"), (.5, .5, "D6"), (1, 1, "F6"),                       # Bb
        (2, .25, "C6"), (2.25, .25, "D6"), (2.5, .5, "E6"), (3, 1, "G6")],                      # C
    10: [(0, .5, "Bb5"), (.5, .5, "D6"), (1, .5, "G6"), (1.5, .5, "F6"),                       # Gm
         (2, .5, "E6"), (2.5, .25, "G6"), (2.75, .25, "F6"), (3, .25, "E6"), (3.25, .25, "D6"),  # A: harmonik
         (3.5, .25, "E6"), (3.75, .25, "C#6")],                                                  # minör iniş → D
    11: [(0, 3.0, "D6")],
}

# KOTO GİRİŞİ (D hirajoshi: D E F A Bb), vuruş mutlak
KOTO_INTRO = [(0, .75, "D5"), (.75, .25, "E5"), (1, .5, "F5"), (1.5, .5, "E5"), (2, .5, "D5"), (2.5, .5, "A4"),
              (3, .5, "Bb4"), (3.5, .5, "A4"),
              (4, .5, "F4"), (4.5, .5, "E4"), (5, .75, "D4"), (5.75, .25, "E4"), (6, .5, "F4"), (6.5, .5, "A4"),
              (7, .25, "Bb4"), (7.25, .25, "A4"), (7.5, .5, "D5")]
# Çıkışta koto inişi (son akordan sonra, sakin)
KOTO_OUTRO = [(42, .25, "A5"), (42.25, .25, "F5"), (42.5, .25, "E5"), (42.75, .25, "D5"), (43, .25, "Bb4"),
              (43.25, .25, "A4"), (43.5, .5, "F4"), (44, 2.0, "D4")]
# Taiko: (vuruş, nota, şiddet)
TAIKO = [(0, "D2", 118), (1.5, "A2", 84), (2, "D2", 96), (3, "D2", 110), (4, "D2", 116), (5.5, "A2", 86),
         (6, "D2", 98), (6.5, "A2", 90), (7, "D2", 104), (7.25, "A2", 92), (7.5, "D2", 108), (7.75, "A2", 112),
         (8, "D2", 124), (44, "D2", 100)]
# Yükseliş arpeji (16'lık; vuruş → 4 nota)
ARP = {8: ["D4", "F4", "A4", "D5"], 9: ["F4", "A4", "D5", "F5"], 10: ["A4", "D5", "F5", "A5"],
       11: ["D5", "F5", "A5", "D6"], 12: ["Bb3", "D4", "F4", "Bb4"], 13: ["D4", "F4", "Bb4", "D5"],
       14: ["A4", "C#5", "E5", "A5"]}


def melody_notes() -> list[tuple[float, float, int]]:
    out = []
    for bar, notes in MELODY.items():
        base = (bar - 1) * 4
        for beat, dur, name in notes:
            out.append((base + beat, dur, n(name)))
    return out


# --- FluidSynth bölümleri -------------------------------------------------------------------------

def gm_stem(program: int, notes: list[tuple[float, float, int, int]], gain: float = 0.6) -> np.ndarray:
    song = Song(BPM, 0.5, {0: {"program": program, "volume": 110, "pan": 64, "reverb": 0}})
    for beat, dur, pitch, vel in notes:
        song.note(0, beat, dur, pitch, vel)
    return S.fit(S.fluidsynth(song.midi(), SOUNDFONT, gain), LENGTH)


def onset_offset(stem: np.ndarray, beat: float) -> int:
    """FluidSynth gecikmesi: notanın beklenen başlangıcından ilk anlamlı örneğe kadar (örnek)."""
    start = at(beat)
    seg = np.max(np.abs(stem[:, start - 2000:start + 4000]), axis=0)
    thresh = seg.max() * 0.08
    return int(np.argmax(seg > thresh)) - 2000


# --- Sentez bölümleri -----------------------------------------------------------------------------

def supersaw_pad(notes: list[str], beats: float, cutoff, release: float = 0.35, cents: float = 18.0,
                 attack: float = 0.04) -> np.ndarray:
    hold = at(beats)
    total = hold + max(int(release * SR), 1)
    sig = np.zeros((2, total))
    for name in notes:
        sig += S.supersaw(hz(n(name)), total, rng, cents)
    sig /= np.sqrt(len(notes))
    cut = cutoff(total) if callable(cutoff) else cutoff
    sig = S.svf2(sig, cut, q=0.85)
    sig = S.fft_filter(sig, lo=170.0)
    return sig * S.env_adsr(hold, attack, 0.4, 0.85, release)[:total]


def lead_part(notes: list[tuple[float, float, int]]) -> np.ndarray:
    """Süpersaw lead (tek ses): nota başına süzgeç zarfı tek bir kesim dizisine yazılır, tek SVF geçişi."""
    buf = np.zeros((2, LENGTH))
    cutoff = np.full(LENGTH, 1800.0)
    for beat, dur, pitch in notes:
        start = at(beat)
        hold = max(at(beat + dur) - start - int(0.012 * SR), int(0.03 * SR))
        total = hold + int(0.09 * SR)
        t = np.arange(total) / SR
        f = np.full(total, hz(pitch))
        if dur >= 1.0:   # uzun notada gecikmeli vibrato
            ramp = np.clip((t - 0.18) / 0.25, 0.0, 1.0)
            f *= 2.0 ** (14.0 * ramp * np.sin(2 * np.pi * 5.6 * t) / 1200.0)
        sig = S.supersaw(f, total, rng, cents=13.0, width=0.55)
        sig += 0.35 * S.pan(S.saw(f * 0.5, total, rng.random()), 0.0) * 0.5    # alt oktav gövde
        sig *= S.env_adsr(hold, 0.003, 0.22, 0.82, 0.09)[:total]
        S.place(buf, start, sig)
        end = min(LENGTH, start + total)
        cut = 3100.0 + 5200.0 * np.exp(-t / 0.11)
        cutoff[start:end] = np.maximum(cutoff[start:end], cut[:end - start])
    return S.svf2(buf, cutoff, q=0.9)


def bell_part(notes: list[tuple[float, float, int]]) -> np.ndarray:
    """FM çan (lead'in bir oktav üstü, 5–8. ölçü)."""
    buf = np.zeros((2, LENGTH))
    for beat, dur, pitch in notes:
        f = hz(pitch)
        total = int(0.9 * SR)
        t = np.arange(total) / SR
        index = 1.6 * np.exp(-t / 0.12) + 0.25
        mod = np.sin(2 * np.pi * 3.0 * f * t)
        sig = np.sin(2 * np.pi * f * t + index * mod) * np.exp(-t / 0.42) * np.minimum(1.0, t / 0.002)
        S.place(buf, at(beat), S.pan(sig, 0.25))
    return buf


def bass_part(events: list[tuple[float, float, int, float]]) -> np.ndarray:
    """Testere + ince detune ikizi + alt sinüs; nota başına süzgeç zarfı (Eurobeat oktav basının 'pıt' sesi)."""
    buf = np.zeros(LENGTH)
    for beat, dur, pitch, vel in events:
        start = at(beat)
        hold = int(dur * SPB)
        total = hold + int(0.045 * SR)
        t = np.arange(total) / SR
        f = hz(pitch)
        root = hz(pitch - 12) if pitch >= 40 else f
        osc = 0.75 * S.saw(f, total, rng.random()) + 0.45 * S.saw(f * 1.006, total, rng.random())
        cut = 560.0 + 2800.0 * vel * np.exp(-t / 0.06)
        sig = S.svf(osc, cut, q=1.1) + 0.4 * S.sine(root, total)
        sig = np.tanh(1.4 * sig) * S.env_adsr(hold, 0.002, 0.12, 0.78, 0.045)[:total] * vel
        end = min(LENGTH, start + total)
        buf[start:end] += sig[:end - start]
    return buf


def stab_part() -> np.ndarray:
    """Arka vuruşlarda kısa süpersaw akor vuruşları (Eurobeat 'pa')."""
    buf = np.zeros((2, LENGTH))
    for base, beats, chord in CHORDS:
        for k, off in enumerate(o for o in (0.5, 1.5, 2.5, 3.5) if o < beats):
            hold = int(0.2 * SPB)
            total = hold + int(0.07 * SR)
            t = np.arange(total) / SR
            sig = np.zeros((2, total))
            for name in VOICING[chord]:
                sig += S.supersaw(hz(n(name) + 12), total, rng, cents=16.0)
            sig = S.svf2(sig, 1300.0 + 6000.0 * np.exp(-t / 0.05), q=0.8) / 2.0
            accent = 1.0 if k % 2 == 1 else 0.82
            S.place(buf, at(base + off), sig * S.env_adsr(hold, 0.002, 0.08, 0.6, 0.07)[:total] * accent)
    return S.fft_filter(buf, lo=220.0)


def arp_part() -> np.ndarray:
    buf = np.zeros((2, LENGTH))
    for beat, names in ARP.items():
        for k, name in enumerate(names):
            b = beat + k * 0.25
            hold = int(0.2 * SPB)
            total = hold + int(0.05 * SR)
            gain = 0.55 + 0.45 * (b - 8.0) / 7.0
            sig = S.supersaw(hz(n(name)), total, rng, cents=11.0) * S.env_adsr(hold, 0.002, 0.06, 0.55, 0.05)[:total]
            S.place(buf, at(b), sig * gain)
    s, e = at(8), at(BREAK_BEAT) + int(0.06 * SR)
    seg = buf[:, s:e]
    cut = 450.0 * (16.0 ** np.linspace(0.0, 1.0, seg.shape[1]))     # 450 → 7200 Hz
    buf[:, s:e] = S.svf2(seg, cut, q=1.4)
    buf[:, :s] = 0.0
    return buf


def intro_pad() -> np.ndarray:
    buf = np.zeros((2, LENGTH))
    beats = BREAK_BEAT - 0.02
    sig = supersaw_pad(["D3", "A3", "D4", "F4"], beats, lambda m: 220.0 * (12.0 ** (np.linspace(0, 1, m) ** 1.6)),
                       release=0.03, cents=22.0, attack=0.6)
    swell = np.linspace(0.0, 1.0, sig.shape[1]) ** 1.3
    S.place(buf, 0, sig * (0.25 + 0.75 * swell))
    return buf


def main_pad() -> np.ndarray:
    buf = np.zeros((2, LENGTH))
    for start, beats, chord in CHORDS:
        S.place(buf, at(start), supersaw_pad(VOICING[chord], beats, 2600.0, release=0.25))
    final = supersaw_pad(["D3", "A3", "D4", "F4", "A4"], 4.0, lambda m: 3200.0 * np.exp(-np.arange(m) / (2.2 * SR)) + 700.0,
                         release=1.6, attack=0.005)
    S.place(buf, at(END_BEAT), final)
    return buf


# --- Davul ----------------------------------------------------------------------------------------

def kick() -> np.ndarray:
    total = int(0.42 * SR)
    t = np.arange(total) / SR
    f = 52.0 + 150.0 * np.exp(-t / 0.024) + 260.0 * np.exp(-t / 0.0028)
    body = S.sine(f, total) * np.exp(-t / 0.17) * np.minimum(1.0, t / 0.0008)
    body = np.tanh(2.0 * body) / np.tanh(2.0)
    click = S.fft_filter(rng.standard_normal(total), lo=2500.0, hi=9000.0) * np.exp(-t / 0.0035) * 0.4
    return body + click


def clap() -> np.ndarray:
    total = int(0.32 * SR)
    t = np.arange(total) / SR
    env = np.zeros(total)
    for k, start in enumerate((0.0, 0.0085, 0.017)):
        tt = t - start
        env += np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / 0.0045), 0.0) * (0.75 + 0.1 * k)
    tail = t - 0.024
    env += np.where(tail >= 0, np.exp(-np.maximum(tail, 0) / 0.085), 0.0) * 0.8
    noise = S.bandpass_fft(rng.standard_normal(total), 1250.0, 0.9)
    noise = S.fft_filter(noise, lo=500.0)
    body = (S.sine(186.0, total) * 0.5 + S.sine(328.0, total) * 0.25) * np.exp(-t / 0.06)
    snare = S.fft_filter(rng.standard_normal(total), lo=3000.0) * np.exp(-t / 0.11) * 0.35
    return noise * env + body + snare


def snare(level: float) -> np.ndarray:
    total = int(0.2 * SR)
    t = np.arange(total) / SR
    noise = S.fft_filter(rng.standard_normal(total), lo=900.0, hi=11000.0) * np.exp(-t / 0.07)
    body = S.sine(200.0 * (1 + 0.3 * np.exp(-t / 0.01)), total) * np.exp(-t / 0.05) * 0.7
    return (noise + body) * level


METAL = np.array([205.3, 304.4, 369.6, 522.7, 540.0, 800.0]) * 1.65


def hat(open_: bool) -> np.ndarray:
    decay = 0.13 if open_ else 0.028
    total = int((0.45 if open_ else 0.12) * SR)
    t = np.arange(total) / SR
    metal = sum(np.sign(np.sin(2 * np.pi * f * t + rng.random() * 6.28)) for f in METAL) / len(METAL)
    sig = 0.55 * metal + 0.8 * rng.standard_normal(total)
    sig = S.fft_filter(sig, lo=7200.0 if open_ else 8200.0, order=3)
    shape = np.exp(-t / decay) * np.minimum(1.0, t / 0.0007)
    return sig * shape


def crash(seconds: float = 2.4) -> np.ndarray:
    total = int(seconds * SR)
    t = np.arange(total) / SR
    out = np.zeros((2, total))
    for ch in range(2):
        metal = sum(np.sin(2 * np.pi * f * (1.0 + 0.002 * ch) * t + rng.random() * 6.28)
                    for f in METAL * np.array([2.1, 2.4, 2.2, 2.6, 2.9, 3.3]))
        sig = 0.25 * metal / 6.0 + rng.standard_normal(total)
        sig = S.fft_filter(sig, lo=3800.0, hi=11000.0)
        out[ch] = sig * (np.exp(-t / 0.75) * 0.8 + 0.2 * np.exp(-t / 0.08)) * np.minimum(1.0, t / 0.001)
    return out


def sub_boom(seconds: float = 1.1) -> np.ndarray:
    total = int(seconds * SR)
    t = np.arange(total) / SR
    f = 34.0 + 30.0 * np.exp(-t / 0.18)
    return np.tanh(1.5 * S.sine(f, total) * np.exp(-t / 0.45) * np.minimum(1.0, t / 0.002))


def taiko_boom() -> np.ndarray:
    total = int(0.6 * SR)
    t = np.arange(total) / SR
    f = 58.0 + 45.0 * np.exp(-t / 0.04)
    thump = S.fft_filter(rng.standard_normal(total), hi=700.0) * np.exp(-t / 0.03) * 0.5
    return (S.sine(f, total) * np.exp(-t / 0.28) + thump) * np.minimum(1.0, t / 0.002)


def riser() -> np.ndarray:
    """Beyaz gürültü yükselişi: 8. vuruştan kırılma anına (15) süzgeci açılır, sesi büyür; kırılmada kesilir."""
    buf = np.zeros((2, LENGTH))
    s, e = at(8), at(BREAK_BEAT)
    m = e - s
    x = np.linspace(0.0, 1.0, m)
    cut = 350.0 * (30.0 ** (x ** 1.4))
    for ch in range(2):
        sig = S.svf(rng.standard_normal(m), cut, q=2.2, mode="bp")
        buf[ch, s:e] = sig * (x ** 2.2) * np.minimum(1.0, (e - s - np.arange(m)) / (0.012 * SR))
    return buf


def drums() -> dict[str, np.ndarray]:
    k, cl, oh, ch = kick(), clap(), hat(True), hat(False)
    parts = {name: np.zeros((2, LENGTH)) for name in ("kick", "clap", "ohat", "chat", "roll", "crash", "boom", "rev")}
    for beat in range(DROP_BEAT, END_BEAT + 1):
        S.place(parts["kick"], at(beat), k)
    for beat in range(DROP_BEAT, END_BEAT):
        if beat % 2 == 1 and beat not in (END_BEAT - 1,):
            S.place(parts["clap"], at(beat), S.pan(cl, 0.0) * 0.72)
        S.place(parts["ohat"], at(beat + 0.5), S.pan(oh, 0.18) * 0.72)
        for off in (0.25, 0.75):
            S.place(parts["chat"], at(beat + off), S.pan(ch, -0.22) * 0.72 * (0.85 if off == 0.25 else 0.7))
    # giriş yükselişi: 16'lık kapalı hi-hat
    for k16 in range(8 * 4, BREAK_BEAT * 4):
        b = k16 / 4
        S.place(parts["chat"], at(b), S.pan(ch, -0.22) * 0.72 * (0.5 + 0.35 * (b - 8) / 7) * (1.0 if k16 % 2 == 0 else 0.7))
    # hızlanan trampet: 8'lik → 16'lık → 32'lik, kreşendo; 15. vuruşta kesilir
    roll = [(8 + i * 0.5, 0.3 + 0.25 * i / 7) for i in range(8)]
    roll += [(12 + i * 0.25, 0.55 + 0.25 * i / 7) for i in range(8)]
    roll += [(14 + i * 0.125, 0.8 + 0.2 * i / 7) for i in range(8)]
    # nakarat içi dolgular: 8. ölçü sonu (31) ve 10. ölçü sonu (38–40)
    roll += [(31 + i * 0.25, 0.5 + 0.15 * i) for i in range(4)]
    roll += [(END_BEAT - 2 + i * 0.25, 0.45 + 0.07 * i) for i in range(8)]
    for b, level in roll:
        S.place(parts["roll"], at(b), S.pan(snare(level), 0.05))
    for beat in (DROP_BEAT, 32, END_BEAT):
        S.place(parts["crash"], at(beat), crash() * (1.0 if beat != 32 else 0.8))
    for beat in (DROP_BEAT, END_BEAT):
        S.place(parts["boom"], at(beat), sub_boom())
    # ters zil: kırılma vuruşu boyunca şişer, tam DROP'ta biter
    length = at(DROP_BEAT) - at(BREAK_BEAT)
    c = crash(1.2)[:, :length][:, ::-1]
    c *= (np.linspace(0.0, 1.0, length) ** 2.0)
    S.place(parts["rev"], at(BREAK_BEAT), c)
    return parts


# --- Karışım --------------------------------------------------------------------------------------

def sidechain(depth: float, release: float = 0.12) -> np.ndarray:
    g = np.ones(LENGTH)
    span = int(SPB)
    t = np.arange(span) / SR
    shape = 1.0 - depth * np.exp(-t / release) * np.minimum(1.0, t / 0.004 + 0.35)
    for beat in range(DROP_BEAT, END_BEAT + 1):
        s = at(beat)
        e = min(LENGTH, s + span)
        g[s:e] = np.minimum(g[s:e], shape[:e - s])
    return g


def window(beat_a: float, beat_b: float) -> slice:
    return slice(at(beat_a), at(beat_b))


def level(x: np.ndarray, target_db: float, win: slice) -> np.ndarray:
    current = S.rms_db(x[:, win])
    return x * 10.0 ** ((target_db - current) / 20.0)


def ping_pong(x: np.ndarray, beats: float = 0.75, feedback: float = 0.38, repeats: int = 4) -> np.ndarray:
    mono = np.mean(x, axis=0)
    d = at(beats)
    out = np.zeros_like(x)
    for k in range(1, repeats + 1):
        g = feedback ** (k - 1)
        side = 0 if k % 2 == 1 else 1
        out[side, k * d:] += mono[:LENGTH - k * d] * g
    return S.fft_filter(out, lo=400.0, hi=4200.0)


def tilt(x: np.ndarray) -> np.ndarray:
    """Ana bus EQ'su: 28 Hz altı kesilir, 2,8 kHz +2 dB varlık, 9 kHz üstü yumuşak raf −3 dB (telefonda tiz batmasın)."""
    size = x.shape[1] * 2
    f = np.fft.rfftfreq(size, 1.0 / SR)
    h = 1.0 / np.sqrt(1.0 + (28.0 / np.maximum(f, 1e-3)) ** 4)
    h *= 1.0 - (1.0 - 10 ** (-3.0 / 20)) / (1.0 + (9000.0 / np.maximum(f, 1e-3)) ** 2)
    presence = 1.0 / (1.0 + (0.8 * (f / 2800.0 - 2800.0 / np.maximum(f, 1e-3))) ** 2)
    h *= 1.0 + (10 ** (2.0 / 20) - 1.0) * presence     # +2 dB 2,8 kHz: lead telefon hoparlöründe öne çıksın
    return np.fft.irfft(np.fft.rfft(x, n=size, axis=-1) * h, n=size, axis=-1)[:, :x.shape[1]]


def build() -> np.ndarray:
    clock = time.time()
    melody = melody_notes()
    lead_notes = [(b, d, p - 12) for b, d, p in melody]

    # FluidSynth: koto, taiko, orkestra vuruşu, brass
    koto_notes = [(b, d, n(m), 100) for b, d, m in KOTO_INTRO]
    koto_notes += [(b, d, n(m) - 12, 62) for b, d, m in KOTO_INTRO[9:]]          # 2. ölçüde alt oktav dolgunluk
    koto_notes += [(b, d, p, 92) for b, d, p in melody if b >= 32 and b < END_BEAT]  # 9–10: ezgi oktav üstte (yazılı)
    koto_notes += [(b, d, n(m), 88) for b, d, m in KOTO_OUTRO]
    koto = gm_stem(107, koto_notes)
    taiko = gm_stem(116, [(b, 0.5, n(m), v) for b, m, v in TAIKO])
    orch = gm_stem(55, [(DROP_BEAT, 1.0, n("Bb3"), 120), (DROP_BEAT, 1.0, n("F4"), 110),
                        (32, 1.0, n("Bb3"), 90), (END_BEAT, 2.0, n("D4"), 124), (END_BEAT, 2.0, n("A4"), 112)])
    brass = gm_stem(62, [(b, d, p, 92) for b, d, p in lead_notes])
    lag = onset_offset(orch, DROP_BEAT)
    print(f"FluidSynth gecikmesi: {lag} örnek ({lag / SR * 1000:.2f} ms)")
    if lag != 0:
        for stem in (koto, taiko, orch, brass):
            stem[:] = np.roll(stem, -lag, axis=1)
            if lag > 0:
                stem[:, -lag:] = 0.0
    print(f"  FluidSynth bitti {time.time() - clock:.1f} sn")

    # Synth bölümleri
    bass_events = []
    for b8 in range(8 * 2, BREAK_BEAT * 2):           # giriş: D pedalı, süzgeç açılır
        b = b8 / 2
        pitch = n("D2") + (12 if b8 % 2 else 0)
        bass_events.append((b, 0.42, pitch, 0.45 + 0.45 * (b - 8) / 7))
    for start, beats, chord in CHORDS:
        root = n(BASS_ROOT[chord])
        for k in range(int(beats * 2)):
            b = start + k * 0.5
            bass_events.append((b, 0.42, root + (12 if k % 2 else 0), 1.0 if k % 2 else 0.92))
    bass_events.append((END_BEAT, 2.5, n("D2"), 1.0))
    bass = S.pan(bass_part(bass_events), 0.0)
    print(f"  bas bitti {time.time() - clock:.1f} sn")
    lead = lead_part(lead_notes)
    print(f"  lead bitti {time.time() - clock:.1f} sn")
    bell = bell_part([(b, d, p) for b, d, p in melody if b < 32])
    stabs = stab_part()
    arp = arp_part()
    pad_in = intro_pad()
    pad = main_pad()
    rise = riser()
    boom = np.zeros((2, LENGTH))
    for b, m, v in TAIKO:
        S.place(boom, at(b), taiko_boom() * (v / 127.0) ** 2)
    print(f"  synth bitti {time.time() - clock:.1f} sn")
    dr = drums()

    MAIN = window(DROP_BEAT, END_BEAT)
    INTRO = window(0, 8)
    BUILD = window(8, BREAK_BEAT)
    st: dict[str, np.ndarray] = {}
    st["kick"] = level(dr["kick"], -18.0, MAIN)
    st["clap"] = level(dr["clap"], -24.0, MAIN)
    st["ohat"] = level(dr["ohat"], -30.0, MAIN)
    st["chat"] = level(dr["chat"], -35.5, MAIN)
    st["roll"] = level(dr["roll"], -24.0, window(12, BREAK_BEAT))
    st["crash"] = dr["crash"] * (10 ** (-13.5 / 20) / max(np.max(np.abs(dr["crash"])), 1e-9))
    st["boom"] = dr["boom"] * (10 ** (-9.0 / 20) / max(np.max(np.abs(dr["boom"])), 1e-9))
    st["rev"] = dr["rev"] * (10 ** (-14.0 / 20) / max(np.max(np.abs(dr["rev"])), 1e-9))
    st["bass"] = level(bass, -19.5, MAIN)
    st["lead"] = level(lead, -17.5, MAIN)
    st["brass"] = level(S.pan(np.mean(brass, axis=0), 0.12), -27.0, MAIN)
    st["bell"] = level(bell, -31.0, window(DROP_BEAT, 32))
    st["stabs"] = level(stabs, -26.0, MAIN)
    st["pad"] = level(pad, -25.0, MAIN)
    st["pad_in"] = level(pad_in, -27.0, window(4, BREAK_BEAT))
    st["arp"] = level(arp, -25.0, BUILD)
    st["rise"] = level(rise, -27.0, window(12, BREAK_BEAT))
    # koto: giriş ve nakarat ayrı düzey (aynı basım, zamana göre kazanç)
    k_mono = S.pan(np.mean(koto, axis=0), -0.28)
    k_gain = np.where(np.arange(LENGTH) < at(DROP_BEAT), 1.0, 0.0)
    k_in = level(k_mono * k_gain, -20.0, INTRO)
    k_main = level(k_mono * (1.0 - k_gain), -27.0, window(32, END_BEAT))
    st["koto"] = k_in + k_main
    st["taiko"] = level(S.pan(np.mean(taiko, axis=0), 0.0), -21.0, INTRO)
    st["taiko_boom"] = level(boom, -25.0, INTRO)
    st["orch"] = S.pan(np.mean(orch, axis=0), 0.0)
    st["orch"] *= 10 ** (-7.0 / 20) / max(np.max(np.abs(st["orch"])), 1e-9)

    # sidechain
    for name, depth in (("pad", 0.6), ("stabs", 0.3), ("bass", 0.35), ("koto", 0.2), ("lead", 0.12), ("brass", 0.15)):
        st[name] = st[name] * sidechain(depth)

    # yankı (tek FFT odası) + lead gecikmesi
    sends = {"lead": 0.22, "brass": 0.25, "bell": 0.5, "pad": 0.3, "pad_in": 0.45, "stabs": 0.22, "koto": 0.4,
             "taiko": 0.35, "taiko_boom": 0.15, "clap": 0.18, "roll": 0.2, "orch": 0.35, "arp": 0.3, "ohat": 0.05,
             "rise": 0.2}
    send = sum(np.mean(st[k], axis=0) * v for k, v in sends.items())
    ir = S.make_ir(rng)
    wet = S.convolve(send, ir)
    wet = S.fft_filter(wet, lo=180.0, hi=9000.0)
    wet *= sidechain(0.4, 0.18)
    # kırılmada yankı da çekilir: boşluk gerçekten boş olsun
    duck = np.ones(LENGTH)
    s, e = at(BREAK_BEAT), at(DROP_BEAT)
    fade = int(0.035 * SR)
    duck[s:s + fade] = np.linspace(1.0, 0.12, fade)
    duck[s + fade:e] = 0.12
    wet *= duck
    st["reverb"] = level(wet, -24.5, MAIN)
    st["delay"] = level(ping_pong(st["lead"]), -30.0, MAIN)
    print(f"  karışım hazır {time.time() - clock:.1f} sn")

    mix = sum(st.values())
    for name in ("kick", "bass", "lead", "pad", "koto", "reverb"):
        print(f"    {name:8s} nakarat RMS {S.rms_db(st[name][:, MAIN]):6.1f} dB")
    mix = tilt(mix)
    mix = S.compress(mix, S.rms_db(mix[:, MAIN]) + 4.0, 2.0)
    # nakarat RMS'i hedefe, sonra sınırlayıcı; sınırlayıcının kaybını bir kez telafi et
    for _ in range(2):
        mix *= 10 ** ((TARGET_MAIN_RMS - S.rms_db(S.limit(mix, CEILING)[:, MAIN])) / 20.0)
    out = S.limit(mix, CEILING)
    tail = int(0.4 * SR)
    out[:, -tail:] *= np.linspace(1.0, 0.0, tail) ** 2
    print(f"  bitti {time.time() - clock:.1f} sn")
    return out


def main() -> None:
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/audio/music/drift_theme.wav")
    x = build()
    S.write_wav(out_path, x)
    main_sl = slice(at(DROP_BEAT), at(END_BEAT))
    print(f"{out_path}: {x.shape[1] / SR:.3f} sn, DROP {at(DROP_BEAT) / SR:.6f} sn (örnek {at(DROP_BEAT)}), "
          f"RMS tüm {S.rms_db(x):.2f} / nakarat {S.rms_db(x[:, main_sl]):.2f} dBFS, tepe {S.peak_db(x):.2f} dBFS")


if __name__ == "__main__":
    main()
