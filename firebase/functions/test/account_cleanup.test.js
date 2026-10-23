// account_cleanup.js testi (internetsiz): sahte Firestore (düz yol → belge). Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { cleanupAccount } = require("../account_cleanup");

function fakeDb(paths) {
  const store = new Set(paths);
  const ref = (path) => ({ path, async delete() { store.delete(path); } });
  const docOf = (path) => ({ id: path.split("/").pop(), ref: ref(path) });
  const fields = { "codes/ABC234": { uid: "ali" }, "codes/XYZ789": { uid: "veli" }, "invites/TOKENTOKEN12": { uid: "ali" },
    "race_log/ali_20383": { uid: "ali" }, "race_log/veli_20383": { uid: "veli" },
    "iap/t_ali": { uid: "ali" }, "iap/t_veli": { uid: "veli" }, "iap/t_misafir": { uid: "" } };
  return {
    store,
    doc: ref,
    collection: (name) => ({
      where: (field, op, value) => ({
        async get() {
          const docs = [...store].filter((p) => p.split("/").length === 2 && p.startsWith(name + "/")
            && (fields[p] || {})[field] === value).map(docOf);
          return { docs };
        },
      }),
    }),
    collectionGroup: (group) => ({
      select: () => ({
        async get() {
          return { docs: [...store].filter((p) => p.split("/").slice(-2, -1)[0] === group).map(docOf) };
        },
      }),
    }),
    async recursiveDelete(r) {
      for (const p of [...store]) if (p.startsWith(r.path + "/")) store.delete(p);
    },
  };
}

const WORLD = [
  // ali'nin kendi belgeleri
  "players/ali", "garages/g_ali", "avatars/a_ali", "push/p_ali", "codes/ABC234", "invites/TOKENTOKEN12",
  "moderation/m_ali", "admin_notes/n_ali", "users/ali/mail/m_x", "players/ali/history/h05", "players/ali/history/d2",
  "promo/REELS50/used/ali", "users/ali/redeem/REELS50", "race_log/ali_20383", "iap/t_ali",
  "users/ali/friends/f_veli", "users/ali/inbox/r_ayse", "users/ali/races/e_veli", "users/ali/gifts/p_veli_20000",
  "users/ali/referral/ref_claim", "referrals/r_ali", "referrals/r_ali/invited/f_ayse",
  // ali'nin başkalarına yazdıkları (eski arkadaş ayse dahil)
  "users/veli/friends/f_ali", "users/veli/races/e_ali", "users/veli/visits/v_ali", "users/veli/gifts/p_ali_20380",
  "users/ayse/outbox/o_ali", "users/ayse/visits/v_ali", "users/ayse/gifts/p_ali_20379", "users/ayse/inbox/r_ali",
  "referrals/r_veli/invited/f_ali",   // ali'yi veli davet etmişti
  // başkalarının belgeleri: KALMALI
  "players/veli", "garages/g_veli", "codes/XYZ789", "users/veli/friends/f_ayse", "users/veli/gifts/p_ayse_20380",
  "users/veli/visits/v_alican", "users/veli/gifts/p_alican_20380", "reports/x_ali_veli", "reports/x_veli_ali",
  "moderation/m_veli", "admin_notes/n_veli", "players/veli/history/h01", "promo/REELS50/used/veli", "race_log/veli_20383",
  "iap/t_veli", "iap/t_misafir", "referrals/r_veli", "referrals/r_veli/invited/f_alican", `ref_devices/${"a".repeat(64)}`,
];

test("silinen hesabın bütün belgeleri gider, başkalarınınkiler kalır", async () => {
  const db = fakeDb(WORLD);
  const result = await cleanupAccount({ db, uid: "ali" });
  const left = [...db.store].sort();
  assert.deepStrictEqual(left, [
    "admin_notes/n_veli", "codes/XYZ789", "garages/g_veli", "iap/t_misafir", "iap/t_veli", "moderation/m_veli", "players/veli", "players/veli/history/h01", "promo/REELS50/used/veli",
    "race_log/veli_20383", "ref_devices/" + "a".repeat(64),   // cihaz özeti kalır (UID yok)
    "referrals/r_veli", "referrals/r_veli/invited/f_alican",   // davet edenin sayacı kalır
    "reports/x_ali_veli", "reports/x_veli_ali",   // şikâyetler 180 gün kalır (cleanup.js siler)
    "users/veli/friends/f_ayse", "users/veli/gifts/p_alican_20380", "users/veli/gifts/p_ayse_20380",
    "users/veli/visits/v_alican",   // "alican" "ali" ile başlıyor ama başka oyuncu
  ]);
  assert.deepStrictEqual(result, { owned: 4, authored: 10 });   // kod + davet + yarış günlüğü + satın alma doğrulaması
});

test("UID biçimsizse (yol kırabilecek karakter) hiçbir şey silinmez", async () => {
  for (const uid of ["", "../players", "ali/x", "a b", null]) {
    const db = fakeDb(WORLD);
    assert.deepStrictEqual(await cleanupAccount({ db, uid }), { skipped: 1 });
    assert.strictEqual(db.store.size, WORLD.length);
  }
});
