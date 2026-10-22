// firestore.rules testi — YEREL EMÜLATÖRDE, gerçek projeye dokunmaz ("demo-" projesi ağa çıkmaz).
// Çalıştırma (firebase/ klasöründen):
//   cd rules_test && npm install   (ilk sefer)
//   firebase emulators:exec --only firestore --project demo-cartown "node rules_test/rules_test.mjs"
import { readFileSync } from "node:fs";
import { initializeTestEnvironment, assertSucceeds, assertFails } from "@firebase/rules-unit-testing";
import { doc, setDoc, getDoc, deleteDoc, getDocs, collection } from "firebase/firestore";

const env = await initializeTestEnvironment({
  projectId: "demo-cartown",
  firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
});

let fails = 0;
async function check(what, promise) {
  try {
    await promise;
    console.log("  OK   " + what);
  } catch (e) {
    fails++;
    console.log("  FAIL " + what + "\n       " + String(e).split("\n")[0]);
  }
}

const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());
const alice = db("alice"), bob = db("bob"), eve = db("eve"), anon = db(null);

const garage = (over = {}) => ({
  name: "Usta Ali", code: "ABC234", level: 5, value: 12000, garage_json: "{}", updated_at: 1, ...over,
});
const req = (over = {}) => ({ name: "Usta Ali", code: "ABC234", at: 1, ...over });

console.log("== players ==");
await check("sahibi kaydını yazar", assertSucceeds(setDoc(doc(alice, "players/alice"), { save_version: 10, save_json: "{}", updated_at: 1 })));
await check("başkası kaydı okuyamaz", assertFails(getDoc(doc(bob, "players/alice"))));
const stats = (over = {}) => ({ money: 5000, gems: 40, level: 3, cars: 2, build: 11, ...over });
const player = (over = {}) => ({ save_version: 10, save_json: "gz1:H4sI", stats: stats(), updated_at: 1, ...over });
await check("özetli (stats) kayıt yazılır", assertSucceeds(setDoc(doc(alice, "players/alice"), player())));
await check("stats'ta ek alan reddedilir", assertFails(setDoc(doc(alice, "players/alice"), player({ stats: stats({ admin: 1 }) }))));
await check("stats metin değer reddedilir", assertFails(setDoc(doc(alice, "players/alice"), player({ stats: stats({ gems: "9" }) }))));
await check("stats.lang (oyun dili) kabul", assertSucceeds(setDoc(doc(alice, "players/alice"), player({ stats: stats({ lang: "de" }) }))));
await check("bilinmeyen dil reddedilir", assertFails(setDoc(doc(alice, "players/alice"), player({ stats: stats({ lang: "xx" }) }))));
await check("60 KB kayıt kabul (eski 20 KB sınırı kalktı)", assertSucceeds(setDoc(doc(alice, "players/alice"), player({ save_json: "x".repeat(60000) }))));
await check("100 KB kayıt reddedilir", assertFails(setDoc(doc(alice, "players/alice"), player({ save_json: "x".repeat(100000) }))));

