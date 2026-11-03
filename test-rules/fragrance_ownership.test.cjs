const { before, after, test } = require('node:test');
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc,
} = require('firebase/firestore');

let env;
const ownerId = `fragrance-owner-${randomUUID()}`;
const fragrance = {
  name: 'Citrus cologne',
  scentNotes: 'Lemon and cedar',
  temperatureBand: 'warm',
  humidityBand: 'humid',
  photoUrl: null,
};
const location = {
  id: 1701697,
  name: 'Miagao',
  latitude: 10.6442,
  longitude: 122.2352,
  country: 'Philippines',
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fitcheck',
    firestore: {
      host: '127.0.0.1', port: 8080,
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
    storage: {
      host: '127.0.0.1', port: 9199,
      rules: fs.readFileSync('storage.rules', 'utf8'),
    },
  });
});

after(async () => { await env?.cleanup(); });

function userDocument(db, path) {
  return doc(db, `users/${ownerId}/${path}`);
}

test('fragrance collection CRUD is isolated to its owner', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const other = env.authenticatedContext('fragrance-other').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const reference = userDocument(owner, 'fragrances/crud');
  await assertSucceeds(setDoc(reference, fragrance));
  await assertSucceeds(getDoc(reference));
  await assertSucceeds(getDocs(collection(owner, `users/${ownerId}/fragrances`)));
  await assertSucceeds(updateDoc(reference, { humidityBand: 'dry' }));
  for (const db of [other, guest]) {
    await assertFails(getDoc(userDocument(db, 'fragrances/crud')));
    await assertFails(getDocs(collection(db, `users/${ownerId}/fragrances`)));
    await assertFails(setDoc(userDocument(db, 'fragrances/intruder'), fragrance));
    await assertFails(updateDoc(userDocument(db, 'fragrances/crud'), { name: 'Changed' }));
    await assertFails(deleteDoc(userDocument(db, 'fragrances/crud')));
  }
  await assertSucceeds(deleteDoc(reference));
});

test('fragrances require exact fields, valid weather bands, and bounded text', async () => {
  const db = env.authenticatedContext(ownerId).firestore();
  const reference = userDocument(db, 'fragrances/schema');
  const invalid = [
    { ...fragrance, name: '' },
    { ...fragrance, name: 'x'.repeat(121) },
    { ...fragrance, name: 42 },
    { ...fragrance, scentNotes: 'x'.repeat(501) },
    { ...fragrance, scentNotes: [] },
    { ...fragrance, temperatureBand: 'hot' },
    { ...fragrance, humidityBand: 'wet' },
    { ...fragrance, photoUrl: 42 },
    { ...fragrance, photoUrl: 'javascript:alert(1)' },
    { ...fragrance, extra: true },
  ];
  for (const key of Object.keys(fragrance)) {
    const missing = { ...fragrance };
    delete missing[key];
    invalid.push(missing);
  }
  for (const data of invalid) await assertFails(setDoc(reference, data));
  await assertSucceeds(setDoc(reference, {
    ...fragrance, name: 'x'.repeat(120), scentNotes: 'x'.repeat(500),
    temperatureBand: 'cool', humidityBand: 'balanced',
    photoUrl: 'https://example.test/photo.png',
  }));
  await assertSucceeds(updateDoc(reference, {
    scentNotes: null, photoUrl: null, temperatureBand: 'mild',
  }));
});

