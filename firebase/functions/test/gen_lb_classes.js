// lb_classes.json üretici: vehicles/cars.json'daki edinilebilir her aracın katalog sınıfı ({araç: "D" | "C" | "B" | "A" | "S"}).
// lbRun bir koşunun sınıfının (cls) aracın sınıfıyla aynı olduğunu buna bakarak denetler (functions klasörü dağıtılırken oyunun
// katalog dosyaları gitmez). Araç kataloğu değişince: cd firebase/functions && npm run lb-classes (sonra functions'ı yeniden yayınla).
// test/leaderboard.test.js dosyanın katalogla aynı olduğunu sınar (eskimişse test düşer).
const { readFileSync, writeFileSync } = require("node:fs");
const path = require("node:path");

const CARS = path.join(__dirname, "../../../vehicles/cars.json");
const OUT = path.join(__dirname, "../lb_classes.json");

/** Kataloğun beklenen sınıf haritası (kimliğe göre sıralı; polis gibi edinilemeyen araçlar yok). */
function catalogClasses() {
  const cars = JSON.parse(readFileSync(CARS, "utf8")).cars || [];
  const out = {};
  for (const c of cars.filter((x) => x && x.id && x.obtainable !== false && x.class).sort((a, b) => (a.id < b.id ? -1 : 1))) {
    out[c.id] = String(c.class);
  }
  return out;
}

if (require.main === module) {
  const classes = catalogClasses();
  writeFileSync(OUT, JSON.stringify(classes, null, 2) + "\n");
  console.log(`lb_classes.json: ${Object.keys(classes).length} araç`);
}

module.exports = { catalogClasses, OUT };