console.log("== garages ==");
await check("sahibi g_uid yazar", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), garage())));
await check("çıplak uid kimliği reddedilir", assertFails(setDoc(doc(alice, "garages/alice"), garage())));
await check("başkasının garajına yazılamaz", assertFails(setDoc(doc(eve, "garages/g_alice"), garage())));
await check("giriş yapmış herkes okur", assertSucceeds(getDoc(doc(bob, "garages/g_alice"))));
await check("girişsiz okunamaz", assertFails(getDoc(doc(anon, "garages/g_alice"))));
await check("garajlar listelenemez (toplu indirme yok)", assertFails(getDocs(collection(bob, "garages"))));
await check("ek alan (money) reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ money: 5 }))));
await check("Türkçe ad kabul", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), garage({ name: "Şahin Çağrı" }))));
await check("kısa ad reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ name: "Al" }))));
await check("uzun ad reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ name: "A".repeat(17) }))));
await check("geçersiz karakter reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ name: "<script>" }))));
await check("büyük garaj_json reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ garage_json: "x".repeat(20000) }))));
await check("hatalı kod reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ code: "abc234" }))));

console.log("== codes ==");
await check("kod alınır", assertSucceeds(setDoc(doc(alice, "codes/ABC234"), { uid: "alice" })));
await check("alınmış kod başkasınca ele geçirilemez", assertFails(setDoc(doc(eve, "codes/ABC234"), { uid: "eve" })));
await check("kendi kodunun üzerine de yazılamaz", assertFails(setDoc(doc(alice, "codes/ABC234"), { uid: "alice" })));
await check("başkası adına kod alınamaz", assertFails(setDoc(doc(eve, "codes/EVE234"), { uid: "alice" })));
await check("biçimsiz kod (O/0/I/1) reddedilir", assertFails(setDoc(doc(bob, "codes/BOB0I1"), { uid: "bob" })));
await check("bob kodunu alır", assertSucceeds(setDoc(doc(bob, "codes/BQB234"), { uid: "bob" })));
await check("kod okunur", assertSucceeds(getDoc(doc(bob, "codes/ABC234"))));
await check("kodlar listelenemez (kod → uid haritası çıkarılamaz)", assertFails(getDocs(collection(bob, "codes"))));
await check("başkasının kodu silinemez", assertFails(deleteDoc(doc(eve, "codes/ABC234"))));

console.log("== istek (alice → bob) ==");
await check("alice bob'a istek yazar", assertSucceeds(setDoc(doc(alice, "users/bob/inbox/r_alice"), req())));
await check("alice kendi giden kutusuna yazar", assertSucceeds(setDoc(doc(alice, "users/alice/outbox/o_bob"), req({ name: "Bob Usta", code: "BQB234" }))));
await check("eve alice adına istek yazamaz", assertFails(setDoc(doc(eve, "users/bob/inbox/r_alice"), req())));
await check("kendine istek atılamaz", assertFails(setDoc(doc(alice, "users/alice/inbox/r_alice"), req())));
await check("eve başkasının giden kutusuna yazamaz", assertFails(setDoc(doc(eve, "users/alice/outbox/o_eve"), req())));
await check("bob gelen kutusunu listeler", assertSucceeds(getDocs(collection(bob, "users/bob/inbox"))));
await check("eve bob'un gelen kutusunu listeleyemez", assertFails(getDocs(collection(eve, "users/bob/inbox"))));
await check("alice gönderdiği isteği okur", assertSucceeds(getDoc(doc(alice, "users/bob/inbox/r_alice"))));

console.log("== arkadaşlık kurma ==");
await check("eve istek olmadan kendini bob'a ekleyemez", assertFails(setDoc(doc(eve, "users/bob/friends/f_eve"), { since: 1 })));
await check("eve istek olmadan bob'u kendine ekleyemez", assertFails(setDoc(doc(eve, "users/eve/friends/f_bob"), { since: 1 })));
await check("alice (gönderen) kendisi kabul edemez", assertFails(setDoc(doc(alice, "users/alice/friends/f_bob"), { since: 1 })));
await check("alice bob'un listesine kendini yazamaz", assertFails(setDoc(doc(alice, "users/bob/friends/f_alice"), { since: 1 })));
await check("bob kabul: kendi listesine", assertSucceeds(setDoc(doc(bob, "users/bob/friends/f_alice"), { since: 1 })));
await check("bob kabul: alice'in listesine", assertSucceeds(setDoc(doc(bob, "users/alice/friends/f_bob"), { since: 1 })));
await check("bob başka birini alice'in listesine yazamaz", assertFails(setDoc(doc(bob, "users/alice/friends/f_eve"), { since: 1 })));
await check("ek alan reddedilir", assertFails(setDoc(doc(bob, "users/bob/friends/f_alice"), { since: 1, x: 1 })));
await check("bob isteği siler", assertSucceeds(deleteDoc(doc(bob, "users/bob/inbox/r_alice"))));
await check("bob alice'in giden kaydını siler", assertSucceeds(deleteDoc(doc(bob, "users/alice/outbox/o_bob"))));
await check("istek silindikten sonra yeniden yazılamaz", assertFails(setDoc(doc(bob, "users/bob/friends/f_alice"), { since: 2 })));
await check("alice arkadaş listesini okur", assertSucceeds(getDocs(collection(alice, "users/alice/friends"))));
await check("eve alice'in listesini okuyamaz", assertFails(getDocs(collection(eve, "users/alice/friends"))));

console.log("== arkadaşlıktan çıkarma ==");
await check("eve alice'in arkadaşını silemez", assertFails(deleteDoc(doc(eve, "users/alice/friends/f_bob"))));
await check("alice bob'u kendi listesinden siler", assertSucceeds(deleteDoc(doc(alice, "users/alice/friends/f_bob"))));
await check("alice kendini bob'un listesinden siler", assertSucceeds(deleteDoc(doc(alice, "users/bob/friends/f_alice"))));

console.log("== reddetme / iptal ==");
await check("eve bob'a istek yazar", assertSucceeds(setDoc(doc(eve, "users/bob/inbox/r_eve"), req({ name: "Eve", code: "EVE234" }))));
await check("eve isteğini geri çeker", assertSucceeds(deleteDoc(doc(eve, "users/bob/inbox/r_eve"))));
await check("alice başkasının isteğini silemez", assertSucceeds(setDoc(doc(eve, "users/bob/inbox/r_eve"), req({ name: "Eve", code: "EVE234" }))));
await check("  ...silme reddedilir", assertFails(deleteDoc(doc(alice, "users/bob/inbox/r_eve"))));

console.log("== hurdalık hediyesi ==");
const dayN = Math.floor(Date.now() / 86400000), day = String(dayN);
const gift = (over = {}) => ({ part: "bolt", name: "Bob Usta", at: 1, day: dayN, ...over });
await check("alice garajında parça ister", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), garage({ ask: { part: "bolt", at: 1 } }))));
await check("bilinmeyen parça istenemez", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ ask: { part: "money", at: 1 } }))));
await check("isteğe ek alan eklenemez", assertFails(setDoc(doc(alice, "garages/g_alice"), garage({ ask: { part: "bolt", at: 1, n: 99 } }))));
await check("arkadaş olmayan eve hediye gönderemez", assertFails(setDoc(doc(eve, "users/alice/gifts/p_eve_" + day), gift({ name: "Eve Usta" }))));
// alice ↔ bob yeniden arkadaş (yukarıda çıkarılmıştı)
await setDoc(doc(bob, "users/alice/inbox/r_bob"), req({ name: "Bob Usta", code: "BQB234" }));
await check("alice kabul: kendi listesi", assertSucceeds(setDoc(doc(alice, "users/alice/friends/f_bob"), { since: 2 })));
await check("alice kabul: bob'un listesi", assertSucceeds(setDoc(doc(alice, "users/bob/friends/f_alice"), { since: 2 })));
await check("istenmeyen parça gönderilemez", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift({ part: "piston" }))));
await check("başka günün kimliğiyle gönderilemez", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + (dayN - 1)), gift({ day: dayN - 1 }))));
await check("kimlik bugün, belgedeki gün eski: reddedilir", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift({ day: dayN - 1 }))));
await check("başkası adına gönderilemez", assertFails(setDoc(doc(bob, "users/alice/gifts/p_carol_" + day), gift())));
await check("ek alan (adet) reddedilir", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift({ n: 50 }))));
await check("arkadaş bob istenen parçayı gönderir", assertSucceeds(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift())));
await check("aynı gün ikinci hediye (üzerine yazma) reddedilir", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift({ at: 2 }))));
await check("kendine hediye gönderilemez", assertFails(setDoc(doc(alice, "users/alice/gifts/p_alice_" + day), gift({ name: "Usta Ali" }))));
await check("bob alice'in hediyelerini okuyamaz", assertFails(getDocs(collection(bob, "users/alice/gifts"))));
await check("alice hediyelerini okur", assertSucceeds(getDocs(collection(alice, "users/alice/gifts"))));
await check("bob gönderdiğini silemez", assertFails(deleteDoc(doc(bob, "users/alice/gifts/p_bob_" + day))));
await check("alice BUGÜNÜN hediyesini silemez (yeniden gönderim açılmasın)", assertFails(deleteDoc(doc(alice, "users/alice/gifts/p_bob_" + day))));
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), "users/alice/gifts/p_bob_" + (dayN - 2)), gift({ day: dayN - 2 }));
});
await check("alice eski hediyeyi temizler", assertSucceeds(deleteDoc(doc(alice, "users/alice/gifts/p_bob_" + (dayN - 2)))));
await check("hesap silme: garaj silinince", assertSucceeds(deleteDoc(doc(alice, "garages/g_alice"))));
await check("  ...bugünün hediyesi de silinir", assertSucceeds(deleteDoc(doc(alice, "users/alice/gifts/p_bob_" + day))));
await check("garajı olmayana hediye gönderilemez (istek yok)", assertFails(setDoc(doc(bob, "users/alice/gifts/p_bob_" + day), gift())));

