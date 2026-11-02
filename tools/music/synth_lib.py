"""numpy ile ses sentezi ve işleme yardımcıları (drift teması + drift lastik cıyağı).

Sistem python'unda numpy yok: Blender'ın python'uyla çalışır (bkz. drift_theme.py başlığı). scipy de yok:
özyinelemeli süzgeçler (SVF) düz python döngüsü (listelerle, ~1 µs/örnek), sabit süzgeçler FFT ile, yankı
FFT evrişimiyle (sentetik, frekansa göre sönen oda yanıtı).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100


# --- Dosya G/Ç ----------------------------------------------------------------------------------

def read_wav(path: str) -> np.ndarray:
    """(kanal, örnek) float64, −1..1."""
    with wave.open(path, "rb") as w:
        ch, width, n = w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    assert width == 2, "yalnız 16 bit"
    return np.frombuffer(raw, dtype="<i2").reshape(-1, ch).T.astype(np.float64) / 32768.0


def write_wav(path: str, x: np.ndarray, seed: int = 7) -> None:
    """x: (kanal, örnek) ya da (örnek,) float; TPDF titreşimiyle 16 bit."""
    x = np.atleast_2d(np.asarray(x, dtype=np.float64))
    rng = np.random.default_rng(seed)
    dither = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0
    data = np.clip(np.round((x + dither) * 32767.0), -32768, 32767).astype("<i2")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[0])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.T.tobytes())


def fluidsynth(midi: bytes, soundfont: str, gain: float = 0.6) -> np.ndarray:
    """MIDI baytlarını FluidSynth'le basar (yankı / chorus kapalı: yankı ortak FFT odasında)."""
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "s.mid")
        out = os.path.join(tmp, "s.wav")
        with open(mid, "wb") as f:
            f.write(midi)
        subprocess.run(["fluidsynth", "-ni", "-q", "-C", "0", "-R", "0", "-g", str(gain), "-r", str(SR),
                        "-F", out, soundfont, mid], check=True, stdout=subprocess.DEVNULL)
        return read_wav(out)


def fit(x: np.ndarray, length: int) -> np.ndarray:
    """(2, n) diziyi uzunluğa kırpar / sıfırla doldurur."""
    if x.shape[1] >= length:
        return x[:, :length].copy()
    return np.pad(x, ((0, 0), (0, length - x.shape[1])))


# --- Ölçüm ----------------------------------------------------------------------------------------

def db(v: float) -> float:
    return 20.0 * np.log10(max(float(v), 1e-12))


def rms_db(x: np.ndarray) -> float:
    return db(np.sqrt(np.mean(np.square(x))))


def peak_db(x: np.ndarray) -> float:
    return db(np.max(np.abs(x)))


# --- Osilatörler ----------------------------------------------------------------------------------

def _phase(freq, n: int, phase0: float) -> tuple[np.ndarray, np.ndarray]:
    dt = np.broadcast_to(np.asarray(freq, dtype=np.float64) / SR, (n,)).copy()
    phase = (phase0 + np.concatenate(([0.0], np.cumsum(dt[:-1])))) % 1.0
    return phase, dt


