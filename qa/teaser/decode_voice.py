"""ElevenLabs MP3'lerini mono 48 kHz WAV'a çözer (sistemde ffmpeg yok; Blender'ın aud modülü kullanılır).
    blender -b --factory-startup --python qa/teaser/decode_voice.py -- <mp3_klasörü> <wav_klasörü>
"""
import os
import sys
import wave

import aud
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
os.makedirs(dst, exist_ok=True)
for f in sorted(os.listdir(src)):
    if not f.lower().endswith(".mp3"):
        continue
    x = np.asarray(aud.Sound(os.path.join(src, f)).resample(48000, False).data(), dtype=np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    with wave.open(os.path.join(dst, f[:-4] + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("SES", f, f"{len(x) / 48000:.2f} sn")
