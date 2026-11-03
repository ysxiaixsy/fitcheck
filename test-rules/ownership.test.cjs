const { before, after, test } = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc } = require('firebase/firestore');
let env;
const item = {
  name:'Navy polo', colorName:'Navy blue', category:'top', formality:'smartCasual',
  occasionIds:['school'], tracksLaundry:true, washAfterWears:2, wearsSinceWash:0,
  lastWorn:null, photoUrl:null,
};
before(async()=>{
  env = await initializeTestEnvironment({
    projectId:'demo-fitcheck',
    firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync('firestore.rules','utf8')},
    storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync('storage.rules','utf8')},
  });
});
after(async()=>{await env?.cleanup();});
test('only the owner can create, read, and update their wardrobe',async()=>{
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(setDoc(doc(alice,'users/alice/clothes/top'),item));
  await assertSucceeds(getDoc(doc(alice,'users/alice/clothes/top')));
  await assertFails(getDoc(doc(bob,'users/alice/clothes/top')));
  await assertFails(updateDoc(doc(bob,'users/alice/clothes/top'),{wearsSinceWash:3}));
  await assertFails(setDoc(doc(bob,'users/alice/clothes/another'),item));
  await assertFails(getDoc(doc(guest,'users/alice/clothes/top')));
});
test('clothing writes reject missing, invalid, and unrelated fields',async()=>{
  const alice = env.authenticatedContext('alice').firestore();
  for(const invalid of [
    {...item,name:''}, {...item,colorName:''}, {...item,category:'accessory'},
    {...item,washAfterWears:4}, {...item,wearsSinceWash:-1}, {...item,occasionIds:[]},
    {...item,arbitraryField:true}, {name:'Incomplete'},
  ]) await assertFails(setDoc(doc(alice,'users/alice/clothes/invalid'),invalid));
});
test('occasions are owner scoped and validated',async()=>{
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(setDoc(doc(alice,'users/alice/occasions/gig'),{name:'Gig',isDefault:false}));
  await assertFails(getDoc(doc(bob,'users/alice/occasions/gig')));
  await assertFails(setDoc(doc(alice,'users/alice/occasions/empty'),{name:'',isDefault:false}));
});
test('photo uploads require ownership, image type, and a size under 5 MB',async()=>{
  const alice = env.authenticatedContext('alice').storage('demo-fitcheck.appspot.com');
  const bob = env.authenticatedContext('bob').storage('demo-fitcheck.appspot.com');
  await assertSucceeds(alice.ref('users/alice/clothes/top/photo').put(new Uint8Array([1,2,3]),{contentType:'image/png'}));
  await assertFails(bob.ref('users/alice/clothes/top/photo').getMetadata());
  await assertFails(bob.ref('users/alice/clothes/top/photo').put(new Uint8Array([1]),{contentType:'image/png'}));
  await assertFails(alice.ref('users/alice/clothes/bad/photo').put(new Uint8Array([1]),{contentType:'text/html'}));
  await assertFails(alice.ref('users/alice/clothes/large/photo').put(new Uint8Array(5*1024*1024+1),{contentType:'image/png'}));
});
