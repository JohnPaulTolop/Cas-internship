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
const role = args.role?.trim()?.toLowerCase();
if (!email || !['admin', 'coordinator', 'student'].includes(role)) {
  console.error('Usage: node set_user_claims.mjs --email=user@example.com --role=admin|coordinator|student');
  process.exit(1);
}

const auth = getAuth();
const db = getFirestore();
const user = await auth.getUserByEmail(email);
const currentClaims = user.customClaims || {};
await auth.setCustomUserClaims(user.uid, {
  ...currentClaims,
  app_role: role,
  role: 'authenticated',
});

await db.collection('users').doc(user.uid).set(
  {
    email: user.email || email,
    role,
    active: true,
    approvalStatus: 'approved',
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`Applied ${role} claims to ${email}. Sign out and sign back in.`);
