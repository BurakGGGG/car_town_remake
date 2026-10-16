"""AUTO YARD teaser ses bandı (22 sn, 48 kHz stereo) — tamamen sentez, dış örnek yok.

numpy gerekir; sistem Python'unda yok, Blender'ınkiyle çalıştırılır:
    /snap/blender/current/5.2/python/bin/python3.13 qa/teaser/soundtrack.py <çıktı.wav>

Zaman çizelgesi görüntüyle aynı sabitleri kullanır (qa/teaser/seg_*.gd). TEK MÜZİK: 0–22 sn kesintisiz,
150 BPM, Am–F–C–G; yalnızca yoğunluk artar (giriş pad → 3,0 ritim → 6,2 trampet/arpej → 12,6 zirve →
17–20 vitrin), 20,0'da son akorla biter. Müzik konuşmaya yer bırakır (0,9–3,5 kHz oyuk, düşük seviye).
Efektler: 0–3 marş/rölanti/far tıkları, 3–7 tamir sesleri, 12–17 ağaç bipleri + BOĞUK motorlar (ağır
çekimde yavaşlayıp söner), 17–20 garaj geçişleri, 20 logo darbesi. Çıktı: ana mix + _muzik / _efekt kanalları.
"""
import os
import sys
import wave

import numpy as np

SR = 48000
# Kurgu zamanı ↔ çekim zamanı (qa/teaser/teaser.gd PIECES ile AYNI): [çekim_baş, çekim_son, kurgu_baş, kurgu_son].
# Efekt saniyeleri çekim zamanında yazılı, place() kurgu zamanına çevirir; müzik doğrudan kurgu zamanında yazılır.
PIECES = [(0.0, 3.0, 0.0, 5.5), (3.0, 7.0, 5.5, 9.5), (7.0, 12.0, 9.5, 14.5), (12.0, 17.0, 14.5, 19.5),
          (17.0, 20.0, 19.5, 23.5), (20.0, 25.4, 23.5, 28.9)]
DUR = 28.9
N = int(SR * DUR)
# Seslendirme satırlarının kurgu saniyeleri (work/ses_hazir/01..06.wav)
VOICE_AT = [0.1, 5.55, 10.1, 14.6, 19.55, 24.1]


def M(t: float) -> float:
    """Çekim saniyesi → kurgu saniyesi."""
    for a, b, c, d in PIECES:
        if t <= b + 1e-9:
            return c + (d - c) * (t - a) / (b - a)
    return t
rng = np.random.default_rng(7)

B2 = 0.4                   # tek müziğin vuruşu (150 BPM)
STORY_CUTS = [3.0, 3.533, 4.067, 4.6, 5.133, 6.2]
GARAGE_CUTS = [7.0, 8.2, 9.0, 9.4, 9.8, 10.2, 10.6]
DRAG_CUTS = [12.0, 12.45, 12.9, 13.7, 14.9, 16.1]
TREE = [12.15, 12.4, 12.65]
GO = 12.9
SHIFTS = [13.3, 14.1, 15.3]
SLOW_FROM, SLOW_TO, FREEZE = 16.25, 16.45, 16.55
HIT = 17.0

music = np.zeros((N, 2))
sfx = np.zeros((N, 2))
engine_bus = np.zeros((N, 2))


# --- Temel araçlar -------------------------------------------------------------------------------

def secs(n: int) -> np.ndarray:
    return np.arange(n) / SR


def place(bus: np.ndarray, x: np.ndarray, at: float, gain: float = 1.0, pan: float = 0.0, edit: bool = False) -> None:
    """Mono ya da stereo sinyali yerleştirir (pan -1 sol … 1 sağ, eş güç). `at` çekim saniyesi; edit=True ise
    zaten kurgu saniyesi."""
    i = int(round((at if edit else M(at)) * SR))
    if i >= N or len(x) == 0:
        return
    if i < 0:
        x = x[-i:]
        i = 0
    x = x[: N - i]
    if x.ndim == 1:
        a = (pan + 1.0) * np.pi / 4.0
        x = np.stack([x * np.cos(a), x * np.sin(a)], axis=1)
    bus[i:i + len(x)] += x * gain


