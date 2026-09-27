class_name GameFeatures
## OYUN ÖZELLİKLERİNİN TEK AÇMA/KAPAMA NOKTASI.
##
## Bir özellik henüz oyuncuya açılmadığında kodu SİLİNMEZ; burada kapatılır. Böylece altyapı
## (veri, kayıt, test) çalışmaya devam eder, yalnızca oyuncunun eriştiği yollar kapanır.
## Kodun içine "if false" serpiştirmek yerine her yer bu bayrağı okur.

## BOYA ATÖLYESİ — maske, shader, sahiplik ve testler duruyor; oyuncu arayüzü kapalı.
## Kapalıyken: garajda BOYA plakası görünmez, boya panosu açılmaz ve HER araç (oyuncununki de,
## trafikteki NPC'ler de) kendi FABRİKA rengiyle çıkar. true yapıldığında sistem geri gelir.
const PAINT: bool = false