console.log("== profil alanları (garages) ==");
const prof = (over = {}) => garage({ av: "img:0a1b2c3d", frame: "neon", flag: "TR", title: "Gece Garajı", car: "lambo_huracan",
  stats: { wins: 3, races: 5, cars: 12, best: 11234, best_car: "vw_golf_7" }, ...over });
await check("profilli garaj yazılır", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), prof())));
await check("hazır avatar (p07) kabul", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), prof({ av: "p07" }))));
await check("boş avatar / bayrak / ad kabul", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), prof({ av: "", flag: "", title: "" }))));
await check("avatar URL'si reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ av: "https://x.y/z.jpg" }))));
await check("büyük harfli hash reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ av: "img:0A1B2C3D" }))));
await check("üç harfli bayrak reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ flag: "TUR" }))));
await check("uzun garaj adı reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ title: "A".repeat(21) }))));
await check("garaj adında < reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ title: "<b>" }))));
await check("istatistiğe ek alan reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ stats: { wins: 1, races: 1, cars: 1, best: 1, best_car: "", gems: 9 } }))));
await check("sayı yerine metin reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"), prof({ stats: { wins: "1", races: 1, cars: 1, best: 1, best_car: "" } }))));

console.log("== avatars ==");
const av = (over = {}) => ({ img: "QUJD".repeat(100), hash: "0a1b2c3d", at: 1, ...over });
await check("sahibi a_uid yazar", assertSucceeds(setDoc(doc(alice, "avatars/a_alice"), av())));
await check("çıplak uid kimliği reddedilir", assertFails(setDoc(doc(alice, "avatars/alice"), av())));
await check("başkasının avatarına yazılamaz", assertFails(setDoc(doc(eve, "avatars/a_alice"), av())));
await check("giriş yapmış herkes okur", assertSucceeds(getDoc(doc(eve, "avatars/a_alice"))));
await check("girişsiz okunamaz", assertFails(getDoc(doc(anon, "avatars/a_alice"))));
await check("40000'den büyük resim reddedilir", assertFails(setDoc(doc(alice, "avatars/a_alice"), av({ img: "x".repeat(40001) }))));
await check("boş resim reddedilir", assertFails(setDoc(doc(alice, "avatars/a_alice"), av({ img: "" }))));
await check("ek alan (url) reddedilir", assertFails(setDoc(doc(alice, "avatars/a_alice"), av({ url: "http://x" }))));
await check("başkası silemez", assertFails(deleteDoc(doc(eve, "avatars/a_alice"))));
await check("başkası fotoğrafı kimlikle okur", assertSucceeds(getDoc(doc(bob, "avatars/a_alice"))));
await check("fotoğraflar listelenemez (toplu indirme yok)", assertFails(getDocs(collection(bob, "avatars"))));
await check("sahibi siler (hesap silme)", assertSucceeds(deleteDoc(doc(alice, "avatars/a_alice"))));

console.log("== reports ==");
const repAt = Math.floor(Date.now() / 1000);
const rep = (over = {}) => ({ target: "alice", reason: "photo", av: "img:0a1b2c3d", name: "Usta Ali", at: repAt, ...over });
await check("eve alice'i şikâyet eder", assertSucceeds(setDoc(doc(eve, "reports/x_eve_alice"), rep())));
await check("aynı şikâyet yeniden yazılır (tek belge)", assertSucceeds(setDoc(doc(eve, "reports/x_eve_alice"), rep({ img: "QUJD", at: repAt + 5 }))));
await check("başkası adına şikâyet edilemez", assertFails(setDoc(doc(eve, "reports/x_bob_alice"), rep())));
await check("kimlik hedefle uyuşmazsa reddedilir", assertFails(setDoc(doc(eve, "reports/x_eve_bob"), rep())));
await check("garajı olmayan (uydurma) hedef şikâyet edilemez", assertFails(setDoc(doc(eve, "reports/x_eve_zed"), rep({ target: "zed" }))));
await check("kendini şikâyet edemez", assertFails(setDoc(doc(alice, "reports/x_alice_alice"), rep())));
await check("bilinmeyen neden reddedilir", assertFails(setDoc(doc(eve, "reports/x_eve_alice"), rep({ reason: "spam" }))));
await check("şikâyet okunamaz (yalnız konsol)", assertFails(getDoc(doc(eve, "reports/x_eve_alice"))));
await check("hedef de okuyamaz", assertFails(getDoc(doc(alice, "reports/x_eve_alice"))));
await check("şikâyet silinemez", assertFails(deleteDoc(doc(eve, "reports/x_eve_alice"))));
await check("girişsiz şikâyet edilemez", assertFails(setDoc(doc(anon, "reports/x_anon_alice"), rep())));
await check("uzak gelecek tarihli şikâyet reddedilir (kuyruğun başına çakılmasın)", assertFails(setDoc(doc(eve, "reports/x_eve_alice"), rep({ at: 9e15 }))));
await check("çok eski tarihli şikâyet reddedilir", assertFails(setDoc(doc(eve, "reports/x_eve_alice"), rep({ at: 1 }))));

console.log("== yarış haberi (races) ==");
// alice ↔ bob arkadaş (yukarıda yeniden kuruldu); eve arkadaş değil
const ev = (over = {}) => ({ name: "Bob Usta", car: "seat_leon", paint: "1e90ff", build: { motor: 2, turbo: 1 },
  their_car: "vw_golf_7", won: true, revenge: false, mw: 3, ml: 1, at: 1, ...over });
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), "users/alice/friends/f_bob"), { since: 3 });
  await setDoc(doc(ctx.firestore(), "users/bob/friends/f_alice"), { since: 3 });
});
await check("arkadaş bob alice'e haber yazar", assertSucceeds(setDoc(doc(bob, "users/alice/races/e_bob"), ev())));
await check("bob haberin üzerine yazar (tek belge)", assertSucceeds(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ won: false, mw: 3, ml: 2, at: 2 }))));
await check("arkadaş olmayan eve yazamaz", assertFails(setDoc(doc(eve, "users/alice/races/e_eve"), ev({ name: "Eve Usta" }))));
await check("başkası adına yazılamaz", assertFails(setDoc(doc(bob, "users/alice/races/e_carol"), ev())));
await check("kendine haber yazılamaz", assertFails(setDoc(doc(alice, "users/alice/races/e_alice"), ev({ name: "Usta Ali" }))));
await check("kademe 6 reddedilir", assertFails(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ build: { motor: 6 } }))));
await check("bilinmeyen modifiye reddedilir", assertFails(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ build: { nitro: 1 } }))));
await check("eksi skor reddedilir", assertFails(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ mw: -1 }))));
await check("biçimsiz araç reddedilir", assertFails(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ car: "../x" }))));
await check("ek alan (money) reddedilir", assertFails(setDoc(doc(bob, "users/alice/races/e_bob"), ev({ money: 9 }))));
await check("alice haberlerini listeler", assertSucceeds(getDocs(collection(alice, "users/alice/races"))));
await check("bob alice'in haberlerini okuyamaz", assertFails(getDocs(collection(bob, "users/alice/races"))));
await check("eve silemez", assertFails(deleteDoc(doc(eve, "users/alice/races/e_bob"))));
await check("gönderen kendi haberini siler", assertSucceeds(deleteDoc(doc(bob, "users/alice/races/e_bob"))));
await setDoc(doc(bob, "users/alice/races/e_bob"), ev());
await check("alice haberi siler (İNTİKAM / tamam)", assertSucceeds(deleteDoc(doc(alice, "users/alice/races/e_bob"))));

