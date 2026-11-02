"""KEDİ SESLERİ (GARAJ DOSTLARI, 2026-11-02): Freesound'daki CC0 gerçek kayıtlardan oyunun kedi seslerini üretir.
Kullanıcı kararı (2026-10-31): ses GERÇEK KAYIT, CC0 / ücretsiz lisanslı (kod sentezi değil); 2026-11-02: yalnız
YAKIN KAMERADA duyulur (sevince mırlar, selam verir, oltada cıvıldar).

Kaynaklar Freesound'un herkese açık HQ önizlemeleri (OGG ~192 kbps; asıl dosya giriş ister, oyunda zaten QOA ile
sıkışır). İndirilenler assets/pets/source/sounds/ (git dışı, .gdignore) önbelleğinde kalır.

İşlem (yalnız stdlib + ffmpeg): kes → yüksek/alçak geçiren → etkin kısmın RMS'i hedefe (tepe −1 dBFS'i aşmaz) →
yumuşak giriş/çıkış. Mırlama dikişsiz döngü: kesimin sonu, başından önceki parçayla eşit güçte çapraz geçer; döngü
.import'ta (edit/loop_mode=2, loop_end=-1 — LoopedWav taşma tuzağı içe aktarılan seste yok).

  python3 tools/pets/kedi_sesleri.py            # assets/audio/pets/*.wav + KAYNAKLAR.txt
  python3 tools/pets/kedi_sesleri.py --dinle    # + ~/Projects/ct_shots/pets/ses/dinle.wav (hepsi arka arkaya)
"""
import array, math, os, subprocess, sys, urllib.request, wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "assets/pets/source/sounds")
OUT = os.path.join(ROOT, "assets/audio/pets")
LISTEN = os.path.expanduser("~/Projects/ct_shots/pets/ses")
RATE = 44100

## Freesound kimliği → (yazar, başlık, HQ önizleme yolu). Hepsi CC0 1.0 (sayfalarında doğrulandı, 2026-11-02).
SOURCES = {
    717866: ("TRP", "230707 Cat purring, close mic, Myshka, EM272, Toronto 11am", "717/717866_97550"),
    686775: ("nathan-osman", "meow-1.wav", "686/686775_2956624"),
    412017: ("skymary", "cat meow short", "412/412017_3652520"),
    479272: ("steffcaffrey", "New Cat Meow 1", "479/479272_1844073"),
    634174: ("Tyler31898", "Cat Chirps.wav", "634/634174_10382509"),
    448084: ("Breviceps", "Cute Kitten Meow", "448/448084_9159316"),
    571216: ("TRP", "181118 Cat, various meows, squeeks, purrs from my 3yr old cat", "571/571216_97550"),
    200336: ("jsbarrett", "Cat trilling", "200/200336_3159560"),
    451250: ("dreamstobecome", "cat chirp.wav", "451/451250_7758073"),
    535318: ("dreamstobecome", "catpurrchirp.m4a", "535/535318_7758073"),
    508686: ("megrez7274", "SND_CatHighMeows.wav", "508/508686_10953321"),
}

## Ad → (kaynak, başlangıç sn, bitiş sn). Adın öneki oyundaki kümeyi belirler (PetVoice.POOLS).
##   hello — yakın kamera açılınca selam miyavı      happy — numara / aksesuar / ad koyma sevinci
##   trill — sevilirken ara sıra "mrrp"               chirp — oltadaki tüye cıvıldama (av sesi)
CLIPS = {
    "hello_1": (686775, 0.00, 0.84),
    "hello_2": (412017, 0.30, 1.02),
    "hello_3": (479272, 0.00, 0.92),
    "happy_1": (634174, 21.70, 22.60),
    "happy_2": (448084, 0.00, 0.60),
    "happy_3": (571216, 37.33, 38.52),
    "trill_1": (200336, 3.42, 4.21),
    "trill_2": (200336, 7.68, 8.40),
    "trill_3": (200336, 9.82, 10.29),
    "chirp_1": (451250, 0.56, 0.77),
    "chirp_2": (535318, 12.95, 13.41),
    "chirp_3": (571216, 20.41, 20.70),
    "chirp_4": (508686, 0.15, 0.45),
}
## Mırlama: kaydın en düzgün 9 sn'si (0,05 sn RMS sapması en düşük pencere, ani tepe yok).
PURR = (717866, 27.30, 36.30)
PURR_XFADE = 0.6

VOICE_FILTER = "highpass=f=150,lowpass=f=10000"
## Telefon hoparlörü 300 Hz altını veremez: gövde gürlemesini biraz kes, 600 Hz "rrrr" dokusunu hafif öne çıkar.
## Sıkıştırıcı: nefes tepeleri (tepe/RMS ~20 dB) düzeyi tepe sınırına dayatıyordu; oyun kaydında mırlama müziğin
## altında kalıyordu (200–1500 Hz'te yalnız +1,4 dB) → tepeler bastırılıp ortalama yükselir.
PURR_FILTER = ("highpass=f=70,lowpass=f=3500,equalizer=f=600:t=q:w=1:g=3,"
               "acompressor=threshold=0.04:ratio=4:attack=8:release=160:knee=4")
