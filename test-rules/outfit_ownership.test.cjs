const { before, after, test } = require('node:test');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;
const ownerId = `outfit-owner-${randomUUID()}`;
const suggestion = {
  date: '2026-11-03',
  topId: 'navy-polo',
  bottomId: 'black-trousers',
  shoesId: 'white-sneakers',
  occasionId: 'school',
  reason: 'Clean pieces for school.',
  worn: false,
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fitcheck',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
  });
});

after(async () => { await env?.cleanup(); });

function outfit(db, date = suggestion.date) {
  return doc(db, `users/${ownerId}/outfits/${date}`);
}

test('only the owner can read, create, change, and delete an unworn outfit', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const other = env.authenticatedContext('outfit-other').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const reference = outfit(owner);

  await assertSucceeds(setDoc(reference, suggestion));
  await assertSucceeds(getDoc(reference));
  await assertSucceeds(updateDoc(reference, { topId: 'blue-shirt' }));
  await assertSucceeds(updateDoc(reference, { reason: 'x' }));
  for (const db of [other, guest]) {
    await assertFails(getDoc(outfit(db)));
    await assertFails(setDoc(outfit(db, '2026-11-04'), { ...suggestion, date: '2026-11-04' }));
    await assertFails(updateDoc(outfit(db), { reason: 'Changed by someone else.' }));
    await assertFails(deleteDoc(outfit(db)));
  }
  await assertSucceeds(deleteDoc(reference));
});

test('outfits require the exact schema, matching date key, and valid field values', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const reference = outfit(owner);
  const invalidRecords = [
    { ...suggestion, date: '2026-11-04' },
    { ...suggestion, topId: suggestion.bottomId },
    { ...suggestion, topId: suggestion.shoesId },
    { ...suggestion, bottomId: suggestion.shoesId },
    { ...suggestion, reason: '' },
    { ...suggestion, reason: 42 },
    { ...suggestion, reason: 'x'.repeat(501) },
    { ...suggestion, reason: 'First line\nSecond line' },
    { ...suggestion, reason: 'First line\rSecond line' },
    { ...suggestion, worn: 'false' },
    { ...suggestion, unrelated: true },
  ];
  for (const key of ['topId', 'bottomId', 'shoesId', 'occasionId']) {
    for (const value of ['', null, 42, '.', '..', 'nested/id', 'x'.repeat(1501)]) {
      invalidRecords.push({ ...suggestion, [key]: value });
    }
  }
  for (const key of Object.keys(suggestion)) {
    const missingField = { ...suggestion };
    delete missingField[key];
    invalidRecords.push(missingField);
  }
  for (const record of invalidRecords) {
    await assertFails(setDoc(reference, record));
  }
  for (const date of ['2026-1-03', '2026-11-3', 'not-a-date']) {
    await assertFails(setDoc(outfit(owner, date), { ...suggestion, date }));
  }
  await assertSucceeds(setDoc(reference, {
    ...suggestion,
    topId: 't'.repeat(1500),
    bottomId: 'b'.repeat(1500),
    shoesId: 's'.repeat(1500),
    occasionId: 'o'.repeat(1500),
    reason: 'x'.repeat(500),
  }));
  await assertSucceeds(deleteDoc(reference));
});

test('recording an outfit as worn prevents reverting, replacing, or deleting it', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const reference = outfit(owner);
  await assertSucceeds(setDoc(reference, suggestion));
  await assertSucceeds(updateDoc(reference, { worn: true }));
  await assertSucceeds(getDoc(reference));
  await assertFails(updateDoc(reference, { worn: false }));
  await assertFails(updateDoc(reference, { topId: 'another-top' }));
  await assertFails(updateDoc(reference, { bottomId: 'another-bottom' }));
  await assertFails(updateDoc(reference, { shoesId: 'another-pair' }));
  await assertFails(updateDoc(reference, { occasionId: 'work' }));
  await assertFails(updateDoc(reference, { reason: 'Another reason.' }));
  await assertFails(setDoc(reference, suggestion));
  await assertFails(deleteDoc(reference));
});