console.log("== ziyaret + beğeni (visits) ==");
const visitDay = Math.floor(Date.now() / 86400000);
const vis = (over = {}) => ({ name: "Bob Usta", at: Math.floor(Date.now() / 1000), day: visitDay, liked: false, ...over });
await check("arkadaş bob alice'in garajını gezdi", assertSucceeds(setDoc(doc(bob, "users/alice/visits/v_bob"), vis())));
await check("bob beğenisini ekler (tek belge üzerine yazılır)", assertSucceeds(setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ liked: true }))));
await check("arkadaş olmayan eve yazamaz", assertFails(setDoc(doc(eve, "users/alice/visits/v_eve"), vis({ name: "Eve Usta" }))));
await check("başkası adına yazılamaz", assertFails(setDoc(doc(bob, "users/alice/visits/v_carol"), vis())));
await check("kendi garajına ziyaret yazılamaz", assertFails(setDoc(doc(alice, "users/alice/visits/v_alice"), vis({ name: "Usta Ali" }))));
await check("dünün günü reddedilir (beğeni sınırı)", assertFails(setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ day: visitDay - 1 }))));
await check("ek alan (likes) reddedilir", assertFails(setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ likes: 99 }))));
await check("liked bool olmalı", assertFails(setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ liked: 5 }))));
await check("biçimsiz ad reddedilir", assertFails(setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ name: "<b>x</b>" }))));
await check("alice ziyaretleri listeler", assertSucceeds(getDocs(collection(alice, "users/alice/visits"))));
await check("bob alice'in ziyaretlerini okuyamaz", assertFails(getDocs(collection(bob, "users/alice/visits"))));
await check("eve silemez", assertFails(deleteDoc(doc(eve, "users/alice/visits/v_bob"))));
await check("ziyaretçi kendi belgesini siler", assertSucceeds(deleteDoc(doc(bob, "users/alice/visits/v_bob"))));
await setDoc(doc(bob, "users/alice/visits/v_bob"), vis({ liked: true }));
await check("alice okuduğu ziyareti siler", assertSucceeds(deleteDoc(doc(alice, "users/alice/visits/v_bob"))));
await check("garajda toplam beğeni (likes) yazılır", assertSucceeds(setDoc(doc(alice, "garages/g_alice"),
  prof({ stats: { wins: 3, races: 5, cars: 12, best: 11234, best_car: "vw_golf_7", likes: 7 } }))));