test('selected weather location is private and accepts only its city schema', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const reference = userDocument(owner, 'settings/weather');
  await assertSucceeds(setDoc(reference, location));
  await assertSucceeds(getDoc(reference));
  for (const context of [env.authenticatedContext('fragrance-other'), env.unauthenticatedContext()]) {
    const db = context.firestore();
    await assertFails(getDoc(userDocument(db, 'settings/weather')));
    await assertFails(setDoc(userDocument(db, 'settings/weather'), location));
    await assertFails(deleteDoc(userDocument(db, 'settings/weather')));
  }
  const invalid = [
    { ...location, id: '1701697' }, { ...location, id: 0 },
    { ...location, name: '' }, { ...location, name: 'x'.repeat(201) },
    { ...location, latitude: -90.01 }, { ...location, latitude: 90.01 },
    { ...location, latitude: Number.NaN },
    { ...location, longitude: -180.01 }, { ...location, longitude: 180.01 },
    { ...location, longitude: Number.POSITIVE_INFINITY },
    { ...location, country: 42 }, { ...location, country: '' },
    { ...location, streetAddress: 'Unrelated personal information' },
  ];
  for (const key of ['id', 'name', 'latitude', 'longitude']) {
    const missing = { ...location };
    delete missing[key];
    invalid.push(missing);
  }
  for (const data of invalid) await assertFails(setDoc(reference, data));
  const noCountry = { ...location };
  delete noCountry.country;
  await assertSucceeds(setDoc(reference, noCountry));
  await assertSucceeds(setDoc(reference, { ...noCountry, country: null }));
  await assertFails(setDoc(userDocument(owner, 'settings/arbitrary'), location));
  await assertSucceeds(deleteDoc(reference));
});

test('daily fragrance picks match their date and reference an owned fragrance', async () => {
  const owner = env.authenticatedContext(ownerId).firestore();
  const other = env.authenticatedContext('fragrance-other').firestore();
  const reference = userDocument(owner, 'fragrancePicks/2026-11-03');
  const pick = { date: '2026-11-03', fragranceId: 'selected' };
  await assertFails(setDoc(reference, pick));
  await assertSucceeds(setDoc(userDocument(owner, 'fragrances/selected'), fragrance));
  await assertSucceeds(setDoc(userDocument(owner, 'fragrances/alternate'), fragrance));
  await assertSucceeds(setDoc(reference, pick));
  await assertSucceeds(getDoc(reference));
  await assertSucceeds(updateDoc(reference, { fragranceId: 'alternate' }));
  for (const db of [other, env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(userDocument(db, 'fragrancePicks/2026-11-03')));
    await assertFails(setDoc(userDocument(db, 'fragrancePicks/2026-11-03'), pick));
    await assertFails(deleteDoc(userDocument(db, 'fragrancePicks/2026-11-03')));
  }
  for (const invalid of [
    { ...pick, date: '2026-11-04' }, { ...pick, fragranceId: '' },
    { ...pick, fragranceId: 'other/id' }, { ...pick, fragranceId: 'missing' },
    { ...pick, fragranceId: 42 }, { ...pick, extra: true },
    { date: pick.date }, { fragranceId: pick.fragranceId },
  ]) await assertFails(setDoc(reference, invalid));
  await assertFails(setDoc(userDocument(owner, 'fragrancePicks/not-a-date'), {
    ...pick, date: 'not-a-date',
  }));
  await assertSucceeds(deleteDoc(reference));
});

test('fragrance photos require owner access, supported images, and at most 5 MB', async () => {
  const owner = env.authenticatedContext(ownerId).storage('demo-fitcheck.appspot.com');
  const other = env.authenticatedContext('fragrance-other').storage('demo-fitcheck.appspot.com');
  const guest = env.unauthenticatedContext().storage('demo-fitcheck.appspot.com');
  const path = `users/${ownerId}/fragrances/selected/photos/test-upload`;
  const reference = owner.ref(path);
  for (const contentType of ['image/jpeg', 'image/png', 'image/webp']) {
    await assertSucceeds(reference.put(new Uint8Array([1, 2, 3]), { contentType }));
  }
  await assertSucceeds(reference.getMetadata());
  for (const storage of [other, guest]) {
    await assertFails(storage.ref(path).getMetadata());
    await assertFails(storage.ref(path).put(new Uint8Array([1]), { contentType: 'image/png' }));
    await assertFails(storage.ref(path).delete());
  }
  await assertFails(reference.put(new Uint8Array([1]), { contentType: 'text/html' }));
  await assertFails(reference.put(new Uint8Array(), { contentType: 'image/png' }));
  await assertSucceeds(reference.put(new Uint8Array(5 * 1024 * 1024), { contentType: 'image/png' }));
  await assertFails(reference.put(new Uint8Array(5 * 1024 * 1024 + 1), { contentType: 'image/png' }));
  await assertSucceeds(reference.delete());
});
