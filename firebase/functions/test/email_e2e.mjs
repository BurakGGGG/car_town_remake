// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): E-POSTA İLE GİRİŞ. Oyunun yaptığı gibi callable'lar düz HTTP ile
// çağrılır (CloudSaveManager: POST {data} → {result} / {error: {details: {reason}}}); emülatörde e-posta gitmez, ileti
// _e2e_mail koleksiyonuna yazılır (index.js). Jetonla Auth emülatörüne girilir; aynı e-postalı Google girişinin AYNI
// hesaba bağlandığı (öteki yolu silmeden) Auth emülatörünün signInWithIdp'siyle sınanır.
// firebase/ klasöründen: npm --prefix functions run email-e2e
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const PROJECT = "demo-cartown";
initializeApp({ projectId: PROJECT });
const db = getFirestore();
const auth = getAuth();
const FN = `http://127.0.0.1:5001/${PROJECT}/europe-west4`;
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };

async function call(name, data) {
  const res = await fetch(`${FN}/${name}`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ data }),
  });
  return { status: res.status, body: await res.json() };
}

async function lastCode(email) {
  const snap = await db.collection("_e2e_mail").where("to", "==", email).get();
  const mails = snap.docs.map((d) => d.data()).sort((a, b) => a.at - b.at);
  const m = mails.length ? mails[mails.length - 1].text.match(/\b(\d{6})\b/) : null;
  return { count: mails.length, code: m ? m[1] : "", mail: mails[mails.length - 1] };
}

/** signInWithCustomToken: yanıtta uid yok, kimlik jetonunun içinden okunur (sign_in_provider "custom" olmalı). */
async function signInWithToken(token) {
  const res = await fetch(`${AUTH}/accounts:signInWithCustomToken?key=fake`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token, returnSecureToken: true }),
  });
  const body = await res.json();
  if (!body.idToken) return body;
  const claims = JSON.parse(Buffer.from(body.idToken.split(".")[1], "base64url").toString());
  return { ...body, localId: claims.user_id, provider: claims.firebase && claims.firebase.sign_in_provider };
}

async function googleSignIn(email, sub) {
  const idToken = JSON.stringify({ sub, email, email_verified: true, name: "Veli" });
  const res = await fetch(`${AUTH}/accounts:signInWithIdp?key=fake`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ requestUri: "http://localhost", returnSecureToken: true,
      postBody: `providerId=google.com&id_token=${encodeURIComponent(idToken)}` }),
  });
  return res.json();
}

// 1) Yeni e-posta: kod gelir, doğru kodla yeni hesap açılır, jetonla girilir
const sent = await call("emailCodeSend", { email: "Yeni@Example.com", lang: "tr" });
check(sent.status === 200 && sent.body.result && sent.body.result.resend_after === 60, `kod gönderildi (${JSON.stringify(sent.body)})`);
const first = await lastCode("yeni@example.com");
check(first.count === 1 && first.code.length === 6, "e-posta küçük harfli adrese, 6 haneli kodla");
check(/giriş kodun/.test(first.mail.subject), "Türkçe konu");

const again = await call("emailCodeSend", { email: "yeni@example.com", lang: "tr" });
check(again.status === 429 && again.body.error.details.reason === "cooldown", `60 sn dolmadan ikinci kod yok (${again.status})`);

const wrong = await call("emailCodeVerify", { email: "yeni@example.com", code: first.code === "000000" ? "111111" : "000000" });
check(wrong.status === 400 && wrong.body.error.details.reason === "wrong_code" && wrong.body.error.details.attempts_left === 4,
  `yanlış kod: kalan hak 4 (${JSON.stringify(wrong.body.error)})`);

const ok = await call("emailCodeVerify", { email: "yeni@example.com", code: first.code });
check(ok.status === 200 && typeof ok.body.result.token === "string" && ok.body.result.created === true, "doğru kod: jeton + yeni hesap");
const session = await signInWithToken(ok.body.result.token);
check(typeof session.localId === "string" && session.localId.length > 0 && session.provider === "custom",
  `jetonla girildi (uid ${session.localId}, ${session.provider})`);
const created = await auth.getUser(session.localId);
check(created.email === "yeni@example.com" && created.emailVerified === true, "hesabın e-postası doğrulanmış");

const reuse = await call("emailCodeVerify", { email: "yeni@example.com", code: first.code });
check(reuse.status === 400 && reuse.body.error.details.reason === "no_code", "kod ikinci kez kullanılamaz");

// 2) Google hesabı olan e-posta: kodla AYNI UID'ye girilir
const google = await googleSignIn("veli@gmail.com", "google-veli");
check(typeof google.localId === "string", `Google hesabı açıldı (${google.localId})`);
await call("emailCodeSend", { email: "veli@gmail.com", lang: "en" });
const veli = await lastCode("veli@gmail.com");
check(/sign-in code/.test(veli.mail.subject), "İngilizce konu");
const veliOk = await call("emailCodeVerify", { email: "veli@gmail.com", code: veli.code });
const veliSession = await signInWithToken(veliOk.body.result.token);
check(veliOk.body.result.created === false && veliSession.localId === google.localId, "kodla Google hesabının UID'sine girildi");
const veliUser = await auth.getUser(google.localId);
check(veliUser.providerData.some((p) => p.providerId === "google.com"), "Google yolu hesapta duruyor");

// 3) Kodla açılan hesaba sonradan aynı e-postalı Google girişi: aynı UID, yeni hesap açılmaz
const later = await googleSignIn("yeni@example.com", "google-yeni");
check(later.localId === session.localId, `Google girişi kodla açılan hesaba bağlandı (${later.localId} = ${session.localId})`);
const laterUser = await auth.getUser(session.localId);
check(laterUser.providerData.some((p) => p.providerId === "google.com"), "hesaba Google yolu eklendi");
const all = await auth.listUsers();
check(all.users.length === 2, `toplam 2 hesap (${all.users.length})`);

// 4) Belgeler istemciye kapalı koleksiyonlarda, kod düz metin yok
const codes = await db.collection("email_codes").get();
check(codes.size === 2 && codes.docs.every((d) => !JSON.stringify(d.data()).includes(first.code) || first.code === ""),
  "email_codes: e-posta başına özet belge, kod düz metin değil");
const ips = await db.collection("email_ips").get();
check(ips.size >= 1, "email_ips: adres sınırı kaydı");

const bad = await call("emailCodeSend", { email: "bozuk", lang: "tr" });
check(bad.status === 400 && bad.body.error.details.reason === "bad_email", "bozuk e-posta reddedilir");

console.log(fails ? `FAIL: ${fails}` : "TÜMÜ OK");
process.exit(fails ? 1 : 0);
