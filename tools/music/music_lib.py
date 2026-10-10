"""Oyun müziklerinin ortak altyapısı: nota adları, MIDI yazımı ve kesintisiz döngü basımı.

Beste dosyaları (garage_theme.py, drag_theme.py) yalnızca notaları yazar; burası MIDI'ye çevirir,
FluidSynth + FluidR3 GM ses bankasıyla (MIT lisanslı) WAV'a basar. Dış kütüphane gerekmez.

Kesintisiz döngü: parça iki tur basılır, İKİNCİ tur kesilip alınır (ilk turun yankı kuyruğu döngünün
başına doğal olarak biner). FluidSynth olayları 64 örneklik bloklara yuvarladığı için iki tur örnek
örnek aynı değil: ikinci turun sonu, ham baskıda döngü başına doğal olarak akan birinci turun sonuyla
yumuşakça karıştırılır (XFADE). Chorus kapalıdır: dalgalanması döngü uzunluğuyla uyuşmaz, dikiş tıklar.
"""
import array
import os
import struct
import subprocess
import sys
import tempfile
import wave
from typing import Callable

TPB = 480                 # MIDI tick / vuruş
RATE = 44100
XFADE = 2048              # döngü dikişindeki karışım (örnek, ~46 ms)
SOUNDFONT = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
DRUMS = 9                 # GM davul kanalı
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Nota adları → MIDI numarası (C4 = 60)
_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name: str) -> int:
    pitch = _NAMES[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        pitch += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        pitch -= 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pitch


class Song:
    """bpm: tempo. swing: vuruş içi ikinci sekizliğin yeri (0.5 = düz, 2/3 = swing).
    mix: kanal → {"program", "volume", "pan", "reverb"} (davul kanalında program yok)."""

    def __init__(self, bpm: int, swing: float, mix: dict[int, dict[str, int]]) -> None:
        self.bpm = bpm
        self.swing_at = swing
        self.events: list[tuple[int, int, bytes]] = []   # (tick, sıra, mesaj); sıra: note-off önce
        for ch, m in mix.items():
            if "program" in m:
                self.events.append((0, -1, bytes([0xC0 | ch, m["program"]])))
            self.events.append((0, -1, bytes([0xB0 | ch, 7, m["volume"]])))
            self.events.append((0, -1, bytes([0xB0 | ch, 10, m["pan"]])))
            self.events.append((0, -1, bytes([0xB0 | ch, 91, m["reverb"]])))
            self.events.append((0, -1, bytes([0xB0 | ch, 93, 0])))   # chorus yok (bkz. başlık)

    def swing(self, beat: float) -> float:
        """Vuruş içindeki ikinci sekizliği swing yerine kaydırır."""
        whole = int(beat)
        if abs(beat - whole - 0.5) < 1e-6:
            return whole + self.swing_at
        return beat

    def note(self, ch: int, beat: float, dur: float, pitch: int, vel: int, nudge: float = 0.0) -> None:
        """nudge: swing'den SONRA eklenen küçük kayma (vuruş; tellerin sırayla çalınması)."""
        start = int(round((self.swing(beat) + nudge) * TPB))
        end = int(round((self.swing(beat + dur) + nudge) * TPB)) - 8
        end = max(end, start + 30)
        vel = max(1, min(127, vel))
        self.events.append((start, 1, bytes([0x90 | ch, pitch, vel])))
        self.events.append((end, 0, bytes([0x80 | ch, pitch, 0])))

    def midi(self) -> bytes:
        tempo = 60_000_000 // self.bpm
        track = bytearray()
        track += _vlq(0) + bytes([0xFF, 0x51, 0x03]) + tempo.to_bytes(3, "big")
        last = 0
        for tick, _, msg in sorted(self.events, key=lambda e: (e[0], e[1])):
            track += _vlq(tick - last) + msg
            last = tick
        track += _vlq(TPB * 8) + bytes([0xFF, 0x2F, 0x00])   # yankı kuyruğu için sessizlik
        header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, TPB)
        return header + b"MTrk" + struct.pack(">I", len(track)) + bytes(track)


def _vlq(value: int) -> bytes:
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.append(0x80 | (value & 0x7F))
        value >>= 7
    return bytes(reversed(out))


def render_loop(song: Song, compose: Callable[[Song, int], None], bars: int, default_out: str,
                gain: float = 0.55) -> None:
    """compose(song, başlangıç_ölçüsü) iki kez çağrılır (iki tur); döngü WAV'ı yazılır.
    Çıktı yolu komut satırından verilebilir (yoksa default_out, depo köküne göre)."""
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, default_out)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    compose(song, 0)
    compose(song, bars)          # ikinci tur: döngü buradan kesilir
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "song.mid")
        raw = os.path.join(tmp, "raw.wav")
        with open(mid, "wb") as f:
            f.write(song.midi())
        subprocess.run(["fluidsynth", "-ni", "-q", "-C", "0", "-g", str(gain), "-r", str(RATE), "-F", raw,
                        SOUNDFONT, mid], check=True, stdout=subprocess.DEVNULL)
        with wave.open(raw, "rb") as src:
            channels, width = src.getnchannels(), src.getsampwidth()
            frames = src.readframes(src.getnframes())
    loop_frames = round(bars * 4 * 60 / song.bpm * RATE)
    chunk = _seamless(frames, channels, loop_frames)
    with wave.open(out_path, "wb") as dst:
        dst.setnchannels(channels)
        dst.setsampwidth(width)
        dst.setframerate(RATE)
        dst.writeframes(chunk)
    print(f"{out_path}: {loop_frames / RATE:.1f} sn döngü, {len(chunk) / 1e6:.1f} MB ham")


def _seamless(frames: bytes, channels: int, loop_frames: int) -> bytes:
    """İkinci turu keser; son XFADE örneği birinci turun sonuna doğru karıştırır (bkz. başlık)."""
    data = array.array("h", frames)
    if sys.byteorder == "big":
        data.byteswap()
    start, end = loop_frames * channels, 2 * loop_frames * channels
    out = data[start:end]
    count = XFADE * channels
    for k in range(count):
        t = (k // channels + 1) / XFADE          # 0 → 1: sona doğru birinci turun sonuna geçilir
        own = out[len(out) - count + k]
        first = data[start - count + k]
        out[len(out) - count + k] = int(round(own * (1.0 - t) + first * t))
    if sys.byteorder == "big":
        out.byteswap()
    return out.tobytes()
