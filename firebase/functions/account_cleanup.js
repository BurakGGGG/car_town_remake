// HESAP SİLİNİNCE SUNUCU TEMİZLİĞİ — saf mantık (index.js Firebase Auth "kullanıcı silindi" tetikleyicisine bağlar;
// test/account_cleanup.test.js sahte db ile, test/account_e2e.mjs emülatörde sınar).
//
// Auth kullanıcısı hangi yolla silinirse silinsin (oyunda HESABIMI SİL, Firebase konsolu, sitedeki silme talebi) o UID'ye
// ait her belge yönetici yetkisiyle silinir. Oyun aynı silmeyi önce kendisi yapar (SocialManager.delete_all + players);
// bu fonksiyon yedek ağdır ve oyunun YAPAMADIKLARINI da siler:
//   - arkadaşlara gönderilen hediyeler users/{x}/gifts/p_{uid}_{gün} (kural yalnız alıcıya sildirir; içinde gönderenin adı var)
//   - artık arkadaş olmayanlara yazılmış ziyaret / yarış haberi / istek
//   - hesap oyun dışından silindiyse her şey
// Bilerek KALANLAR (gizlilik metnindeki süreleriyle cleanup.js siler): reports (180 gün, kötüye kullanım incelemesi),
// email_codes / email_ips (1 saat, özet), push_log (1 gün). ref_devices/{cihaz özeti} süresiz kalır: içinde UID yok,
// aynı telefonun hesap silip yeniden açarak ikinci kez davetle gelmesini önler (referral.js).
//
// Başkalarının alt koleksiyonlarındaki belgeler kimlikten tanınır (alanlarında UID yok): ilgili koleksiyon grupları
// yalnızca belge referansıyla (select()) taranır. Okuma sayısı o gruplardaki belge sayısı kadardır; silme seyrek olduğu
// için şimdilik yeterli, oyuncu sayısı çok büyürse belgeye yazan UID alanı eklenip sorguya çevrilmeli.

// Firebase'in ürettiği UID'ler harf + rakamdır. Başka bir şeyse (ör. "/" içeren) yola girmesin: hiçbir şey silinmez.
const UID_RE = /^[A-Za-z0-9]{1,128}$/;

/** UID'nin kendi kökteki belgeleri. moderation / admin_notes: yönetim panelinin kararı ve notu (2026-10-21) — silinen
 *  hesaba ait kişisel veri kalmasın; yasak yeni hesaba zaten geçmez (yeni UID). */
const OWN_DOCS = (uid) => [`players/${uid}`, `garages/g_${uid}`, `avatars/a_${uid}`, `push/p_${uid}`,
  `moderation/m_${uid}`, `admin_notes/n_${uid}`, `referrals/r_${uid}`];

/** `uid` alanıyla bulunan belgeler (arkadaş kodu, davet linki, yarış günlüğü — 2026-10-22). iap: satın alma doğrulama kaydı
 *  (iap.js). lb_runs: haftalık drag tablosu koşuları (2026-10-26) — her silme lbRun'ı tetikler: oyuncu özetlerden (lb/…, ad ve
 *  avatar dahil) ve sunucu defterinden (lb_counted) düşer. */
const OWNED_BY_FIELD = ["codes", "invites", "race_log", "iap", "lb_runs"];

/** Başkalarının users/{x}/<grup> altına bu UID'nin yazdığı belgeler: grup → kimlik eşleşmesi. */
const AUTHORED = [
  { group: "friends", matches: (id, uid) => id === `f_${uid}` },
  { group: "inbox", matches: (id, uid) => id === `r_${uid}` },
  { group: "outbox", matches: (id, uid) => id === `o_${uid}` },
  { group: "races", matches: (id, uid) => id === `e_${uid}` },
  { group: "visits", matches: (id, uid) => id === `v_${uid}` },
  { group: "gifts", matches: (id, uid) => id.startsWith(`p_${uid}_`) },
  { group: "used", matches: (id, uid) => id === uid },   // kupon kullanımı promo/{KOD}/used/{uid} (sayaç kalır)
  // davet edenin listesindeki satır referrals/r_{x}/invited/f_{uid} (davet edenin sayacı ve aldığı ödül kalır)
  { group: "invited", matches: (id, uid) => id === `f_${uid}` },
  // "arkadaşın seni geçti" haberi users/{x}/lbnews/{hafta}_{sınıf}_{uid} (sunucu yazar; içinde bu oyuncunun adı var)
  { group: "lbnews", matches: (id, uid) => new RegExp(`^[0-9]{1,6}_[DCBAS]_${uid}$`).test(id) },
];

/**
 * UID'nin bütün verisini siler. db: Firestore (yönetici) benzeri {doc(yol) → {delete()}, collection(ad).where(alan, "==", d).get(),
 * collectionGroup(ad).select().get() → {docs: [{id, ref: {path, delete()}}]}, recursiveDelete(ref)}.
 * Dönüş: {owned: kod + davet, authored: başkalarının listesindeki belge} sayıları (günlüğe yalnızca sayılar yazılır, UID yazılmaz).
 */
async function cleanupAccount({ db, uid }) {
  if (!UID_RE.test(String(uid || ""))) return { skipped: 1 };
  const deleted = { owned: 0, authored: 0 };
  for (const path of OWN_DOCS(uid)) {
    await db.doc(path).delete();   // yoksa sorun değil (oyun büyük olasılıkla önce sildi)
  }
  for (const collection of OWNED_BY_FIELD) {
    const snap = await db.collection(collection).where("uid", "==", uid).get();
    for (const doc of snap.docs) await doc.ref.delete();
    deleted.owned += snap.docs.length;
  }
  await db.recursiveDelete(db.doc(`users/${uid}`));   // kendi arkadaş / istek / haber / ziyaret / hediye / posta listeleri
  await db.recursiveDelete(db.doc(`players/${uid}`));   // kayıt geçmişi (players/{uid}/history, 2026-10-21)
  await db.recursiveDelete(db.doc(`referrals/r_${uid}`));   // davet ettiklerinin listesi (referral.js)
  const ownPrefix = `users/${uid}/`;
  for (const { group, matches } of AUTHORED) {
    const snap = await db.collectionGroup(group).select().get();
    for (const doc of snap.docs) {
      if (matches(doc.id, uid) && !doc.ref.path.startsWith(ownPrefix)) {
        await doc.ref.delete();
        deleted.authored++;
      }
    }
  }
  return deleted;
}

module.exports = { UID_RE, OWN_DOCS, OWNED_BY_FIELD, AUTHORED, cleanupAccount };
