import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const options = Object.fromEntries(
  process.argv.slice(2).map((argument) => {
    const [key, ...value] = argument.replace(/^--/, '').split('=');
    return [key, value.join('=')];
  }),
);

const allowedRoles = new Set(['admin', 'coordinator', 'student']);
if (!options.email || !options.password || !options.name || !allowedRoles.has(options.role)) {
  console.error(
    'Usage: node create_user.mjs --email=user@example.com --password=StrongPassword '
      + '--name="User Name" --role=admin|coordinator|student [--studentNumber=2026-0001]',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(options.email);
  user = await auth.updateUser(user.uid, {
    password: options.password,
    displayName: options.name,
    disabled: false,
  });
} catch (error) {
  if (error.code !== 'auth/user-not-found') throw error;
  user = await auth.createUser({
    email: options.email,
    password: options.password,
    displayName: options.name,
    emailVerified: true,
  });
}

// "role: authenticated" lets Supabase map the Firebase JWT to its authenticated
// Postgres role. "app_role" retains the Practicum Connect authorization role.
await auth.setCustomUserClaims(user.uid, {
  role: 'authenticated',
  app_role: options.role,
});

await db.collection('users').doc(user.uid).set(
  {
    email: options.email,
    displayName: options.name,
    role: options.role,
    studentNumber: options.studentNumber ?? null,
    active: true,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`Created/updated ${options.email} as ${options.role} (${user.uid}).`);
