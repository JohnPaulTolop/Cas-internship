import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

function ensureAdminApp() {
  if (getApps().length > 0) return getApps()[0];

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson);
    return initializeApp({
      credential: cert(serviceAccount),
      projectId: serviceAccount.project_id,
    });
  }

  const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    return initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
      projectId,
    });
  }

  return initializeApp({
    credential: applicationDefault(),
    projectId: projectId || undefined,
  });
}

function bearerToken(authorization) {
  if (!authorization || typeof authorization !== 'string') return null;
  const [scheme, token] = authorization.split(' ');
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

export async function ensureStaffClaims({ authorization }) {
  ensureAdminApp();
  const token = bearerToken(authorization);
  if (!token) {
    return { status: 401, payload: { error: 'Staff sign-in is required.' } };
  }

  const auth = getAuth();
  const db = getFirestore();
  const decoded = await auth.verifyIdToken(token, true);
  const profileSnapshot = await db.collection('users').doc(decoded.uid).get();
  const profile = profileSnapshot.data();

  if (!profileSnapshot.exists || profile?.active !== true) {
    return {
      status: 403,
      payload: { error: 'This Practicum Connect account is not active.' },
    };
  }

  const role = String(profile?.role || '').toLowerCase();
  const isAdmin = role === 'admin';
  const isCoordinator =
    role === 'coordinator' && profile?.approvalStatus === 'approved';

  if (!isAdmin && !isCoordinator) {
    return {
      status: 403,
      payload: { error: 'Only an approved Program Coordinator or CAS College Coordinator / SIP Admin can request staff storage access.' },
    };
  }

  const authUser = await auth.getUser(decoded.uid);
  const currentClaims = { ...(authUser.customClaims || {}) };
  const alreadyCorrect =
    currentClaims.app_role === role && currentClaims.role === 'authenticated';

  if (!alreadyCorrect) {
    await auth.setCustomUserClaims(decoded.uid, {
      ...currentClaims,
      app_role: role,
      role: 'authenticated',
    });
  }

  return {
    status: 200,
    payload: {
      ok: true,
      role,
      repaired: !alreadyCorrect,
      message: alreadyCorrect
        ? 'Staff security claims are already current.'
        : 'Staff security claims were repaired. Refresh the Firebase token before retrying storage access.',
    },
  };
}
