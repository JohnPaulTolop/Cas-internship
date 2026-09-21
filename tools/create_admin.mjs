import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

if (getApps().length === 0) {
  initializeApp({ credential: applicationDefault() });
}

const args = Object.fromEntries(
  process.argv.slice(2).map((entry) => {
    const [key, ...rest] = entry.replace(/^--/, '').split('=');
    return [key, rest.join('=')];
  }),
);

const email = args.email?.trim();
const password = args.password;
const displayName = args.name?.trim() || 'School Administrator';
if (!email || !password || password.length < 6) {
  console.error('Usage: node create_admin.mjs --email=admin@example.com --password=StrongPassword123! --name="School Administrator"');
  process.exit(1);
}

const auth = getAuth();
const db = getFirestore();
let user;
try {
  user = await auth.getUserByEmail(email);
} catch (error) {
  if (error?.code !== 'auth/user-not-found') throw error;
  user = await auth.createUser({ email, password, displayName });
}

await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims || {}),
  app_role: 'admin',
  role: 'authenticated',
});
await db.collection('users').doc(user.uid).set(
  {
    email,
    displayName,
    role: 'admin',
    studentNumber: null,
    staffId: null,
    department: 'Administration',
    approvalStatus: 'approved',
    active: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`Administrator ready: ${email}`);
console.log('Sign out and sign back in if this account was already signed in.');
