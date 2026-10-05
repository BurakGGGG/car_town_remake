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

console.log("== başka yollar ==");
await check("bilinmeyen koleksiyon kapalı", assertFails(setDoc(doc(alice, "other/x"), { a: 1 })));
await check("users/{uid} kök belgesi kapalı", assertFails(setDoc(doc(alice, "users/alice"), { a: 1 })));

await env.cleanup();
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
