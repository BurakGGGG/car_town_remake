# CarTownRemake

Godot 4.7, GDScript (C# yok). 3D araba tamir/garaj oyunu.

## Yapı
- `Main.tscn` — ana sahne
- `assets/cars/` — araç modelleri (.glb) ve her biri için .tscn
- `build_grid.gd` — grid tabanlı yerleştirme
- `car_hitbox.gd` — araç parçası seçimi/çarpışma
- `garage_system.gd` — garaj mantığı
- UI kodları `ui/` klasörüne yazılacak

## Kurallar
- `.tscn` ve `.tres` dosyalarını elle düzenleme. Sahne değişikliği
  gerekiyorsa söyle, editörde ben yaparım.
- `.uid` dosyalarına dokunma.
- UI'ı Control node'ları ve container'larla kur, mutlak pozisyon kullanma.
- Statik tipleme zorunlu: `var hiz: float = 10.0`
- Node referansı: `@onready var x: Button = %ButtonAdi` (unique name),
  uzun `$Path/To/Node` yazma.
- Sinyalleri kodda `.connect()` ile bağla.
- Emin olmadığın API için godot-docs MCP'sinden doğrula, tahmin etme.
