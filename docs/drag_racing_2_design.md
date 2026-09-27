# DRAG RACING 2.0 — Tasarım

Amaç: mevcut "5 kez doğru anda dokun" mekaniğini, **gerçek bir basitleştirilmiş şanzıman
modeli** üzerine kurulu RPM + vites + redline + shift timing sistemine dönüştürmek. CSR2'yi
kopyalamak değil; onun drag gameplay DNA'sını Car Town görsel kimliğiyle uyarlamak.

## A) CSR2'de temel mekanik

Üç zamanlama anı var: **kalkış**, **vites geçişleri**, (ve NOS). Kalkışta oyuncu gazı tutup
devir ibresini yeşil "sweet spot"a getirir ve geri sayım biterken bırakır. Yarış boyunca her
vites için takometrede bir **perfect shift penceresi** vardır; ibre yeşile girdiğinde vites
atılır. Doğru zamanlama vites başına yüzde birkaç saniye kazandırır, kaçırmak kaybettirir.
Resmî yardım sayfası bunu "ibrenin yanındaki ışık yeşilken vites paddle'ına bas" diye anlatır.

## B) RPM davranışı

RPM sadece animasyon değil, fiziğin kendisi: motor devri tekerlek hızı × vites oranı × diferansiyel
oranıdır. Hızlandıkça devir yükselir, vites atınca oran değiştiği için **anında düşer**, sonra
tekrar tırmanır. Amaç motoru **power band** içinde tutmaktır: "launch in the powerband, stay in
the powerband, cross the line near peak power".

## C) Shift davranışı

Vites bir olaydır, bir bonus değil: debriyaj ayrılır, kademe değişir, devir yeni orana düşer,
debriyaj kavrar, hızlanma devam eder. Geçiş süresi boyunca çekiş yoktur. Yeni viteste devrin
nereye düştüğü tamamen **oran farkına** bağlıdır — bu yüzden erken vites motoru bandın altına
atar ve araç bocalar.

## D) Redline davranışı

Devir sınırına dayanınca limitçi devreye girer: tork kesilir, ivme neredeyse durur, orada geçen
her salise kayıptır. Sınırda beklemek "geç vites"in fiziksel cezasıdır; ayrıca bir ceza katsayısı
gerekmez.

## E) Perfect / good / early / late

CSR2'de sonuç ikili değil: perfect (yeşil), good (yeşile yakın), kaçırma (kırmızı). Topluluk
kaynakları bunun araçtan araca değiştiğini gösteriyor: gücü devrin altında olan araçlarda
**erken perfect** shift'ler, gücü yukarıda olan araçlarda **derin/geç** shift'ler daha hızlı.
Yani "yeşil nokta" mutlak optimum olmak zorunda değil — teorik en hızlı pattern ayrı bir şey.

## F) Launch davranışı

Kalkış devri performansı belirler: çok düşük → **bog** (motor bandın altında, zayıf çıkış),
optimum → güçlü çıkış, çok yüksek → **wheelspin** (tekerlek boşa döner, çekiş kaybı). Bazı
araçlarda "needle drop" denen, belirli bir devirden (ör. 3800-4800) bırakma tekniği kullanılır.

## G) Needle drop / RPM drop

İki ayrı şey: *needle drop* kalkış tekniği (ibreyi belirli devre düşürüp bırakmak), *RPM drop*
ise vites sonrası devrin oran farkı kadar düşmesi. İkisi de bizim modelde var.

## H) Bizim oyuna alınacak prensipler

1. **Gerçek motor devri** (idle…redline), hızdan ve vites oranından türetilir.
2. **Gerçek vites oranları + diferansiyel**; vites sonrası devir düşüşü oran farkının sonucudur.
3. **Tork eğrisi / power band**; ivme devrin fonksiyonudur.
4. **Redline + limitçi**: sınırda tork kesilir, zaman kaybedilir.
5. **Shift time**: geçiş sırasında çekiş yok; süre vites kalitesine göre kısalır/uzar.
6. **Araç başına farklı optimum shift devri**, oran farkından hesaplanır (elle girilmez).
7. **Launch RPM**: bog / optimum / wheelspin.
8. **Wheelspin**: çekiş limiti aşılınca tekerlek hızı motordan ayrılır.
9. **AI aynı fiziği kullanır**, yalnızca hata payı sınıfa göre değişir.

