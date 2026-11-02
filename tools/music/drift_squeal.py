#!/usr/bin/env python3
"""DRIFT LASTİK CIYAĞI — drift olayındaki araçların sürekli lastik uluması (4,0 sn KESİNTİSİZ döngü, mono).

Oyunda her drift aracında AudioStreamPlayer3D ile çalar; düzey ve perde (pitch_scale ~0,88–1,15) kaymaya göre
çalışma zamanında değişir — bu yüzden ses nötr, çok tiz değil.

Katmanlar: dar bantlı ton (ana uluma ~1 kHz + 780 / 1520 Hz modları + zayıf 2. harmonik; merkezleri yavaşça birkaç %
dolaşır, 6–18 Hz titreşir), aynı modların çevresinde dar bant gürültü (ton "kirli" olsun), 8–20 Hz pürüz (genlik
titremesi), lastik sürtünme hışırtısı (geniş bant 1,5–6 kHz) ve hafif alçak gürleme.

KESİNTİSİZLİK: her şey döngü uzunluğunda DAİRESEL üretilir — gürültüler FFT ızgarasında (0,25 Hz aralık), modülatörler
DC'siz bant sınırlı FFT gürültüsü (döngüde toplamı sıfır), ton merkezleri 0,25 Hz'in katı → her kısmi döngüde tam sayı
devir yapar; dikişte süreksizlik yok.

Kullanım: /snap/blender/current/5.2/python/bin/python3.13 -I tools/music/drift_squeal.py [çıktı.wav]
  (varsayılan assets/audio/sfx/drift_squeal.wav). Godot içe aktarımında edit/loop_mode=2 (ileri döngü).
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import synth_lib as S  # noqa: E402
from synth_lib import SR  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SECONDS = 4.0
N = int(SECONDS * SR)          # 176400: FFT ızgarası 0,25 Hz
PEAK_DB = -3.0
# (merkez Hz — 0,25'in katı, düzey, yavaş gezinme oranı)
MODES = [(1000.0, 1.0, 0.035), (780.0, 0.42, 0.03), (1520.0, 0.5, 0.028), (2000.0, 0.22, 0.035)]
rng = np.random.default_rng(86)


def band_noise(lo: float, hi: float, slope: float = 0.0) -> np.ndarray:
    """Dairesel (döngüde kesintisiz), DC'siz, birim RMS bant sınırlı gürültü; slope: f^-slope genlik eğimi."""
    f = np.fft.rfftfreq(N, 1.0 / SR)
    spec = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f)))
    mask = (f >= lo) & (f <= hi)
    spec *= mask * np.where(f > 0, np.maximum(f, 1e-3) ** -slope, 0.0)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n=N)
    return x / np.sqrt(np.mean(x ** 2))


def circular_bandpass(x: np.ndarray, center: float, q: float) -> np.ndarray:
    return S.bandpass_fft(x, center, q, pad=False)


def build() -> np.ndarray:
    t = np.arange(N) / SR
    roughness = band_noise(8.0, 20.0)                 # pürüz (genlik titremesi)
    swell = band_noise(0.25, 1.0)                     # yavaş nefes
    am = np.clip(1.0 + 0.32 * roughness, 0.15, None) * (1.0 + 0.16 * swell)
    tone = np.zeros(N)
    grit = np.zeros(N)
    white = rng.standard_normal(N)
    for center, gain, wander in MODES:
        drift = band_noise(0.25, 2.0)                 # merkez gezinmesi
        jitter = band_noise(6.0, 18.0)
        freq = center * (1.0 + wander * 0.6 * drift + 0.007 * jitter)
        phase = 2.0 * np.pi * np.concatenate(([0.0], np.cumsum(freq[:-1]))) / SR
        # tam sayı devir: döngü sonunda faz 2π·center·SECONDS (gezinme/titreşim DC'siz → toplamı sıfır)
        partial = np.sin(phase) + 0.16 * np.sin(3.0 * phase)   # hafif tek harmonik (sert tını), gezinmeyi izler
        tone += gain * partial * (1.0 + 0.12 * band_noise(2.0, 9.0))
        grit += gain * circular_bandpass(white, center, 18.0)
    grit /= np.sqrt(np.mean(grit ** 2)) / np.sqrt(np.mean(tone ** 2))
    howl = (0.68 * tone + 0.5 * grit) * am
    scrub = S.fft_filter(rng.standard_normal(N), lo=1400.0, hi=5800.0, pad=False)
    scrub *= (1.0 + 0.25 * roughness) * np.sqrt(np.mean(howl ** 2)) / np.sqrt(np.mean(scrub ** 2))
    rumble = S.fft_filter(rng.standard_normal(N), lo=35.0, hi=170.0, pad=False)
    rumble *= np.sqrt(np.mean(howl ** 2)) / np.sqrt(np.mean(rumble ** 2))
    x = howl + 10 ** (-13.0 / 20) * scrub + 10 ** (-20.0 / 20) * rumble
    x = S.fft_filter(x, hi=5200.0, order=1, pad=False)          # tizi yumuşat (dairesel)
    return x * 10 ** (PEAK_DB / 20.0) / np.max(np.abs(x))


def main() -> None:
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/audio/sfx/drift_squeal.wav")
    x = build()
    S.write_wav(out_path, x)
    diffs = np.abs(np.diff(x))
    seam = abs(x[0] - x[-1])
    print(f"{out_path}: {N / SR:.2f} sn döngü, tepe {S.peak_db(x):.2f} dBFS, RMS {S.rms_db(x):.2f} dBFS, "
          f"dikiş farkı {seam:.4f} (komşu örnek farkı ortanca {np.median(diffs):.4f}, %99 {np.percentile(diffs, 99):.4f})")


if __name__ == "__main__":
    main()
