"""Seslendirme satırlarını hazırlar: baş/son sessizliği atar, satır içi duraklamaları kısaltır, perdeyi bozmadan
(WSOLA) hızlandırır, 80 Hz altını keser, seviyeyi eşitler. Girdi: blender ile çözülmüş mono WAV'lar
(qa/teaser/decode_voice.py → work/ses_wav/NN.wav). Çıktı: work/ses_hazir/NN.wav (48 kHz mono).
    /snap/blender/current/5.2/python/bin/python3.13 -I qa/teaser/voice_prep.py <ses_wav> <ses_hazir> [hız]
"""
import os
import sys
import wave

import numpy as np

SR = 48000
MAX_GAP = 0.14       # satır içi duraklama üst sınırı (sn)
EDGE = 0.04          # baş/sonda bırakılan pay


def read(path: str) -> np.ndarray:
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0


def write(path: str, x: np.ndarray) -> None:
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def squeeze_pauses(x: np.ndarray) -> np.ndarray:
    win = 480
    n = len(x) // win
    r = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(1))
    on = r > r.max() * 0.04
    idx = np.where(on)[0]
    first, last = idx[0], idx[-1] + 1
    out = []
    i = first
    keep_gap = int(MAX_GAP * SR / win)
    while i < last:
        if on[i]:
            j = i
            while j < last and on[j]:
                j += 1
            out.append(x[i * win:j * win])
            i = j
        else:
            j = i
            while j < last and not on[j]:
                j += 1
            gap = x[i * win:j * win]
            if j - i > keep_gap:
                half = keep_gap * win // 2
                fade = np.linspace(1, 0, half)
                gap = np.concatenate([gap[:half] * fade, gap[-half:] * fade[::-1]])
            out.append(gap)
            i = j
    pad = np.zeros(int(EDGE * SR))
    return np.concatenate([pad] + out + [pad])


def wsola(x: np.ndarray, rate: float, frame: int = 1536, hop: int = 384, tol: int = 384) -> np.ndarray:
    """Perde korumalı hızlandırma (rate > 1 kısaltır): her çıkış penceresi, girişte beklenen yerin ±tol
    çevresinde bir önceki pencerenin doğal devamına en çok benzeyen yerden alınır."""
    win = np.hanning(frame)
    n_out = int(len(x) / rate)
    out = np.zeros(n_out + frame)
    norm = np.zeros(n_out + frame)
    xp = np.concatenate([np.zeros(tol), x, np.zeros(frame + tol + hop)])
    prev = tol
    o = 0
    while o < n_out:
        expect = int(o * rate) + tol
        if o == 0:
            pos = expect
        else:
            target = xp[prev + hop: prev + hop + frame]
            lo, hi = max(0, expect - tol), expect + tol
            seg = xp[lo: hi + frame]
            corr = np.correlate(seg, target, mode="valid")
            pos = lo + int(np.argmax(corr))
        out[o:o + frame] += xp[pos:pos + frame] * win
        norm[o:o + frame] += win
        prev = pos
        o += hop
    return (out / np.maximum(norm, 1e-3))[:n_out]


def highpass(x: np.ndarray, fc: float) -> np.ndarray:
    size = 1 << int(np.ceil(np.log2(len(x) + 1)))
    f = np.fft.rfftfreq(size, 1.0 / SR)
    g = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1.0)) ** 4)
    return np.fft.irfft(np.fft.rfft(x, size) * g, size)[: len(x)]


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    rate = float(sys.argv[3]) if len(sys.argv) > 3 else 1.1
    os.makedirs(dst, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not f.endswith(".wav"):
            continue
        x = read(os.path.join(src, f))
        y = squeeze_pauses(x)
        z = wsola(y, rate) if abs(rate - 1.0) > 1e-3 else y
        z = highpass(z, 80.0)
        rms = np.sqrt(np.mean(z[np.abs(z) > 0.01] ** 2))
        z *= 0.16 / rms                      # konuşma seviyesi eşit
        z = np.tanh(z * 1.6) / 1.6 * 1.0      # yumuşak tepe sınırlama
        write(os.path.join(dst, f), z)
        print(f"{f}: {len(x) / SR:.2f} → {len(y) / SR:.2f} (boşluk) → {len(z) / SR:.2f} sn (×{rate})")


if __name__ == "__main__":
    main()
