// account_cleanup.js testi (internetsiz): sahte Firestore (düz yol → belge). Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { cleanupAccount } = require("../account_cleanup");

function fakeDb(paths) {
  const store = new Set(paths);
  const ref = (path) => ({ path, async delete() { store.delete(path); } });
  const docOf = (path) => ({ id: path.split("/").pop(), ref: ref(path) });
  const fields = { "codes/ABC234": { uid: "ali" }, "codes/XYZ789": { uid: "veli" }, "invites/TOKENTOKEN12": { uid: "ali" } };
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
  "users/ali/friends/f_veli", "users/ali/inbox/r_ayse", "users/ali/races/e_veli", "users/ali/gifts/p_veli_20000",
  // ali'nin başkalarına yazdıkları (eski arkadaş ayse dahil)
  "users/veli/friends/f_ali", "users/veli/races/e_ali", "users/veli/visits/v_ali", "users/veli/gifts/p_ali_20380",
  "users/ayse/outbox/o_ali", "users/ayse/visits/v_ali", "users/ayse/gifts/p_ali_20379", "users/ayse/inbox/r_ali",
  // başkalarının belgeleri: KALMALI
  "players/veli", "garages/g_veli", "codes/XYZ789", "users/veli/friends/f_ayse", "users/veli/gifts/p_ayse_20380",
  "users/veli/visits/v_alican", "users/veli/gifts/p_alican_20380", "reports/x_ali_veli", "reports/x_veli_ali",
];

test("silinen hesabın bütün belgeleri gider, başkalarınınkiler kalır", async () => {
  const db = fakeDb(WORLD);
  const result = await cleanupAccount({ db, uid: "ali" });
  const left = [...db.store].sort();
  assert.deepStrictEqual(left, [
    "codes/XYZ789", "garages/g_veli", "players/veli",
    "reports/x_ali_veli", "reports/x_veli_ali",   // şikâyetler 180 gün kalır (cleanup.js siler)
    "users/veli/friends/f_ayse", "users/veli/gifts/p_alican_20380", "users/veli/gifts/p_ayse_20380",
    "users/veli/visits/v_alican",   // "alican" "ali" ile başlıyor ama başka oyuncu
  ]);
  assert.deepStrictEqual(result, { owned: 2, authored: 8 });
});

test("UID biçimsizse (yol kırabilecek karakter) hiçbir şey silinmez", async () => {
  for (const uid of ["", "../players", "ali/x", "a b", null]) {
    const db = fakeDb(WORLD);
    assert.deepStrictEqual(await cleanupAccount({ db, uid }), { skipped: 1 });
    assert.strictEqual(db.store.size, WORLD.length);
  }
});