await check("eksi beğeni reddedilir", assertFails(setDoc(doc(alice, "garages/g_alice"),
  prof({ stats: { wins: 3, races: 5, cars: 12, best: 11234, best_car: "vw_golf_7", likes: -1 } }))));

console.log("== arkadaş daveti (link) ==");
const carol = db("carol"), dave = db("dave");
const nowSec = () => Math.floor(Date.now() / 1000);
const inv = (over = {}) => ({ uid: "carol", name: "Carol Usta", code: "CAR234", at: nowSec(), ...over });
const fr = (over = {}) => ({ since: 1, inv: "ABCDEFGH2345", ...over });
await check("sahibi davet oluşturur", assertSucceeds(setDoc(doc(carol, "invites/ABCDEFGH2345"), inv())));
await check("başkası adına davet oluşturulamaz", assertFails(setDoc(doc(eve, "invites/EVEEVEEVE234"), inv())));
await check("biçimsiz jeton reddedilir", assertFails(setDoc(doc(carol, "invites/abc"), inv())));
await check("ileri tarihli davet (uzun ömür) reddedilir", assertFails(setDoc(doc(carol, "invites/ABCDEFGH2346"), inv({ at: nowSec() + 3600 }))));
await check("geri tarihli davet reddedilir", assertFails(setDoc(doc(carol, "invites/ABCDEFGH2347"), inv({ at: nowSec() - 3600 }))));
await check("ek alan reddedilir", assertFails(setDoc(doc(carol, "invites/ABCDEFGH2348"), inv({ x: 1 }))));
await check("davetin üzerine yazılamaz", assertFails(setDoc(doc(carol, "invites/ABCDEFGH2345"), inv())));
await check("giriş yapmış herkes jetonla okur", assertSucceeds(getDoc(doc(dave, "invites/ABCDEFGH2345"))));
await check("girişsiz okunamaz", assertFails(getDoc(doc(anon, "invites/ABCDEFGH2345"))));
await check("davetler listelenemez", assertFails(getDocs(collection(dave, "invites"))));
await check("dave davetle carol'ı kendi listesine ekler", assertSucceeds(setDoc(doc(dave, "users/dave/friends/f_carol"), fr())));
await check("dave davetle kendini carol'ın listesine ekler", assertSucceeds(setDoc(doc(dave, "users/carol/friends/f_dave"), fr())));
await check("davetle başkası carol'a eklenemez", assertFails(setDoc(doc(dave, "users/carol/friends/f_eve"), fr())));
await check("davetle üçüncü kişinin listesine yazılamaz", assertFails(setDoc(doc(dave, "users/eve/friends/f_dave"), fr())));
await check("davet başka bir oyuncu için kullanılamaz", assertFails(setDoc(doc(eve, "users/eve/friends/f_bob"), fr())));
await check("carol kendi davetiyle kendini ekleyemez", assertFails(setDoc(doc(carol, "users/carol/friends/f_carol"), fr())));
await check("biçimsiz inv reddedilir", assertFails(setDoc(doc(eve, "users/eve/friends/f_carol"), fr({ inv: "x" }))));
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), "invites/EXPEXPEXP234"), inv({ at: nowSec() - 3700 }));
});
await check("süresi dolan davetle eklenemez", assertFails(setDoc(doc(eve, "users/eve/friends/f_carol"), fr({ inv: "EXPEXPEXP234" }))));
await check("eve daveti silemez", assertFails(deleteDoc(doc(eve, "invites/ABCDEFGH2345"))));
await check("sahibi daveti siler", assertSucceeds(deleteDoc(doc(carol, "invites/ABCDEFGH2345"))));
await check("silinen davetle eklenemez", assertFails(setDoc(doc(eve, "users/eve/friends/f_carol"), fr())));
await check("eski istekli arkadaşlık yolu değişmedi (ek alansız)", assertFails(setDoc(doc(eve, "users/eve/friends/f_bob"), { since: 1 })));

