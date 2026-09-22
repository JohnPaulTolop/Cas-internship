import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// Do not initialize Firebase unless the local emulator is available.
const hub = await fetch('http://127.0.0.1:4400/emulators');
if (!hub.ok) {
  throw new Error('Local emulator hub is unavailable. No records were written.');
}

const emulators = await hub.json();
if (emulators.firestore?.port !== 8080) {
  throw new Error('Expected the local Firestore emulator on port 8080.');
}

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

// A separate fictional project keeps this test isolated from other emulator data.
const projectId = `demo-pc-test-${randomBytes(4).toString('hex')}`;
process.env.FIREBASE_PROJECT_ID = projectId;
initializeApp({ projectId });

const { submitPublicEvaluation } = await import('./evaluation_core.mjs');
const db = getFirestore();

const currentYear = '2026-2027';
const previousYear = '2025-2026';
const email = 'fictional-supervisor@example.invalid';
const program = 'Fictional Emulator Program';

const prerequisite = db.collection('requirement_definitions').doc('deployment-document');
const finalReport = db.collection('requirement_definitions').doc('final-report');

const cleanupRefs = [prerequisite, finalReport];
const studentIds = [];

const ratings = {
  professionalism: 5,
  workQuality: 4,
  attendance: 5,
  communication: 4,
  initiative: 5,
};

async function createScenario(name, {
  evaluationYear = currentYear,
  recordYear = currentYear,
  includePrerequisite = true,
  placementStatus = 'Confirmed',
} = {}) {
  const studentId = `fictional-${name}-${randomBytes(5).toString('hex')}`;
  studentIds.push(studentId);

  const userRef = db.collection('users').doc(studentId);
  const profileRef = db.collection('internship_profiles').doc(studentId);

  const token = randomBytes(24).toString('base64url');
  const evaluationRef = db.collection('supervisor_evaluations').doc(token);
  const statusRef = db.collection('evaluation_status').doc();

  cleanupRefs.push(userRef, profileRef, evaluationRef, statusRef);

  const writes = [
    userRef.set({
      role: 'student',
      program,
      academicYear: currentYear,
    }),
    profileRef.set({
      studentId,
      academicYear: currentYear,
      status: 'Ongoing Internship',
      placementStatus,
      requiredHours: 2,
      archived: false,
    }),
    evaluationRef.set({
      studentId,
      statusId: statusRef.id,
      academicYear: evaluationYear,
      supervisorEmail: email,
      status: 'pending',
      archived: false,
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 600000)),
    }),
    statusRef.set({
      studentId,
      academicYear: evaluationYear,
      status: 'pending',
      createdAt: Timestamp.now(),
    }),
  ];

  const requirementDefinitions = [
    { ref: prerequisite, title: 'Deployment Document' },
    { ref: finalReport, title: 'Final Report' },
  ];

  for (const definition of requirementDefinitions) {
    if (!includePrerequisite && definition.ref.id === prerequisite.id) {
      continue;
    }

    const requirementRef = db.collection('requirements').doc();
    cleanupRefs.push(requirementRef);

    writes.push(requirementRef.set({
      studentId,
      definitionId: definition.ref.id,
      title: definition.title,
      academicYear: recordYear,
      status: 'verified',
      archived: false,
      submittedAt: Timestamp.now(),
    }));
  }

  const dtrRef = db.collection('dtr_entries').doc();
  cleanupRefs.push(dtrRef);

  const timeIn = new Date('2026-09-01T08:00:00+08:00');
  const timeOut = new Date('2026-09-01T10:00:00+08:00');

  writes.push(dtrRef.set({
    studentId,
    academicYear: recordYear,
    status: 'verified',
    archived: false,
    timeIn: Timestamp.fromDate(timeIn),
    timeOut: Timestamp.fromDate(timeOut),
    breakMinutes: 0,
  }));

  await Promise.all(writes);

  const result = await submitPublicEvaluation({
    body: {
      token,
      email,
      comments: 'Fictional completion-test comment',
      ratings,
    },
  });

  assert.equal(result.status, 200, `${name}: ${JSON.stringify(result.payload)}`);

  const [evaluationDoc, statusDoc, profileDoc] = await Promise.all([
    evaluationRef.get(),
    statusRef.get(),
    profileRef.get(),
  ]);

  assert.equal(evaluationDoc.data()?.status, 'submitted');
  assert.equal(statusDoc.data()?.status, 'submitted');

  return profileDoc.data()?.status;
}

try {
  await Promise.all([
    prerequisite.set({
      title: 'Deployment Document',
      category: 'Pre-Deployment',
      program,
      active: true,
    }),
    finalReport.set({
      title: 'Final Report',
      category: 'Completion',
      program,
      active: true,
    }),
  ]);

  const previousEvaluationStatus = await createScenario(
    'previous-evaluation',
    { evaluationYear: previousYear },
  );
  assert.notEqual(previousEvaluationStatus, 'Completed');
  console.log('PASS: A previous-year evaluation cannot complete the current internship.');

  const previousRecordsStatus = await createScenario(
    'previous-records',
    { recordYear: previousYear },
  );
  assert.notEqual(previousRecordsStatus, 'Completed');
  console.log('PASS: Previous-year requirements and DTR hours do not count.');

  const missingPrerequisiteStatus = await createScenario(
    'missing-prerequisite',
    { includePrerequisite: false },
  );
  assert.notEqual(missingPrerequisiteStatus, 'Completed');
  console.log('PASS: Missing deployment prerequisites prevent completion.');

  const unconfirmedPlacementStatus = await createScenario(
    'unconfirmed-placement',
    { placementStatus: 'Unassigned' },
  );
  assert.notEqual(unconfirmedPlacementStatus, 'Completed');
  console.log('PASS: Unconfirmed placement prevents completion.');

  const validStatus = await createScenario('valid-current-internship');
  assert.equal(validStatus, 'Completed');
  console.log('PASS: Valid current-year records allow completion.');

  console.log('All local internship-completion tests passed.');
} finally {
  // Delete the fictional records and any notification created by this test.
  for (const studentId of studentIds) {
    const notifications = await db.collection('notifications')
      .where('targetUserId', '==', studentId)
      .get();

    for (const notification of notifications.docs) {
      if (notification.data().createdBy === 'system:evaluation-api') {
        cleanupRefs.push(notification.ref);
      }
    }
  }

  await Promise.all(cleanupRefs.map((ref) => ref.delete()));
}