def spectral(x: np.ndarray, shape) -> np.ndarray:
    """Durağan FFT süzgeci: shape(frekans_dizisi) → kazanç."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(n + 1)))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / SR)
    return np.fft.irfft(spec * shape(f), size)[:n]


def lowpass(x: np.ndarray, fc: float, order: float = 4.0) -> np.ndarray:
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def highpass(x: np.ndarray, fc: float, order: float = 4.0) -> np.ndarray:
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1.0)) ** (2 * order)))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return highpass(lowpass(x, hi), lo)


def sweep(x: np.ndarray, lo_fn, hi_fn, frame: int = 2048, hop: int = 512) -> np.ndarray:
    """Zamanla değişen bant geçiren (STFT, örtüşmeli topla): lo_fn/hi_fn(t_saniye) → Hz."""
    n = len(x)
    pad = np.concatenate([np.zeros(frame), x, np.zeros(frame)])
    out = np.zeros_like(pad)
    norm = np.zeros_like(pad)
    win = np.hanning(frame)
    f = np.fft.rfftfreq(frame, 1.0 / SR)
    for s in range(0, len(pad) - frame, hop):
        t = (s + frame / 2 - frame) / SR
        lo, hi = lo_fn(t), hi_fn(t)
        g = 1.0 / np.sqrt(1.0 + (f / hi) ** 8) / np.sqrt(1.0 + (lo / np.maximum(f, 1.0)) ** 8)
        seg = np.fft.irfft(np.fft.rfft(pad[s:s + frame] * win) * g, frame)
        out[s:s + frame] += seg * win
        norm[s:s + frame] += win * win
    out = out / np.maximum(norm, 1e-6)
    return out[frame:frame + n]


def noise(n: int) -> np.ndarray:
    return rng.standard_normal(n)


def exp_env(n: int, decay: float, attack: float = 0.002) -> np.ndarray:
    t = secs(n)
    return (1.0 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t * decay)


def reverb(x: np.ndarray, length: float = 1.8, decay: float = 3.0, mix: float = 0.3) -> np.ndarray:
    """Stereo yapay yankı: üstel sönen iki gürültü dürtüsüyle FFT evrişimi."""
    n = int(length * SR)
    t = secs(n)
    out = np.zeros((len(x) + n, 2))
    mono = x if x.ndim == 1 else x.mean(axis=1)
    for c in range(2):
        ir = noise(n) * np.exp(-t * decay)
        ir = lowpass(ir, 6000.0, 2.0)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(mono) + n)))
        wet = np.fft.irfft(np.fft.rfft(mono, size) * np.fft.rfft(ir, size), size)[: len(mono) + n]
        out[:, c] = wet * mix
    dry = x if x.ndim == 2 else np.stack([x, x], axis=1)
    out[: len(x)] += dry * (1.0 - mix * 0.5)
    return out


def saw(phase: np.ndarray, harmonics: int = 24) -> np.ndarray:
    out = np.zeros_like(phase)
    for k in range(1, harmonics + 1):
        out += np.sin(k * phase) / k
    return out * 0.6


def note_hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# --- Davul ve vuruş sesleri ----------------------------------------------------------------------

def kick(power: float = 1.0) -> np.ndarray:
    n = int(0.55 * SR)
    t = secs(n)
    f = 42.0 + 110.0 * np.exp(-t * 32.0)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (6.0 / power))
    click = highpass(noise(n), 2500.0) * np.exp(-t * 300.0) * 0.4
    return np.tanh((body + click) * 1.6 * power) * 0.9


def snare() -> np.ndarray:
    n = int(0.35 * SR)
    t = secs(n)
    tone = np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 30.0) * 0.6
    rattle = bandpass(noise(n), 1500.0, 9000.0) * np.exp(-t * 16.0)
    return np.tanh(tone + rattle * 0.9)


def clap() -> np.ndarray:
    n = int(0.3 * SR)
    t = secs(n)
    env = np.zeros(n)
    for d in (0.0, 0.011, 0.023):
        env += np.where(t >= d, np.exp(-(t - d) * 90.0), 0.0)
    env += np.where(t >= 0.03, np.exp(-(t - 0.03) * 14.0) * 0.5, 0.0)
    return bandpass(noise(n), 900.0, 6000.0) * env * 0.8


def hat(open_: bool = False) -> np.ndarray:
    n = int((0.25 if open_ else 0.06) * SR)
    return highpass(noise(n), 7500.0) * exp_env(n, 10.0 if open_ else 70.0, 0.0005) * 0.2


def crash() -> np.ndarray:
    n = int(2.2 * SR)
    x = highpass(noise(n), 4000.0, 2.0) * exp_env(n, 3.2, 0.001)
    return x * 0.28


def boom(length: float = 2.6) -> np.ndarray:
    """Sinematik darbe: alçak sinüs çöküşü + gümbürtü + metal tını."""
    n = int(length * SR)
    t = secs(n)
    f = 34.0 + 70.0 * np.exp(-t * 9.0)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)
    thump = lowpass(noise(n), 400.0) * np.exp(-t * 7.0) * 2.0
    metal = np.zeros(n)
    for ratio, dec in ((1.0, 2.5), (2.76, 3.5), (5.4, 5.0), (8.93, 7.0)):
        metal += np.sin(2 * np.pi * 110.0 * ratio * t + rng.uniform(0, 6)) * np.exp(-t * dec)
    return np.tanh((sub * 1.4 + thump * 0.5 + metal * 0.12) * 1.3)


def metal_hit(f0: float = 340.0, length: float = 0.9) -> np.ndarray:
    n = int(length * SR)
    t = secs(n)
    out = np.zeros(n)
    for ratio, dec, amp in ((1.0, 6.0, 1.0), (2.76, 9.0, 0.6), (5.4, 13.0, 0.4), (8.93, 18.0, 0.25), (13.3, 25.0, 0.15)):
        out += np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6)) * np.exp(-t * dec) * amp
    out += highpass(noise(n), 3000.0) * np.exp(-t * 80.0) * 0.5
    return out * 0.5


def whoosh(length: float = 0.5, lo: float = 300.0, hi: float = 4500.0) -> np.ndarray:
    n = int(length * SR)
    t = secs(n)
    bell = np.sin(np.pi * t / length) ** 2
    peak = lambda s: lo + (hi - lo) * np.sin(np.pi * np.clip(s / length, 0, 1))
    x = sweep(noise(n), lambda s: peak(s) * 0.5, lambda s: peak(s) * 1.6 + 200.0)
    return x * bell * 0.7


def riser(length: float, lo: float = 250.0, hi: float = 7000.0) -> np.ndarray:
    n = int(length * SR)
    t = secs(n)
    k = t / length
    x = sweep(noise(n), lambda s: lo + (hi - lo) * (s / length) ** 2 * 0.5,
              lambda s: lo * 2.0 + (hi - lo) * (s / length) ** 2)
    tone = np.sin(2 * np.pi * np.cumsum(180.0 + 900.0 * k ** 2) / SR) * 0.25
    return (x * 0.8 + tone) * k ** 2


def reverse_swell(length: float) -> np.ndarray:
    hitn = crash()[: int(length * SR)]
    tail = reverb(hitn, 1.2, 2.5, 0.6)[: len(hitn)].mean(axis=1)
    return tail[::-1] * 1.4


def beep(freq: float, length: float) -> np.ndarray:
    n = int(length * SR)
    t = secs(n)
    env = np.minimum(1.0, t / 0.004) * np.minimum(1.0, (length - t) / 0.02)
    return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)) * env * 0.4


def pop(f0: float = 700.0) -> np.ndarray:
    n = int(0.25 * SR)
    t = secs(n)
    f = f0 + f0 * 0.8 * (1.0 - np.exp(-t * 40.0))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18.0) * 0.6


def shimmer(length: float = 1.6) -> np.ndarray:
    n = int(length * SR)
    out = np.zeros(n)
    t = secs(n)
    for i, m in enumerate((88, 91, 95, 100, 103, 107)):
        d = i * 0.05
        e = np.where(t >= d, np.exp(-(t - d) * 4.0), 0.0)
        out += np.sin(2 * np.pi * note_hz(m) * t) * e * 0.18
    return out


# --- Motor sentezi ------------------------------------------------------------------------------

def engine(rpm: np.ndarray, cylinders: int, gain: np.ndarray, rough: float = 0.3, bright: float = 4500.0,
           hiss: float = 0.8) -> np.ndarray:
    """Ateşleme frekansı = rpm/60 × silindir/2; harmonikler + alt harmonik (krank gümbürtüsü) + gürültü."""
    fire = rpm / 60.0 * cylinders / 2.0
    phase = 2 * np.pi * np.cumsum(fire) / SR
    out = np.zeros(len(rpm))
    for k in range(1, 16):
        amp = 1.0 / k ** 0.75
        mask = np.clip((9000.0 - fire * k) / 2000.0, 0.0, 1.0)
        out += np.sin(k * phase + k * 1.7) * amp * mask
    out += np.sin(phase * 0.5) * 0.6                     # yarım düzen: gümbürtü
    jitter = lowpass(noise(len(rpm)), 60.0) * rough * 3.0
    out *= 1.0 + jitter
    hiss_noise = bandpass(noise(len(rpm)), 800.0, 5000.0) * (0.25 + 0.4 * np.clip(rpm / 9000.0, 0, 1))
    pulses = np.maximum(0.0, np.sin(phase)) ** 6
    out += hiss_noise * pulses * hiss
    out = lowpass(np.tanh(out * 0.9), bright, 2.0)
    return out * gain


def race_rpm(t: np.ndarray, offset: float) -> np.ndarray:
    """Kalkış öncesi gaz patlamaları + kalkıştan sonra vites vites devir (iki araç biraz farklı)."""
    rpm = np.full(len(t), 1100.0)
    for blip in (12.05, 12.4):
        k = np.clip((t - blip) / 0.12, 0, 1) - np.clip((t - blip - 0.18) / 0.25, 0, 1)
        rpm += 5200.0 * np.clip(k, 0, 1)
    hold = (t >= 12.55) & (t < GO)
    rpm[hold] = 6800.0 + 300.0 * np.sin(t[hold] * 40.0)
    gears = [GO] + [s + offset for s in SHIFTS] + [99.0]
    for g in range(len(gears) - 1):
        a, b = gears[g], gears[g + 1]
        m = (t >= a) & (t < b)
        x = t[m] - a
        top = 8600.0
        start = 5200.0 if g == 0 else 6100.0
        rpm[m] = top - (top - start) * np.exp(-x * (2.2 - g * 0.3))
    return rpm


# --- 0–3 sn: gizem ------------------------------------------------------------------------------

def act_story() -> None:
    n = int(M(3.05) * SR)
    t = secs(n)
    wind = sweep(noise(n), lambda s: 180.0 + 80.0 * np.sin(s * 1.3), lambda s: 600.0 + 250.0 * np.sin(s * 0.9))
    wind *= np.minimum(1.0, t / 0.8) * 0.35
    drone = (np.sin(2 * np.pi * 55.0 * t) + 0.6 * np.sin(2 * np.pi * 58.3 * t) + 0.3 * np.sin(2 * np.pi * 110.4 * t))
    drone = lowpass(drone, 400.0) * np.minimum(1.0, t / 1.5) * 0.25
    amb = np.stack([wind + drone, wind * 0.9 + drone], axis=1)
    amb[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))[:, None]
    place(sfx, amb, 0.0, 0.45)
    # Marş + rölanti: 0,15 marş, 0,55'te motor tutar, 2,86'da susar
    crank_n = int(0.42 * SR)
    ct = secs(crank_n)
    crank = np.sin(2 * np.pi * np.cumsum(9.0 + 4.0 * np.sin(ct * 60)) / SR * 6.0)
    crank = lowpass(np.sign(crank) * 0.5 + bandpass(noise(crank_n), 300, 2000) * 0.3, 1800.0) * 0.35
    place(sfx, crank, 0.15)
    idle_n = int((M(2.86) - M(0.55)) * SR)
    it = secs(idle_n)
    rpm = 850.0 + 1500.0 * np.exp(-it * 4.0) + 40.0 * np.sin(it * 3.0)
    g = np.minimum(1.0, it / 0.05) * 0.4
    idle = engine(rpm, 4, g, rough=0.45, bright=2200.0)
    idle[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
    place(engine_bus, idle, 0.55, 1.0, -0.1)
    # Far röle tıkları + ampul vızıltısı
    for at in (0.35, 0.52, 0.58):
        place(sfx, metal_hit(1800.0, 0.08) * 0.5, at, 0.6)
    bn = int((M(2.9) - M(0.7)) * SR)
    bt = secs(bn)
    buzz = np.sign(np.sin(2 * np.pi * 100.0 * bt)) * 0.3 + np.sin(2 * np.pi * 200.0 * bt) * 0.3
    buzz = bandpass(buzz, 100.0, 3000.0) * 0.06
    for a, b in ((1.32, 1.38), (1.45, 1.49), (2.21, 2.26)):
        buzz[int((M(a) - M(0.7)) * SR):int((M(b) - M(0.7)) * SR)] *= 0.1
    place(sfx, buzz, 0.7, 1.0, 0.3)


# --- TEK MÜZİK: 0–22 sn kesintisiz, 150 BPM, Am–F–C–G; katmanlar yavaşça eklenir --------------------
# Ölçü başları: -0,2 + n × 1,6 → 3,0 / 6,2 / 12,6 / 17,4 ölçü başı. Tempo, akor ve ses rengi hiç değişmez;
# yalnızca yoğunluk artar (konuşma için geri planda kalır). 20,0'da son akorla biter.

RHYTHM_START = M(3.0)                  # 5,5: ritim girer (ölçü başı)
BAR = 4 * B2
ANCHOR = RHYTHM_START - 4 * BAR            # ölçü başları: ANCHOR + n × 1,6 (garaj kesmeleri vuruşta)
MUSIC_END = DUR - 1.0                      # son akor; kapanış sesinin altında müzik sürer
CHORDS = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]   # Am F C G


def chord_at(t0: float) -> tuple:
    return CHORDS[int(np.floor((t0 - ANCHOR + 1e-6) / BAR)) % 4]


def level(t0: float) -> float:
    """Yoğunluk eğrisi 0..1, KURGU saniyesiyle (giriş → ritim → dolgun → zirve → vitrin → kapanış)."""
    pts = [(0.0, 0.25), (M(3.0), 0.5), (M(6.2), 0.65), (M(11.0), 0.75), (M(12.6), 1.0), (M(17.0), 0.85),
           (M(20.0), 0.7), (DUR, 0.6)]
    for (a, va), (b, vb) in zip(pts, pts[1:]):
        if a <= t0 < b:
            return va + (vb - va) * (t0 - a) / (b - a)
    return pts[-1][1]


def music_track() -> None:
    """TEK MÜZİK, kurgu zamanında: 0'dan pad, M(3)=5,5'te ritim, M(6,2)'de trampet/arpej, M(12,6)'da zirve,
    MUSIC_END'de son akor."""
    full = M(12.6)
    snare_from = M(6.2)
    t0 = ANCHOR
    while t0 < MUSIC_END - 1e-6:
        dur = min(BAR, MUSIC_END - t0)
        n = int(dur * SR)
        t = secs(n)
        x = np.zeros(n)
        for m in chord_at(t0 + 0.01)[1]:
            for det in (-0.08, 0.08):
                x += saw(2 * np.pi * note_hz(m + det) * t, 14)
        x = lowpass(x, 1400.0, 2.0) * np.minimum(1.0, t / 0.08) * np.minimum(1.0, (dur - t) / 0.08)
        x = x * 0.05 * (0.7 + 0.3 * level(max(t0, 0.0))) * np.clip((t + t0) / 2.5, 0.0, 1.0)   # girişte yumuşak açılır
        place(music, np.stack([x, np.roll(x, 300)], axis=1), t0, edit=True)
        t0 += BAR
    n = int(1.6 * SR)
    t = secs(n)
    x = np.zeros(n)
    for m in (45, 57, 60, 64, 69):
        x += saw(2 * np.pi * note_hz(m) * t, 14)
    x = lowpass(x, 1600.0, 2.0) * np.exp(-t * 1.8) * np.minimum(1.0, t / 0.01)
    place(music, reverb(x * 0.07, 1.6, 2.2, 0.4), MUSIC_END, edit=True)
    place(music, kick(1.2), MUSIC_END, 0.6, edit=True)
    beats = int(round((MUSIC_END - RHYTHM_START) / B2))
    for b in range(beats):
        at = RHYTHM_START + b * B2
        lv = level(at)
        place(music, kick(1.0 + 0.3 * lv), at, 0.55 + 0.35 * lv, edit=True)
        if at >= snare_from and b % 2 == 1:
            place(music, snare(), at, 0.3 * lv, edit=True)
            place(music, clap(), at, 0.22 * lv, edit=True)
        sub = 4 if at >= snare_from else 2
        for h in range(sub):
            place(music, hat(open_=(at >= full and h == sub // 2)), at + h * B2 / sub, (0.35 if h else 0.25) * lv, 0.3, edit=True)
        steps = 4 if full <= at < M(17.0) else 2
        root = chord_at(at)[0]
        for k in range(steps):
            st = B2 / steps
            nn = int(st * 0.9 * SR)
            tt = secs(nn)
            f = note_hz(root - 12 if k % 2 == 0 else root)
            xb = lowpass(saw(2 * np.pi * f * tt, 30), 450.0 + 500.0 * lv, 3.0) * exp_env(nn, 5.0, 0.003)
            place(music, np.tanh(xb * (1.2 + lv)) * 0.32, at + k * st, edit=True)
        if at >= snare_from:
            notes = chord_at(at)[1]
            for k in range(4):
                i = b * 4 + k
                m = notes[i % 3] + (12 if (i // 3) % 2 else 0)
                nn = int(B2 / 4 * 0.95 * SR)
                tt = secs(nn)
                xa = saw(2 * np.pi * note_hz(m + 12) * tt, 10) * exp_env(nn, 14.0, 0.002)
                place(music, lowpass(xa, 3000.0, 2.0) * 0.08 * lv, at + k * B2 / 4, 1.0, 0.35 * np.sin(i * 1.3), edit=True)
    place(music, riser(1.6) * 0.35, M(11.0), edit=True)
    place(music, crash(), full, 0.35, edit=True)


# --- Efektler: tamir 3–7 ---------------------------------------------------------------------------

def act_repair() -> None:
    place(sfx, boom(1.8), 3.0, 0.7)
    for c in STORY_CUTS[1:]:
        place(sfx, whoosh(0.22, 600.0, 5000.0), c - 0.2, 0.4, 0.4)
        place(sfx, metal_hit(260.0, 0.5), c, 0.25)
    for i in range(6):
        place(sfx, metal_hit(420.0 + i * 60, 0.3), 3.05 + i * 0.07, 0.2, -0.6 + i * 0.24)
    gn = int(0.22 * SR)
    gt = secs(gn)
    gun = np.maximum(0, np.sin(2 * np.pi * 32.0 * gt)) ** 8 * bandpass(noise(gn), 600, 6000) + \
        np.sin(2 * np.pi * 180.0 * gt) * 0.2
    place(sfx, gun * 0.9, 3.56, 0.6, 0.5)
    place(sfx, metal_hit(150.0, 0.7), 3.8, 0.55)
    wn = int(0.55 * SR)
    wt = secs(wn)
    whine = np.sin(2 * np.pi * np.cumsum(2600.0 + 300.0 * np.sin(wt * 30.0)) / SR) * 0.15
    grind = bandpass(noise(wn), 1800.0, 9000.0) * (0.6 + 0.4 * np.sin(wt * 47.0)) * 0.5
    g = np.minimum(1.0, wt / 0.03) * np.minimum(1.0, (0.55 - wt) / 0.05)
    place(sfx, (whine + grind) * g, 4.07, 0.45, 0.3)
    place(sfx, whoosh(0.3, 300.0, 3000.0), 4.6, 0.4)
    place(sfx, boom(1.2), 4.867, 0.45)
    place(sfx, metal_hit(200.0, 0.8), 4.867, 0.4)
    zn = int(1.05 * SR)
    zt = secs(zn)
    zap = np.sin(2 * np.pi * np.cumsum(300.0 + 2000.0 * (zt / 1.05) ** 1.5) / SR) * (0.5 + 0.5 * np.sin(zt * 70.0))
    zap += highpass(noise(zn), 5000.0) * 0.3 * (0.5 + 0.5 * np.sin(zt * 23.0))
    place(sfx, zap * np.minimum(1.0, zt / 0.05) * 0.2, 5.15, 0.8)
    place(sfx, shimmer(1.2), 6.2, 0.45)


# --- Efektler: garaj 7–12 --------------------------------------------------------------------------

def act_garage() -> None:
    place(sfx, boom(1.4), 7.0, 0.5)
    for c in GARAGE_CUTS[1:]:
        place(sfx, whoosh(0.3, 500.0, 5000.0), c - 0.25, 0.4, 0.5 if c % 0.8 else -0.5)


# --- Efektler + motorlar: drag 12–17 ---------------------------------------------------------------

def act_drag() -> None:
    for at in TREE:
        place(sfx, beep(880.0, 0.12), at, 0.6)
    place(sfx, beep(1320.0, 0.35), GO, 0.7)
    place(sfx, boom(2.0), GO, 0.8)
    for s in SHIFTS:
        place(sfx, boom(0.6), s, 0.25)
    # Vites patlamaları: boğuk, kısa
    for s in SHIFTS + [GO + 0.05]:
        for k, off in enumerate((0.0, 0.04)):
            bn = int(0.14 * SR)
            bang = lowpass(noise(bn), 900.0) * exp_env(bn, 30.0, 0.001) * 1.6
            place(sfx, np.tanh(bang * 2), s + off, 0.45, -0.4 if k == 0 else 0.4)
    place(sfx, whoosh(0.6, 150.0, 1800.0), 13.35, 0.7, -0.6)
    for c in DRAG_CUTS[3:]:
        place(sfx, whoosh(0.3, 400.0, 3500.0), c - 0.25, 0.35)
    # Motorlar: BOĞUK — düşük ateşleme frekansı, kalın gümbürtü, tiz kesik, ıslık yok
    t = secs(N)
    m = (t >= 11.95) & (t < 16.6)
    tt = t[m]
    for off, pan, g, base in ((0.0, -0.35, 0.8, 1.0), (0.04, 0.35, 0.6, 0.92)):
        rpm = race_rpm(tt, off) * base
        # Ağır çekimde motor da yavaşlar ve kısılır (bant durdurma yok, yumuşak sönüş)
        slow = np.clip((tt - SLOW_FROM) / (FREEZE - SLOW_FROM), 0, 1)
        rpm = rpm * (1.0 - 0.55 * slow)
        gain = np.clip((tt - 11.95) / 0.1, 0, 1) * g * (1.0 - slow) ** 1.5
        gain *= np.where(tt < GO, 0.75, 1.0)
        sig = engine(rpm, 4, gain, rough=0.3, bright=1300.0, hiss=0.05)
        rumble = lowpass(engine(rpm * 0.5, 4, gain, rough=0.4, bright=400.0, hiss=0.0), 220.0, 2.0)
        place(engine_bus, sig + rumble * 0.9, 11.95, 1.0, pan)
    sn = int((GO + 0.5 - 12.3) * SR)
    st = secs(sn)
    screech = bandpass(noise(sn), 900.0, 2500.0) * (0.6 + 0.4 * np.sin(st * 90.0))
    screech *= np.minimum(1.0, st / 0.1) * np.minimum(1.0, (len(st) / SR - st) / 0.2) * 0.15
    place(sfx, screech, 12.3, 1.0)


# --- Efektler: 17–20 garaj vitrini, 20–22 logo -----------------------------------------------------

SHOWCASE = [17.0, 17.75, 18.5, 19.25]
END_CARD = 20.0


def act_logo() -> None:
    place(sfx, reverb(boom(2.4), 2.0, 1.8, 0.4), HIT, 0.7)
    for i, at in enumerate(SHOWCASE[1:] + [END_CARD]):
        place(sfx, whoosh(0.35, 400.0, 5000.0), at - 0.3, 0.4, -0.5 if i % 2 else 0.5)
    for at in SHOWCASE[1:]:
        place(sfx, metal_hit(220.0, 0.5), at, 0.18)
    place(sfx, reverb(boom(2.6), 2.2, 1.8, 0.45), END_CARD, 0.9)
    place(sfx, pop(650.0), 20.3, 0.4)
    place(sfx, pop(880.0), 20.5, 0.5)
    place(sfx, reverb(shimmer(1.4), 1.5, 2.5, 0.5), 20.55, 0.45)


# --- Son mix: müzik konuşmaya yer bırakır ----------------------------------------------------------

def voice_pocket(bus: np.ndarray) -> np.ndarray:
    """Müzikte konuşma bandını (≈0,9–3,5 kHz) ~6 dB oyar; bas ve parlaklık korunur."""
    def shape(f: np.ndarray) -> np.ndarray:
        x = np.log2(np.maximum(f, 20.0) / 1800.0)
        return 1.0 - 0.5 * np.exp(-(x * x) / (2 * 0.8 ** 2))
    return np.stack([spectral(bus[:, c], shape) for c in range(2)], axis=1)


def write_wav(path: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def load_voice(folder: str) -> np.ndarray:
    """Hazırlanmış seslendirme satırlarını (mono 48 kHz) VOICE_AT saniyelerine yerleştirir; ortada, hafif oda."""
    out = np.zeros((N, 2))
    if not folder or not os.path.isdir(folder):
        return out
    files = sorted(f for f in os.listdir(folder) if f.endswith(".wav"))
    for at, f in zip(VOICE_AT, files):
        with wave.open(os.path.join(folder, f)) as w:
            x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0
        x = reverb(x, 0.6, 9.0, 0.08)
        place(out, x, at, 1.0, edit=True)
    return out


def duck_curve(voice: np.ndarray, depth: float) -> np.ndarray:
    """Konuşma varken 1 → (1 - depth); ~60 ms iner, ~350 ms'de geri gelir."""
    env = np.abs(voice).max(axis=1)
    hop = 480
    n = len(env) // hop + 1
    blocks = np.array([env[i * hop:(i + 1) * hop].max() if i * hop < len(env) else 0.0 for i in range(n)])
    on = (blocks > 0.02).astype(float)
    g = np.zeros(n)
    a_dn, a_up = 1.0 - np.exp(-hop / (0.06 * SR)), 1.0 - np.exp(-hop / (0.35 * SR))
    for i in range(1, n):
        g[i] = g[i - 1] + (on[i] - g[i - 1]) * (a_dn if on[i] > g[i - 1] else a_up)
    curve = np.interp(np.arange(len(env)), np.arange(n) * hop, 1.0 - depth * g)
    return curve[:, None]


def main() -> None:
    out_path = sys.argv[1] if len(sys.argv) > 1 else "teaser_soundtrack.wav"
    voice_dir = sys.argv[2] if len(sys.argv) > 2 else ""
    act_story()
    music_track()
    act_repair()
    act_garage()
    act_drag()
    act_logo()
    voice = load_voice(voice_dir)
    mus = voice_pocket(music) * 0.42 * duck_curve(voice, 0.6)
    fx = (engine_bus * 0.42 + sfx * 0.6) * duck_curve(voice, 0.6)
    vo = voice * 1.0
    mix = mus + fx + vo
    mix = np.stack([highpass(mix[:, c], 25.0, 2.0) for c in range(2)], axis=1)
    peak = np.abs(mix).max()
    norm = 1.0 / peak * 1.4
    soft = lambda x: np.tanh(x * norm) / np.tanh(1.4) * 0.89
    write_wav(out_path, soft(mix))
    # Kurgu için ayrı kanallar (aynı kazançla: üst üste konunca ana mix'e yakın)
    base = out_path[:-4] if out_path.endswith(".wav") else out_path
    write_wav(base + "_muzik.wav", soft(mus))
    write_wav(base + "_efekt.wav", soft(fx))
    write_wav(base + "_konusma.wav", soft(vo))
    print(f"{out_path} (+ _muzik / _efekt): {DUR:.1f} sn, tepe {peak:.2f}")


if __name__ == "__main__":
    main()
