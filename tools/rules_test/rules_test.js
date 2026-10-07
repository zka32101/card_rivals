const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, deleteDoc, updateDoc, collection, getDocs } = require('firebase/firestore');
const fs = require('fs');

const RULES = process.env.RULES_PATH;
let pass = 0, fail = 0;
async function check(name, p) {
  try { await p; pass++; console.log('PASS', name); } catch (e) { fail++; console.log('FAIL', name, '-', String(e.message).slice(0, 90)); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-cr',
    firestore: { rules: fs.readFileSync(RULES, 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const anon = env.unauthenticatedContext().firestore();

  // seed (管理側)
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'events/e1'), { name: 'ev', endDate: new Date() });
    await setDoc(doc(db, 'events/e1/challenges/c1'), { difficulty: 1 });
    await setDoc(doc(db, 'users/alice/friends/bob'), { friendId: 'bob' });
    await setDoc(doc(db, 'users/alice/friendRequests/r1'), { senderId: 'bob', recipientId: 'alice' });
  });

  // ---- friends ----
  await check('alice reads own friends', assertSucceeds(getDocs(collection(alice, 'users/alice/friends'))));
  await check('alice writes own friend', assertSucceeds(setDoc(doc(alice, 'users/alice/friends/carol'), { friendId: 'carol' })));
  await check('bob cannot read alice friends', assertFails(getDocs(collection(bob, 'users/alice/friends'))));
  await check('bob reciprocal: users/alice/friends/bob (id=bob, friendId=bob)', assertSucceeds(setDoc(doc(bob, 'users/alice/friends/bob'), { friendId: 'bob', friendName: 'B' })));
  await check('bob cannot write users/alice/friends/carol (id != own uid)', assertFails(setDoc(doc(bob, 'users/alice/friends/carol'), { friendId: 'carol' })));
  await check('bob cannot forge friendId (id=bob, friendId=alice)', assertFails(setDoc(doc(bob, 'users/alice/friends/bob'), { friendId: 'alice' })));
  await check('bob cannot delete alice friend', assertFails(deleteDoc(doc(bob, 'users/alice/friends/bob'))));
  await check('anon cannot read friends', assertFails(getDocs(collection(anon, 'users/alice/friends'))));

  // ---- friendRequests ----
  await check('alice reads own requests', assertSucceeds(getDocs(collection(alice, 'users/alice/friendRequests'))));
  await check('bob cannot read alice requests', assertFails(getDocs(collection(bob, 'users/alice/friendRequests'))));
  await check('bob sends request to alice (senderId=bob, recipient=alice)', assertSucceeds(setDoc(doc(bob, 'users/alice/friendRequests/r2'), { senderId: 'bob', recipientId: 'alice', expiresAt: new Date() })));
  await check('bob cannot spoof sender (senderId=carol)', assertFails(setDoc(doc(bob, 'users/alice/friendRequests/r3'), { senderId: 'carol', recipientId: 'alice' })));
  await check('bob cannot wrongly address (recipient=carol into alice box)', assertFails(setDoc(doc(bob, 'users/alice/friendRequests/r4'), { senderId: 'bob', recipientId: 'carol' })));
  await check('alice deletes request', assertSucceeds(deleteDoc(doc(alice, 'users/alice/friendRequests/r1'))));
  await check('bob cannot delete alice request', assertFails(deleteDoc(doc(bob, 'users/alice/friendRequests/r2'))));

  // ---- eventProgress ----
  await check('alice writes own eventProgress', assertSucceeds(setDoc(doc(alice, 'users/alice/eventProgress/e1_c1'), { eventId: 'e1', progress: 1 })));
  await check('bob cannot read alice eventProgress', assertFails(getDoc(doc(bob, 'users/alice/eventProgress/e1_c1'))));

  // ---- events ----
  await check('alice reads events', assertSucceeds(getDocs(collection(alice, 'events'))));
  await check('alice reads challenges', assertSucceeds(getDocs(collection(alice, 'events/e1/challenges'))));
  await check('anon cannot read events', assertFails(getDocs(collection(anon, 'events'))));
  await check('alice cannot write event', assertFails(setDoc(doc(alice, 'events/e2'), { name: 'x' })));
  await check('alice cannot write challenge', assertFails(setDoc(doc(alice, 'events/e1/challenges/c2'), { difficulty: 9 })));

  // ---- 既存の規則が変わっていない（回帰） ----
  await check('regression: alice reads own wallet', assertSucceeds(getDoc(doc(alice, 'users/alice/wallet/main'))));
  await check('regression: bob cannot read alice wallet', assertFails(getDoc(doc(bob, 'users/alice/wallet/main'))));
  await check('regression: alice cannot write rentals', assertFails(setDoc(doc(alice, 'rentals/x'), { renterUid: 'alice' })));

  console.log(`\nRESULT pass=${pass} fail=${fail}`);
  await env.cleanup();
  process.exit(fail ? 1 : 0);
})();