console.log("== bildirim jetonu (push) ==");
const tok = (over = {}) => ({ token: "f".repeat(150), lang: "tr", at: 1, ...over });
await check("sahibi jetonunu yazar", assertSucceeds(setDoc(doc(bob, "push/p_bob"), tok())));
await check("başkasının jetonuna yazılamaz", assertFails(setDoc(doc(eve, "push/p_bob"), tok())));
await check("başkasının jetonu okunamaz", assertFails(getDoc(doc(eve, "push/p_bob"))));
await check("bilinmeyen dil reddedilir", assertFails(setDoc(doc(bob, "push/p_bob"), tok({ lang: "it" }))));
await check("Almanca kabul edilir", assertSucceeds(setDoc(doc(bob, "push/p_bob"), tok({ lang: "de" }))));
await check("Fransızca kabul edilir", assertSucceeds(setDoc(doc(bob, "push/p_bob"), tok({ lang: "fr" }))));
await check("kısa jeton reddedilir", assertFails(setDoc(doc(bob, "push/p_bob"), tok({ token: "abc" }))));
await check("ek alan reddedilir", assertFails(setDoc(doc(bob, "push/p_bob"), tok({ uid: "bob" }))));
await check("bildirim türleri (prefs) yazılır", assertSucceeds(setDoc(doc(bob, "push/p_bob"), tok({ prefs: { race: false, gift: true } }))));
await check("bilinmeyen tür reddedilir", assertFails(setDoc(doc(bob, "push/p_bob"), tok({ prefs: { spam: true } }))));
await check("tür değeri bool olmalı", assertFails(setDoc(doc(bob, "push/p_bob"), tok({ prefs: { gift: 1 } }))));
await check("sahibi siler", assertSucceeds(deleteDoc(doc(bob, "push/p_bob"))));
await check("bildirim sınırı (push_log) istemciye kapalı: yazılamaz", assertFails(setDoc(doc(bob, "push_log/l_alice_bob"), { at: 0 })));
await check("bildirim sınırı okunamaz", assertFails(getDoc(doc(alice, "push_log/l_alice_bob"))));

console.log("== kayıt geçmişi (history) ==");
const hist = (over = {}) => ({ save_json: "gz1:H4sI", stats: stats(), updated_at: 5, ...over });
await check("saat dilimi yazılır (h05)", assertSucceeds(setDoc(doc(alice, "players/alice/history/h05"), hist())));
await check("gün dilimi yazılır (d3)", assertSucceeds(setDoc(doc(alice, "players/alice/history/d3"), hist())));
await check("dilimin üzerine yazılır", assertSucceeds(setDoc(doc(alice, "players/alice/history/h05"), hist({ updated_at: 9 }))));
await check("geçersiz dilim (h24) reddedilir", assertFails(setDoc(doc(alice, "players/alice/history/h24"), hist())));
await check("geçersiz dilim (keyfi kimlik) reddedilir", assertFails(setDoc(doc(alice, "players/alice/history/x1"), hist())));
await check("başkasının geçmişine yazılamaz", assertFails(setDoc(doc(bob, "players/alice/history/h06"), hist())));
await check("ek alan reddedilir", assertFails(setDoc(doc(alice, "players/alice/history/h07"), hist({ gems: 999 }))));
await check("istemci geçmişi okuyamaz", assertFails(getDoc(doc(alice, "players/alice/history/h05"))));

console.log("== uzaktan ayar (config) ==");
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "config/app"), { min_code: 10, latest_code: 11 }));
await check("misafir (oturumsuz) okur", assertSucceeds(getDoc(doc(anon, "config/app"))));
await check("giriş yapmış okur", assertSucceeds(getDoc(doc(alice, "config/app"))));
await check("istemci yazamaz", assertFails(setDoc(doc(alice, "config/app"), { min_code: 0 })));
await check("misafir yazamaz", assertFails(setDoc(doc(anon, "config/app"), { min_code: 0 })));
await check("silinemez", assertFails(deleteDoc(doc(alice, "config/app"))));
await check("listelenemez", assertFails(getDocs(collection(anon, "config"))));

