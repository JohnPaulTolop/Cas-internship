import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const options = Object.fromEntries(
  process.argv.slice(2).map((argument) => {
    const [key, ...value] = argument.replace(/^--/, '').split('=');
    return [key, value.join('=')];
  }),
);

const allowedRoles = new Set(['admin', 'coordinator', 'student']);
if (!options.email || !allowedRoles.has(options.role)) {
  console.error(
    'Usage: node set_user_claims.mjs --email=user@example.com '
      + '--role=admin|coordinator|student',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });

const auth = getAuth();
const user = await auth.getUserByEmail(options.email.trim());
await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims ?? {}),
  role: 'authenticated',
  app_role: options.role,
});

console.log(
  `Storage access enabled for ${user.email} as ${options.role} (${user.uid}).`,
);