VOICE_RMS_DB = -16.0
PURR_RMS_DB = -15.0
PEAK_DB = -1.0


def fetch(sid: int) -> str:
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "%d.ogg" % sid)
    if not os.path.exists(path):
        url = "https://cdn.freesound.org/previews/%s-hq.ogg" % SOURCES[sid][2]
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as r, open(path + ".tmp", "wb") as f:
            f.write(r.read())
        os.replace(path + ".tmp", path)
    return path


def decode(sid: int, start: float, end: float, filt: str) -> list:
    cmd = ["ffmpeg", "-loglevel", "error", "-i", fetch(sid), "-ss", "%.3f" % start, "-to", "%.3f" % end,
           "-ac", "1", "-ar", str(RATE), "-af", filt, "-f", "s16le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    pcm = array.array("h")
    pcm.frombytes(raw)
    return [s / 32768.0 for s in pcm]


def active_rms_db(x: list) -> float:
    hop = RATE // 100
    frames = []
    for i in range(0, len(x) - hop, hop):
        e = sum(v * v for v in x[i:i + hop]) / hop
        frames.append(10.0 * math.log10(e + 1e-12))
    top = max(frames)
    act = [f for f in frames if f > top - 25.0]
    return 10.0 * math.log10(sum(10.0 ** (f / 10.0) for f in act) / len(act))


def normalize(x: list, rms_db: float) -> list:
    gain = 10.0 ** ((rms_db - active_rms_db(x)) / 20.0)
    peak = max(abs(v) for v in x)
    gain = min(gain, 10.0 ** (PEAK_DB / 20.0) / max(peak, 1e-9))
    return [v * gain for v in x]


def fade(x: list, fin: float, fout: float) -> list:
    n_in, n_out = int(fin * RATE), int(fout * RATE)
    for i in range(min(n_in, len(x))):
        x[i] *= 0.5 - 0.5 * math.cos(math.pi * i / n_in)
    for i in range(min(n_out, len(x))):
        x[len(x) - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / n_out)
    return x


## Dikişsiz döngü: gövde = x[xf : L+xf]; son xf örnek x[L+i] ile x[i] eşit güçte karışır → son örnek x[xf-1]'e
## varır, ilk örnek x[xf] onu izler.
def loop(x: list, xf: float) -> list:
    n = int(xf * RATE)
    length = len(x) - n
    out = x[n:length + n]
    for i in range(n):
        t = (i + 0.5) / n * math.pi * 0.5
        out[length - n + i] = x[length + i] * math.cos(t) + x[i] * math.sin(t)
    return out


def write(path: str, x: list) -> None:
    pcm = array.array("h", [max(-32767, min(32767, int(round(v * 32767.0)))) for v in x])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    made = {}
    sid, a, b = PURR
    purr = loop(normalize(decode(sid, a, b + PURR_XFADE, PURR_FILTER), PURR_RMS_DB), PURR_XFADE)
    write(os.path.join(OUT, "purr.wav"), purr)
    made["purr"] = purr
    for name, (sid, a, b) in CLIPS.items():
        x = fade(normalize(decode(sid, a, b, VOICE_FILTER), VOICE_RMS_DB), 0.008, 0.05)
        write(os.path.join(OUT, name + ".wav"), x)
        made[name] = x
    with open(os.path.join(OUT, "KAYNAKLAR.txt"), "w", encoding="utf-8") as f:
        f.write("Kedi sesleri — hepsi Freesound, CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/).\n")
        f.write("Üretim: tools/pets/kedi_sesleri.py (kesim, süzgeç, düzey, döngü).\n\n")
        uses = {}
        for name, (sid, a, b) in list(CLIPS.items()) + [("purr", PURR)]:
            uses.setdefault(sid, []).append("%s (%.2f–%.2f sn)" % (name, a, b))
        for sid, (user, title, _p) in SOURCES.items():
            f.write("%s — \"%s\" by %s — https://freesound.org/people/%s/sounds/%d/\n    %s\n"
                    % (sid, title, user, user, sid, ", ".join(uses.get(sid, []))))
    for name, x in made.items():
        print("%-8s %5.2f sn  etkin RMS %6.1f dB  tepe %6.1f dB" % (
            name, len(x) / RATE, active_rms_db(x), 20.0 * math.log10(max(abs(v) for v in x))))
    if "--dinle" in sys.argv:
        os.makedirs(LISTEN, exist_ok=True)
        gap = [0.0] * int(0.6 * RATE)
        seq = purr * 2 + gap
        for name in CLIPS:
            seq += made[name] + gap
        write(os.path.join(LISTEN, "dinle.wav"), seq)
        print("dinleme →", os.path.join(LISTEN, "dinle.wav"))


if __name__ == "__main__":
    main()