console.log("== posta kutusu (mail) ==");
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "users/alice/mail/m1"), { gems: 50, at: 1 }));
await check("sahibi listeler", assertSucceeds(getDocs(collection(alice, "users/alice/mail"))));
await check("başkası listeleyemez", assertFails(getDocs(collection(bob, "users/alice/mail"))));
await check("başkası okuyamaz", assertFails(getDoc(doc(bob, "users/alice/mail/m1"))));
await check("sahibi kendine hediye yazamaz", assertFails(setDoc(doc(alice, "users/alice/mail/m2"), { gems: 9999, at: 1 })));
await check("sahibi hediyeyi değiştiremez", assertFails(setDoc(doc(alice, "users/alice/mail/m1"), { gems: 9999, at: 1 })));
await check("başkası hediye yazamaz", assertFails(setDoc(doc(bob, "users/alice/mail/m3"), { gems: 1, at: 1 })));
await check("başkası silemez", assertFails(deleteDoc(doc(bob, "users/alice/mail/m1"))));
await check("sahibi alınca siler", assertSucceeds(deleteDoc(doc(alice, "users/alice/mail/m1"))));

console.log("== iade (refunds) ==");
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), "users/alice/refunds/r1"), { product: "gems_pack_1", quantity: 1, at: 1 }));
await check("sahibi iadeyi okur", assertSucceeds(getDocs(collection(alice, "users/alice/refunds"))));
await check("başkası iadeyi okuyamaz", assertFails(getDocs(collection(bob, "users/alice/refunds"))));
await check("sahibi iade yazamaz / değiştiremez", assertFails(setDoc(doc(alice, "users/alice/refunds/r1"), { product: "x", quantity: 0, at: 1 })));
await check("başkası iadeyi silemez", assertFails(deleteDoc(doc(bob, "users/alice/refunds/r1"))));
await check("sahibi uygulayınca siler", assertSucceeds(deleteDoc(doc(alice, "users/alice/refunds/r1"))));

console.log("== kupon kodu (redeem) ==");
const nowS = Math.floor(Date.now() / 1000);
await check("oyuncu kod denemesi yazar", assertSucceeds(setDoc(doc(alice, "users/alice/redeem/REELS50"), { at: nowS })));
await check("aynı kod ikinci kez yazılamaz", assertFails(setDoc(doc(alice, "users/alice/redeem/REELS50"), { at: nowS })));
await check("sonucu okur", assertSucceeds(getDoc(doc(alice, "users/alice/redeem/REELS50"))));
await check("başkası adına deneme yazılamaz", assertFails(setDoc(doc(bob, "users/alice/redeem/BOBCODE"), { at: nowS })));
await check("biçimsiz kod (küçük harf) reddedilir", assertFails(setDoc(doc(alice, "users/alice/redeem/reels50"), { at: nowS })));
await check("sonuç alanını istemci yazamaz", assertFails(setDoc(doc(alice, "users/alice/redeem/FAKEOK"), { at: nowS, status: "ok" })));
await check("geçmiş tarihli deneme reddedilir (saat sınırı atlatılamaz)", assertFails(setDoc(doc(alice, "users/alice/redeem/OLDTRY"), { at: nowS - 7200 })));
await check("kupon belgesi istemciye kapalı", assertFails(getDoc(doc(alice, "promo/REELS50"))));

console.log("== moderasyon / yasak ==");
const now = Math.floor(Date.now() / 1000);
const banDb = (id, ban) => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `moderation/m_${id}`), ban ? { ban } : {}));
const mallory = db("mallory"), trent = db("trent");
await check("kendi moderasyon belgesini okur (yoksa da)", assertSucceeds(getDoc(doc(mallory, "moderation/m_mallory"))));
await check("başkasınınkini okuyamaz", assertFails(getDoc(doc(bob, "moderation/m_mallory"))));
await check("istemci kendi belgesini yazamaz (yasağı kaldıramaz)", assertFails(setDoc(doc(mallory, "moderation/m_mallory"), {})));
await banDb("mallory", { kind: "social", reason: "name", until: now + 3600, at: now });
await check("sosyal yasak: açık garaj yazılamaz", assertFails(setDoc(doc(mallory, "garages/g_mallory"), garage({ code: "MLR234" }))));
await check("sosyal yasak: arkadaşlık isteği gönderilemez", assertFails(setDoc(doc(mallory, "users/bob/inbox/r_mallory"), req({ name: "Mallory", code: "MLR234" }))));
await check("sosyal yasak: kod alınamaz", assertFails(setDoc(doc(mallory, "codes/MLR234"), { uid: "mallory" })));
await check("sosyal yasak: fotoğraf yüklenemez", assertFails(setDoc(doc(mallory, "avatars/a_mallory"), { img: "x", hash: "0011aabb", at: 1 })));
await check("sosyal yasak: bulut kaydı YAZILIR (oynamaya devam)", assertSucceeds(setDoc(doc(mallory, "players/mallory"), { save_version: 10, save_json: "{}", updated_at: 1 })));
await check("sosyal yasak: bildirim jetonu yazılır", assertSucceeds(setDoc(doc(mallory, "push/p_mallory"), { token: "m".repeat(150), lang: "tr", at: 1 })));
await check("sosyal yasak: kendi garajını silebilir (temizlik)", assertSucceeds(deleteDoc(doc(mallory, "garages/g_mallory"))));
await check("yasaksız oyuncu etkilenmez", assertSucceeds(setDoc(doc(trent, "garages/g_trent"), garage({ code: "TRN234" }))));
await banDb("mallory", { kind: "full", reason: "cheat", until: 0, at: now });
await check("tam yasak (kalıcı): bulut kaydı yazılamaz", assertFails(setDoc(doc(mallory, "players/mallory"), { save_version: 10, save_json: "{}", updated_at: 2 })));
await check("tam yasak: bildirim jetonu yazılamaz", assertFails(setDoc(doc(mallory, "push/p_mallory"), { token: "m".repeat(150), lang: "tr", at: 2 })));
await check("tam yasak: sosyal de kapalı", assertFails(setDoc(doc(mallory, "garages/g_mallory"), garage({ code: "MLR234" }))));
await check("tam yasak: kendi kaydını okuyabilir", assertSucceeds(getDoc(doc(mallory, "players/mallory"))));
await check("tam yasak: yarış günlüğü yazılamaz", assertFails(setDoc(doc(mallory, `race_log/mallory_${Math.floor(Date.now() / 86400000)}`),
  { uid: "mallory", day: Math.floor(Date.now() / 86400000), events: "[]", n: 0, v: 1, at: 1 })));
