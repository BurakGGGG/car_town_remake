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

console.log("== players (değişmedi) ==");
await check("sahibi kaydını yazar", assertSucceeds(setDoc(doc(alice, "players/alice"), { save_version: 10, save_json: "{}", updated_at: 1 })));
await check("başkası kaydı okuyamaz", assertFails(getDoc(doc(bob, "players/alice"))));

console.log("== garages ==");
await check("sahibi g_uid yazar", assertSucceeds(setDoc(doc(alice, "garages/g_alice"), garage())));
await check("çıplak uid kimliği reddedilir", assertFails(setDoc(doc(alice, "garages/alice"), garage())));
await check("başkasının garajına yazılamaz", assertFails(setDoc(doc(eve, "garages/g_alice"), garage())));
await check("giriş yapmış herkes okur", assertSucceeds(getDoc(doc(bob, "garages/g_alice"))));
await check("girişsiz okunamaz", assertFails(getDoc(doc(anon, "garages/g_alice"))));
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
await check("sahibi siler (hesap silme)", assertSucceeds(deleteDoc(doc(alice, "avatars/a_alice"))));

console.log("== reports ==");
const rep = (over = {}) => ({ target: "alice", reason: "photo", av: "img:0a1b2c3d", name: "Usta Ali", at: 1, ...over });
await check("eve alice'i şikâyet eder", assertSucceeds(setDoc(doc(eve, "reports/x_eve_alice"), rep())));
await check("aynı şikâyet yeniden yazılır (tek belge)", assertSucceeds(setDoc(doc(eve, "reports/x_eve_alice"), rep({ img: "QUJD", at: 2 }))));
await check("başkası adına şikâyet edilemez", assertFails(setDoc(doc(eve, "reports/x_bob_alice"), rep())));
await check("kimlik hedefle uyuşmazsa reddedilir", assertFails(setDoc(doc(eve, "reports/x_eve_bob"), rep())));
await check("kendini şikâyet edemez", assertFails(setDoc(doc(alice, "reports/x_alice_alice"), rep())));
await check("bilinmeyen neden reddedilir", assertFails(setDoc(doc(eve, "reports/x_eve_alice"), rep({ reason: "spam" }))));
await check("şikâyet okunamaz (yalnız konsol)", assertFails(getDoc(doc(eve, "reports/x_eve_alice"))));
await check("hedef de okuyamaz", assertFails(getDoc(doc(alice, "reports/x_eve_alice"))));
await check("şikâyet silinemez", assertFails(deleteDoc(doc(eve, "reports/x_eve_alice"))));
await check("girişsiz şikâyet edilemez", assertFails(setDoc(doc(anon, "reports/x_anon_alice"), rep())));

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
await check("sahibi siler", assertSucceeds(deleteDoc(doc(bob, "push/p_bob"))));
await check("bildirim sınırı (push_log) istemciye kapalı: yazılamaz", assertFails(setDoc(doc(bob, "push_log/l_alice_bob"), { at: 0 })));
await check("bildirim sınırı okunamaz", assertFails(getDoc(doc(alice, "push_log/l_alice_bob"))));

console.log("== başka yollar ==");
await check("bilinmeyen koleksiyon kapalı", assertFails(setDoc(doc(alice, "other/x"), { a: 1 })));
await check("users/{uid} kök belgesi kapalı", assertFails(setDoc(doc(alice, "users/alice"), { a: 1 })));

await env.cleanup();
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
