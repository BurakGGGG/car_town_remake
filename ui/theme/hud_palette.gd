class_name HudPalette
## HUD renk paleti — "yol mobilyası / plaka" dili.
## Dünya renkleri sahnedeki materyallerden: çim #83B24F, asfalt #444444,
## kaldırım #E2D1AB, showroom camı #88E3FF. UI bu dördünün üstüne az miktarda
## amber, açık mavi ve beyaz ekler; koyu panel yok.

# Dünya
const GRASS: Color = Color("83B24F")
const ASPHALT: Color = Color("444444")
const SIDEWALK: Color = Color("E2D1AB")
const GLASS: Color = Color("88E3FF")

# Plaka (kaldırım kremi, biraz açık) ve kalınlık kenarı
const PLATE: Color = Color("F3E8CF")
const PLATE_HOVER: Color = Color("FAF2E0")
const PLATE_EDGE: Color = Color("B9A67C")
# Seçili plaka: amber (sarı plaka)
const PLATE_SELECTED: Color = Color("F5BE4C")
const PLATE_SELECTED_HOVER: Color = Color("F8C862")
const PLATE_SELECTED_EDGE: Color = Color("B27A1C")

# Plaka yazısı / ikon mürekkebi (asfalt koyusu)
const INK: Color = Color("2F3236")
const INK_SOFT: Color = Color("5A5E64")

# Yuvarlak tabela butonları
const SIGN: Color = Color("FFFFFF")
const SIGN_ACTIVE: Color = Color("7FD3F5")
const SIGN_ACTIVE_EDGE: Color = Color("3D9FC7")

# XP: yoldaki şerit çizgisi gibi boyanır
const LANE_TRACK: Color = Color("3A3D41")
const LANE_PAINT: Color = Color("F5BE4C")
const LANE_FADED: Color = Color(1.0, 1.0, 1.0, 0.28)

# Dünya üstüne doğrudan yazılan konturlu metin
const TEXT_LIGHT: Color = Color("FFF6E5")  # sıcak beyaz
const TEXT_OUTLINE: Color = Color("2F3236", 0.9)

# Para birimleri
const COIN: Color = Color("F5BE4C")
const COIN_DARK: Color = Color("B27A1C")
const GEM: Color = Color("7FD3F5")
const GEM_LIGHT: Color = Color("D2F3FF")
const GEM_DARK: Color = Color("3D9FC7")

# Geri alınamaz işlemler (hesap silme)
const DANGER: Color = Color("B3412E")
const DANGER_DARK: Color = Color("8A2E20")

const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.25)