await check("tam yasak: kayıt geçmişi yazılamaz", assertFails(setDoc(doc(mallory, "players/mallory/history/h01"), { save_json: "{}", updated_at: 1 })));
await banDb("mallory", { kind: "full", reason: "cheat", until: now - 60, at: now - 7200 });
await check("süresi dolan yasak: kayıt yine yazılır", assertSucceeds(setDoc(doc(mallory, "players/mallory"), { save_version: 10, save_json: "{}", updated_at: 3 })));
await check("süresi dolan yasak: garaj yine yazılır", assertSucceeds(setDoc(doc(mallory, "garages/g_mallory"), garage({ code: "MLR234" }))));
await banDb("mallory", null);
await check("yasak kaldırılınca (ban alanı yok) her şey açık", assertSucceeds(setDoc(doc(mallory, "users/bob/inbox/r_mallory"), req({ name: "Mallory", code: "MLR234" }))));

console.log("== yarış günlüğü (race_log) ==");
const logDay = Math.floor(Date.now() / 86400000);
const rlog = (over = {}) => ({ uid: "alice", day: logDay, events: "[]", n: 0, v: 1, at: nowS, ...over });
await check("sahibi bugünün günlüğünü yazar", assertSucceeds(setDoc(doc(alice, `race_log/alice_${logDay}`), rlog({ events: "[{}]", n: 1 }))));
await check("sahibi günlüğü günceller", assertSucceeds(setDoc(doc(alice, `race_log/alice_${logDay}`), rlog({ n: 2 }))));
await check("iki gün önceki (çevrimdışı birikmiş) günlük yazılır", assertSucceeds(setDoc(doc(alice, `race_log/alice_${logDay - 2}`), rlog({ day: logDay - 2 }))));
await check("üç gün önceki günlük reddedilir", assertFails(setDoc(doc(alice, `race_log/alice_${logDay - 3}`), rlog({ day: logDay - 3 }))));
await check("gelecek gün reddedilir", assertFails(setDoc(doc(alice, `race_log/alice_${logDay + 1}`), rlog({ day: logDay + 1 }))));
await check("başkası adına yazılamaz", assertFails(setDoc(doc(eve, `race_log/alice_${logDay}`), rlog())));
await check("kimlik ile gün uyuşmazsa reddedilir", assertFails(setDoc(doc(alice, `race_log/alice_${logDay - 1}`), rlog())));
await check("ek alan reddedilir", assertFails(setDoc(doc(alice, `race_log/alice_${logDay}`), rlog({ money: 1 }))));
await check("çok büyük günlük reddedilir", assertFails(setDoc(doc(alice, `race_log/alice_${logDay}`), rlog({ events: "x".repeat(100000) }))));
await check("sahibi bile okuyamaz", assertFails(getDoc(doc(alice, `race_log/alice_${logDay}`))));
await check("silinemez (hesap silinince sunucu siler)", assertFails(deleteDoc(doc(alice, `race_log/alice_${logDay}`))));
await check("öğrenme tablosu herkese okunur", assertSucceeds(getDoc(doc(anon, "config/race_learning"))));
await check("öğrenme tablosu yazılamaz", assertFails(setDoc(doc(alice, "config/race_learning"), { off: true })));

console.log("== başka yollar ==");
await check("bilinmeyen koleksiyon kapalı", assertFails(setDoc(doc(alice, "other/x"), { a: 1 })));
await check("users/{uid} kök belgesi kapalı", assertFails(setDoc(doc(alice, "users/alice"), { a: 1 })));

await env.cleanup();
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