def saw(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """polyBLEP bant sınırlı testere (freq sabit ya da dizi)."""
    phase, dt = _phase(freq, n, phase0)
    y = 2.0 * phase - 1.0
    m = phase < dt
    t = phase[m] / dt[m]
    y[m] -= t + t - t * t - 1.0
    m = phase > 1.0 - dt
    t = (phase[m] - 1.0) / dt[m]
    y[m] -= t * t + t + t + 1.0
    return y


def sine(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    phase, _ = _phase(freq, n, phase0)
    return np.sin(2.0 * np.pi * phase)


DETUNE = np.array([-1.0, -0.62, -0.28, 0.0, 0.29, 0.61, 0.97])
VOICE_GAIN = np.array([0.6, 0.75, 0.88, 1.0, 0.88, 0.75, 0.6])


def supersaw(freq, n: int, rng: np.random.Generator, cents: float = 20.0, width: float = 0.85) -> np.ndarray:
    """7 sesli süpersaw (stereo yayılım). freq sabit ya da dizi. Çıktı (2, n)."""
    out = np.zeros((2, n))
    base = np.asarray(freq, dtype=np.float64)
    for d, g in zip(DETUNE, VOICE_GAIN):
        v = saw(base * 2.0 ** (d * cents / 1200.0), n, rng.random()) * g
        pan = d * width
        out[0] += v * np.sqrt(0.5 * (1.0 - pan))
        out[1] += v * np.sqrt(0.5 * (1.0 + pan))
    return out / VOICE_GAIN.sum() * 1.7


# --- Süzgeçler -------------------------------------------------------------------------------------

def svf(x: np.ndarray, cutoff, q: float = 0.707, mode: str = "lp") -> np.ndarray:
    """TPT durum değişkenli süzgeç (Zavalishin), kesim frekansı sabit ya da örnek başına dizi."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    fc = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (n,)), 15.0, SR * 0.45)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, A1, A2, A3 = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist()
    lp = [0.0] * n
    bp = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = A1[i] * ic1 + A2[i] * v3
        v2 = ic2 + A2[i] * ic1 + A3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        lp[i] = v2
        bp[i] = v1
    lpa, bpa = np.array(lp), np.array(bp)
    if mode == "lp":
        return lpa
    if mode == "bp":
        return bpa
    return x - k * bpa - lpa   # hp


def svf2(x: np.ndarray, cutoff, q: float = 0.707, mode: str = "lp") -> np.ndarray:
    """Stereo (2, n) için kanal kanal SVF."""
    return np.stack([svf(x[0], cutoff, q, mode), svf(x[1], cutoff, q, mode)])


def fft_filter(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2,
               pad: bool = True) -> np.ndarray:
    """Sabit Butterworth genlik eğrisi (faz sıfır), FFT ile. x (n,) ya da (k, n). pad=False → dairesel (döngü)."""
    x = np.asarray(x, dtype=np.float64)
    n = x.shape[-1]
    size = n * 2 if pad else n
    f = np.fft.rfftfreq(size, 1.0 / SR)
    h = np.ones_like(f)
    if hi:
        h *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo:
        h *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    y = np.fft.irfft(np.fft.rfft(x, n=size, axis=-1) * h, n=size, axis=-1)
    return y[..., :n]


def bandpass_fft(x: np.ndarray, center: float, q: float, pad: bool = True) -> np.ndarray:
    """Tek tepeli rezonans (2. derece bant geçiren genlik eğrisi)."""
    x = np.asarray(x, dtype=np.float64)
    n = x.shape[-1]
    size = n * 2 if pad else n
    f = np.maximum(np.fft.rfftfreq(size, 1.0 / SR), 1e-3)
    h = 1.0 / np.sqrt(1.0 + (q * (f / center - center / f)) ** 2)
    return np.fft.irfft(np.fft.rfft(x, n=size, axis=-1) * h, n=size, axis=-1)[..., :n]


# --- Zarflar ---------------------------------------------------------------------------------------

def env_adsr(hold: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    """hold: nota süresi (örnek); dönen dizi hold + release uzunluğunda."""
    a = max(int(attack * SR), 1)
    d = max(int(decay * SR), 1)
    r = max(int(release * SR), 1)
    e = np.full(hold, sustain)
    seg = np.linspace(0.0, 1.0, a, endpoint=False)
    e[:min(a, hold)] = seg[:min(a, hold)]
    if hold > a:
        dd = np.arange(min(d, hold - a))
        e[a:a + len(dd)] = sustain + (1.0 - sustain) * np.exp(-dd / (d / 4.0))
    last = e[-1] if hold > 0 else 0.0
    return np.concatenate([e, last * np.exp(-np.arange(r) / (r / 5.0))])


def place(buf: np.ndarray, start: int, sig: np.ndarray) -> None:
    """buf (2, N) içine start'tan itibaren ekler (taşanı keser). sig (n,) ise iki kanala da."""
    if sig.ndim == 1:
        sig = np.stack([sig, sig])
    if start >= buf.shape[1]:
        return
    if start < 0:
        sig = sig[:, -start:]
        start = 0
    end = min(buf.shape[1], start + sig.shape[1])
    buf[:, start:end] += sig[:, :end - start]


def pan(sig: np.ndarray, p: float) -> np.ndarray:
    """Mono → stereo, sabit güç (p −1 sol … +1 sağ)."""
    return np.stack([sig * np.sqrt(0.5 * (1.0 - p)), sig * np.sqrt(0.5 * (1.0 + p))]) * np.sqrt(2.0)


# --- Yankı ve dinamik -----------------------------------------------------------------------------

def make_ir(rng: np.random.Generator, seconds: float = 2.6, rt60=(2.1, 1.7, 0.85), predelay: float = 0.018) -> np.ndarray:
    """Sentetik stereo oda yanıtı: bantlara bölünmüş gürültü, her bant kendi RT60'ıyla söner (bas uzun, tiz kısa)."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)
    low = 1.0 / np.sqrt(1.0 + (f / 450.0) ** 4)
    high = 1.0 / np.sqrt(1.0 + (3800.0 / np.maximum(f, 1e-3)) ** 4)
    mid = np.clip(1.0 - low - high, 0.0, 1.0)
    out = np.zeros((2, n + int(predelay * SR)))
    for ch in range(2):
        spec = np.fft.rfft(rng.standard_normal(n))
        ir = np.zeros(n)
        for mask, rt in zip((low, mid, high), rt60):
            ir += np.fft.irfft(spec * mask, n=n) * np.exp(-6.91 * t / rt)
        ir *= np.minimum(1.0, t / 0.012)        # yumuşak başlangıç (ilk yansımalar yayılır)
        out[ch, int(predelay * SR):] = ir
    return out / np.sqrt(np.sum(out ** 2) / 2.0)


def convolve(x_mono: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """Mono gönderme → stereo ıslak (FFT evrişim), giriş uzunluğunda."""
    n = len(x_mono)
    size = 1 << int(np.ceil(np.log2(n + ir.shape[1])))
    X = np.fft.rfft(x_mono, n=size)
    return np.stack([np.fft.irfft(X * np.fft.rfft(ir[c], n=size), n=size)[:n] for c in range(2)])


def moving_average(x: np.ndarray, width: int) -> np.ndarray:
    width = max(int(width), 1)
    c = np.cumsum(np.concatenate(([0.0], x)))
    out = (c[width:] - c[:-width]) / width
    return np.concatenate([np.full(width - 1, out[0]), out])


def compress(x: np.ndarray, threshold_db: float, ratio: float, window: float = 0.03) -> np.ndarray:
    """Yumuşak tutkal kompresör: stereo RMS (pencere), eşik üstü ratio:1, kazanç yumuşatılır."""
    power = moving_average(np.mean(x ** 2, axis=0), int(window * SR))
    level = 10.0 * np.log10(np.maximum(power, 1e-12))
    over = np.maximum(level - threshold_db, 0.0)
    gain_db = -over * (1.0 - 1.0 / ratio)
    gain_db = moving_average(gain_db, int(0.02 * SR))
    return x * 10.0 ** (gain_db / 20.0)


def limit(x: np.ndarray, ceiling_db: float = -1.0, lookahead: float = 0.0015) -> np.ndarray:
    """İleri bakışlı tepe sınırlayıcı: gereken kazancın min süzgeci (±2W) + ortalaması (W) → tavan aşılmaz."""
    ceiling = 10.0 ** (ceiling_db / 20.0)
    peak = np.max(np.abs(x), axis=0)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    w = max(int(lookahead * SR), 1)
    padded = np.pad(need, (2 * w, 2 * w), constant_values=1.0)
    win = np.lib.stride_tricks.sliding_window_view(padded, 4 * w + 1).min(axis=1)
    # ortalanmış ortalama: ma[i + w − 1] = win[i − w//2 … i + w − w//2 − 1] ortalaması
    smooth = moving_average(np.pad(win, (w // 2, w - w // 2), mode="edge"), w)[w - 1: w - 1 + len(need)]
    y = x * smooth
    return np.clip(y, -ceiling, ceiling)
