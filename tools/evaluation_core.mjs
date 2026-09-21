import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';

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


function isCompletionDefinition(data) {
  const key = `${data.category || ''} ${data.title || ''}`.toLowerCase();
  return key.includes('performance') ||
    key.includes('evaluation') ||
    key.includes('final report') ||
    key.includes('narrative') ||
    key.includes('exit form');
}

async function syncCompletionStage(db, studentId) {
  if (!studentId) return;
  const [userDoc, profileDoc, definitionsSnapshot, requirementsSnapshot, dtrSnapshot] =
    await Promise.all([
      db.collection('users').doc(studentId).get(),
      db.collection('internship_profiles').doc(studentId).get(),
      db.collection('requirement_definitions').get(),
      db.collection('requirements').where('studentId', '==', studentId).get(),
      db.collection('dtr_entries').where('studentId', '==', studentId).get(),
    ]);

  if (!userDoc.exists || !profileDoc.exists) return;
  const user = userDoc.data() || {};
  const profile = profileDoc.data() || {};
  if (profile.archived === true) return;

  const program = String(user.program || '').trim();
  const definitions = definitionsSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((item) => item.active !== false)
    .filter((item) => {
      const target = String(item.program || 'All Programs').trim();
      return !target || target === 'All Programs' || target === program;
    });
  const completionDefinitions = definitions.filter(isCompletionDefinition);
  const requirements = requirementsSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((item) => item.archived !== true);

  const latestFor = (definition) => requirements
    .filter((record) =>
      record.definitionId === definition.id ||
      (!record.definitionId &&
        String(record.title || '').trim().toLowerCase() ===
          String(definition.title || '').trim().toLowerCase()))
    .sort((a, b) => {
      const aMillis = a.submittedAt?.toMillis?.() || 0;
      const bMillis = b.submittedAt?.toMillis?.() || 0;
      return bMillis - aMillis;
    })[0];

  const completionVerified = completionDefinitions.length === 0 ||
    completionDefinitions.every((definition) => latestFor(definition)?.status === 'verified');

  const approvedHours = dtrSnapshot.docs
    .map((doc) => doc.data())
    .filter((record) => record.archived !== true && record.status === 'verified')
    .reduce((sum, record) => {
      const timeIn = record.timeIn?.toDate?.();
      const timeOut = record.timeOut?.toDate?.();
      if (!(timeIn instanceof Date) || !(timeOut instanceof Date)) return sum;
      const breakMinutes = Number(record.breakMinutes || 0);
      const minutes = Math.max(0, Math.round((timeOut - timeIn) / 60000) - breakMinutes);
      return sum + minutes / 60;
    }, 0);
  const requiredHours = Number(profile.requiredHours || 400);

  if (approvedHours < requiredHours || !completionVerified) {
    await profileDoc.ref.set({
      statusSyncPending: false,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }

  await profileDoc.ref.set({
    status: 'Completed',
    completedAt: profile.completedAt || FieldValue.serverTimestamp(),
    statusSyncPending: false,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection('notifications').add({
    title: 'Internship status updated',
    message: 'Your internship status is now Completed.',
    targetRole: 'user:' + studentId,
    targetUserId: studentId,
    type: 'status_update',
    relatedId: studentId,
    priority: 'normal',
    active: true,
    readBy: [],
    createdBy: 'system:evaluation-api',
    createdAt: FieldValue.serverTimestamp(),
  });
}

function parseBody(body) {
  if (body && typeof body === 'object') return body;
  if (typeof body === 'string' && body.trim()) return JSON.parse(body);
  return {};
}

function normalizeToken(value) {
  const token = String(value || '').trim();
  return /^[A-Za-z0-9_-]{20,160}$/.test(token) ? token : '';
}

function iso(value) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value?.toDate) return value.toDate().toISOString();
  return null;
}

function publicPayload(id, data) {
  return {
    token: id,
    studentName: String(data.studentName || 'Student Intern'),
    companyName: String(data.companyName || ''),
    supervisorName: String(data.supervisorName || 'Industry Supervisor'),
    status: String(data.status || 'pending'),
    expiresAt: iso(data.expiresAt),
    submittedAt: iso(data.submittedAt),
    archived: data.archived === true,
  };
}

export async function getPublicEvaluation({ token }) {
  ensureAdminApp();
  const safeToken = normalizeToken(token);
  if (!safeToken) {
    return { status: 400, payload: { error: 'Invalid evaluation link.' } };
  }

  const db = getFirestore();
  const snapshot = await db.collection('supervisor_evaluations').doc(safeToken).get();
  if (!snapshot.exists) {
    return { status: 404, payload: { error: 'Evaluation link not found.' } };
  }

  const data = snapshot.data();
  return { status: 200, payload: publicPayload(snapshot.id, data) };
}


export async function verifyPublicEvaluationAccess({ body }) {
  ensureAdminApp();
  const parsed = parseBody(body);
  const token = normalizeToken(parsed.token);
  const email = String(parsed.email || '').trim().toLowerCase();
  if (!token || !email.includes('@')) {
    return {
      status: 400,
      payload: { error: 'A valid evaluation link and registered supervisor email are required.' },
    };
  }

  const db = getFirestore();
  const snapshot = await db.collection('supervisor_evaluations').doc(token).get();
  if (!snapshot.exists) {
    return { status: 404, payload: { error: 'Evaluation link not found.' } };
  }
  const data = snapshot.data();
  if (data.archived === true) {
    return { status: 410, payload: { error: 'This evaluation record has been archived.' } };
  }
  if (data.status === 'submitted') {
    return { status: 409, payload: { error: 'This evaluation was already submitted and is locked.' } };
  }
  const expiresAt = data.expiresAt?.toDate?.();
  if (!(expiresAt instanceof Date) || expiresAt.getTime() <= Date.now()) {
    return { status: 410, payload: { error: 'This evaluation link has expired.' } };
  }
  const expectedEmail = String(data.supervisorEmail || '').trim().toLowerCase();
  if (!expectedEmail || email !== expectedEmail) {
    return {
      status: 403,
      payload: { error: 'The email address does not match the supervisor authorized for this evaluation.' },
    };
  }
  return {
    status: 200,
    payload: { authorized: true, ...publicPayload(snapshot.id, data) },
  };
}

export async function submitPublicEvaluation({ body }) {
  ensureAdminApp();
  const parsed = parseBody(body);
  const token = normalizeToken(parsed.token);
  const email = String(parsed.email || '').trim().toLowerCase();
  const comments = String(parsed.comments || '').trim();
  const ratings = parsed.ratings && typeof parsed.ratings === 'object'
    ? parsed.ratings
    : {};

  if (!token || !email.includes('@')) {
    return {
      status: 400,
      payload: { error: 'A valid evaluation link and registered supervisor email are required.' },
    };
  }
  if (comments.length > 3000) {
    return { status: 400, payload: { error: 'Comments must be 3000 characters or fewer.' } };
  }

  const required = ['professionalism', 'workQuality', 'attendance', 'communication', 'initiative'];
  const normalizedRatings = {};
  for (const key of required) {
    const value = Number(ratings[key]);
    if (!Number.isInteger(value) || value < 1 || value > 5) {
      return { status: 400, payload: { error: 'Every rating must be an integer from 1 to 5.' } };
    }
    normalizedRatings[key] = value;
  }

  const db = getFirestore();
  const ref = db.collection('supervisor_evaluations').doc(token);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        return { status: 404, payload: { error: 'Evaluation link not found.' } };
      }
      const data = snapshot.data();
      if (data.archived === true) {
        return { status: 410, payload: { error: 'This evaluation record has been archived.' } };
      }
      if (data.status === 'submitted') {
        return { status: 409, payload: { error: 'This evaluation was already submitted and is locked.' } };
      }
      const expiresAt = data.expiresAt?.toDate?.();
      if (!(expiresAt instanceof Date) || expiresAt.getTime() <= Date.now()) {
        return { status: 410, payload: { error: 'This evaluation link has expired.' } };
      }
      const expectedEmail = String(data.supervisorEmail || '').trim().toLowerCase();
      if (!expectedEmail || email !== expectedEmail) {
        return {
          status: 403,
          payload: { error: 'The email address does not match the supervisor authorized for this evaluation.' },
        };
      }

      transaction.update(ref, {
        ratings: normalizedRatings,
        comments,
        status: 'submitted',
        submittedAt: FieldValue.serverTimestamp(),
        statusSyncPending: true,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        status: 200,
        studentId: String(data.studentId || ''),
        payload: {
          ok: true,
          message: 'Evaluation submitted successfully. This form is now locked.',
        },
      };
    });
    if (result.status === 200 && result.studentId) {
      try {
        await syncCompletionStage(db, result.studentId);
      } catch (syncError) {
        console.error('Unable to synchronize internship completion stage:', syncError);
      }
    }
    return { status: result.status, payload: result.payload };
  } catch (error) {
    return {
      status: 500,
      payload: { error: error instanceof Error ? error.message : String(error) },
    };
  }
}
