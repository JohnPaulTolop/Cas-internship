import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// Verify that the LOCAL emulator is running before initializing Firebase.
const hubResponse = await fetch('http://127.0.0.1:4400/emulators');
if (!hubResponse.ok) {
  throw new Error('Local emulator hub is unavailable. No test data was written.');
}

const emulators = await hubResponse.json();
if (emulators.firestore?.port !== 8080) {
  throw new Error('Expected local Firestore emulator on port 8080.');
}

// Force this test process to use the demo project and local emulator.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_PROJECT_ID = 'demo-practicum-connect';

initializeApp({ projectId: 'demo-practicum-connect' });

const { submitPublicEvaluation } = await import('./evaluation_core.mjs');
const db = getFirestore();

const token1 = randomBytes(24).toString('base64url');
const token2 = randomBytes(24).toString('base64url');
const evaluation1 = db.collection('supervisor_evaluations').doc(token1);
const evaluation2 = db.collection('supervisor_evaluations').doc(token2);
const status1 = db.collection('evaluation_status').doc();
const status2 = db.collection('evaluation_status').doc();

const email = 'fictional-supervisor@example.invalid';
const commonData = {
  studentId: 'fictional-student-for-local-test',
  coordinatorId: 'fictional-coordinator-for-local-test',
  academicYear: '2026-2027',
  supervisorEmail: email,
  archived: false,
  status: 'pending',
  expiresAt: Timestamp.fromDate(new Date(Date.now() + 600000)),
};

const body = {
  token: token1,
  email,
  comments: 'Fictional test comment',
  ratings: {
    professionalism: 5,
    workQuality: 4,
    attendance: 5,
    communication: 4,
    initiative: 5,
  },
};

try {
  await Promise.all([
    evaluation1.set({ ...commonData, statusId: status1.id }),
    evaluation2.set({ ...commonData, statusId: status2.id }),
    status1.set({
      studentId: commonData.studentId,
      academicYear: commonData.academicYear,
      status: 'pending',
    }),
    status2.set({
      studentId: commonData.studentId,
      academicYear: commonData.academicYear,
      status: 'pending',
    }),
  ]);

  const result = await submitPublicEvaluation({ body });
  assert.equal(result.status, 200, JSON.stringify(result.payload));

  const [submittedEvaluation, submittedStatus, pendingEvaluation, pendingStatus] =
    await Promise.all([
      evaluation1.get(),
      status1.get(),
      evaluation2.get(),
      status2.get(),
    ]);

  assert.equal(submittedEvaluation.data().status, 'submitted');
  assert.equal(submittedEvaluation.data().statusId, status1.id);
  assert.equal(submittedStatus.data().status, 'submitted');
  assert.equal(pendingEvaluation.data().status, 'pending');
  assert.equal(pendingStatus.data().status, 'pending');

  for (const field of ['ratings', 'comments', 'supervisorEmail', 'token']) {
    assert.equal(
      Object.hasOwn(submittedStatus.data(), field),
      false,
      `Confidential field found in student status: ${field}`,
    );
  }

  console.log('PASS: Only the matching evaluation and status were submitted.');
  console.log('PASS: Student status contains no confidential evaluation fields.');

  const repeatResult = await submitPublicEvaluation({ body });
  assert.equal(repeatResult.status, 409);

  console.log('PASS: The same evaluation link cannot be submitted twice.');
  console.log('All local supervisor-submission tests passed.');
} finally {
  // Remove only the fictional records created by this test.
  await Promise.all([
    evaluation1.delete(),
    evaluation2.delete(),
    status1.delete(),
    status2.delete(),
  ]);
}