## I) Alınmayacaklar

- NOS / nitro (oyunda yok, yeni sistem eklenmeyecek).
- Tuning / dyno / parça yükseltme ekonomisi.
- Fusion parçaları, kademeli stage sistemi.
- Çok vitesli (8-10) hiper araçlar; bizim araçlar 5-6 vites.
- Gerçek araçların fabrika şanzıman tablolarını birebir kopyalamak — sınıfa göre türetilir.

## J) Mevcut sistemle farklar

| Konu | Eski (1.0) | Yeni (2.0) |
|---|---|---|
| RPM | `speed / gear_top[g]` → 0-1 normalize, gerçek devir yok | Gerçek devir (d/dk), `hız → tekerlek → oran → motor` |
| Vites kademesi | Geometrik sabit (her viteste ×0,72) | Araç başına **gerçek oran tablosu** + diferansiyel |
| Vites sonrası düşüş | Her araçta aynı oran | Oran farkının **fiziksel sonucu**, viteste ve araçta değişir |
| Vites kalitesi | 1,3 sn süren ivme çarpanı (0,84 / 1,14 / 0,80) | **Geçiş süresi** ve devrin nereye düştüğü; çarpan yok |
| Optimum devir | Tüm araçlarda %72-90 bandı | Araç başına oran farkından **hesaplanır** |
| Redline | rpm ≥ 1 → ivme ×0,15 | Limitçi: tork kesilir, devir sınırda tutulur, zaman kaybı |
| Kalkış | Yalnızca tepki süresi | Tepki + **launch RPM** (bog / optimum / wheelspin) |
| Patinaj | Yok (yalnızca statik `grip` çarpanı) | Çekiş limiti aşılınca gerçek patinaj, süre ve kayıp ölçülür |
| AI | Aynı modeli kullanıyordu ✔ | Aynı model, sınıfa göre hata payı |

## Kaynaklar

- CSR 2 Help Center — *How do I get the Perfect Shift?*
  <https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/5912-how-do-i-get-the-perfect-shift/>
- CSR 2 Help Center — *How do I get the perfect start?*
  <https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/13224-how-do-i-get-the-perfect-start/>
- Gamezebo — CSR Racing 2 Tips, Cheats and Strategies
  <https://www.gamezebo.com/walkthroughs/csr-racing-2-tips-cheats-and-strategies/>
- CSR2 Tuning Guide — Shift Patterns, Perfect Shifts & Dyno-Beating
  <https://csr2modding.com/blog/csr2-tuning-guide>
- Perfect Shift Pattern Guide <https://www.allclash.com/perfect-shift-pattern-guide/>
- Level Winner — CSR Racing 2 tips (launch/wheelspin)
  <https://www.levelwinner.com/csr-racing-2-tips-cheats-strategies-7-hints-need-know/>
- Wikipedia — *Power band* <https://en.wikipedia.org/wiki/Power_band>
- Wikipedia — *Close-ratio transmission* <https://en.wikipedia.org/wiki/Close-ratio_transmission>
- Wikipedia — *Short shifting* <https://en.wikipedia.org/wiki/Short_shifting>

## Model (uygulanacak)

```
tekerlek_devri = hız / (2π·r) · 60
motor_devri    = tekerlek_devri · diferansiyel · oran[vites]        (idle…redline arası kırpılır)
tork           = tork_eğrisi(motor_devri) · tepe_tork               (Nm)
tekerlek_kuvveti = tork · oran · diferansiyel · verim / r           (N)
direnç         = ½·ρ·Cd·A·v² + Crr·m·g
ivme           = (kuvvet − direnç) / kütle
```

Çekiş limiti: `kuvvet > μ·m·g` ise patinaj — fazlası boşa gider, motor devri hızdan ayrılır.

Vites geçişi: `shift_time` boyunca çekiş 0; sonrasında motor devri yeni oranla hesaplanır
(düşüş otomatik). Kalite yalnızca `shift_time`'ı ve devrin nereye düştüğünü belirler.

Optimum vites devri her vites için sayısal olarak çözülür: mevcut viteste tekerlek kuvveti,
bir üst viteste aynı hızdaki tekerlek kuvvetine **eşitlendiği** devir. Klasik sonuç: ideal
upshift noktası tepe torkun değil, oran farkının belirlediği noktadır.
