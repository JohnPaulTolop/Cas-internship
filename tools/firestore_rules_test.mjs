import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-practicum-connect',
  firestore: {
    host: '127.0.0.1',
    port: 8080,
    rules: readFileSync('firestore.rules', 'utf8'),
  },
});

async function check(description, operation) {
  await operation();
  console.log(`PASS: ${description}`);
}

try {
  // All records below are fictional and exist only in the local emulator.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await Promise.all([
      setDoc(doc(db, 'users', 'student1'), {
        role: 'student',
        active: true,
        coordinatorId: 'coordinator1',
      }),
      setDoc(doc(db, 'users', 'student2'), {
        role: 'student',
        active: true,
        coordinatorId: 'coordinator2',
      }),
      setDoc(doc(db, 'users', 'coordinator1'), {
        role: 'coordinator',
        active: true,
        approvalStatus: 'approved',
      }),
      setDoc(doc(db, 'users', 'coordinator2'), {
        role: 'coordinator',
        active: true,
        approvalStatus: 'approved',
      }),
      setDoc(doc(db, 'users', 'admin1'), {
        role: 'admin',
        active: true,
      }),

      // Two evaluations for the same student have separate status IDs.
      setDoc(doc(db, 'evaluation_status', 'status-eval-1'), {
        studentId: 'student1',
        academicYear: '2026-2027',
        status: 'submitted',
        createdAt: new Date(),
      }),
      setDoc(doc(db, 'evaluation_status', 'status-eval-2'), {
        studentId: 'student1',
        academicYear: '2026-2027',
        status: 'pending',
        createdAt: new Date(),
      }),
      setDoc(doc(db, 'evaluation_status', 'status-other-student'), {
        studentId: 'student2',
        academicYear: '2026-2027',
        status: 'submitted',
        createdAt: new Date(),
      }),

      setDoc(doc(db, 'supervisor_evaluations', 'test-evaluation'), {
        studentId: 'student1',
        coordinatorId: 'coordinator1',
        statusId: 'status-eval-1',
        academicYear: '2026-2027',
        status: 'submitted',
        statusSyncPending: true,
        ratings: { professionalism: 5 },
        comments: 'Fictional confidential test comment',
      }),
    ]);
  });

  const student = env.authenticatedContext('student1').firestore();
  const otherStudent = env.authenticatedContext('student2').firestore();
  const coordinator = env.authenticatedContext('coordinator1').firestore();
  const otherCoordinator =
    env.authenticatedContext('coordinator2').firestore();
  const admin = env.authenticatedContext('admin1').firestore();

  const evaluationPath = ['supervisor_evaluations', 'test-evaluation'];

  await check('Student can read own submitted evaluation status', () =>
    assertSucceeds(getDoc(doc(student, 'evaluation_status', 'status-eval-1'))));

  await check('Student can read own pending evaluation status', () =>
    assertSucceeds(getDoc(doc(student, 'evaluation_status', 'status-eval-2'))));

  await check('Student cannot read another student status', () =>
    assertFails(getDoc(doc(student, 'evaluation_status', 'status-other-student'))));

  await check('Another student cannot read this student status', () =>
    assertFails(getDoc(doc(otherStudent, 'evaluation_status', 'status-eval-1'))));

  await check('Student can query only own evaluation statuses', () =>
    assertSucceeds(getDocs(query(
      collection(student, 'evaluation_status'),
      where('studentId', '==', 'student1'),
    ))));

  await check('Student cannot query all students evaluation statuses', () =>
    assertFails(getDocs(collection(student, 'evaluation_status'))));

  await check('Student cannot read confidential evaluation', () =>
    assertFails(getDoc(doc(student, ...evaluationPath))));

  await check('Assigned coordinator can read confidential evaluation', () =>
    assertSucceeds(getDoc(doc(coordinator, ...evaluationPath))));

  await check('Unassigned coordinator cannot read confidential evaluation', () =>
    assertFails(getDoc(doc(otherCoordinator, ...evaluationPath))));

  await check('Coordinator cannot change supervisor ratings', () =>
    assertFails(updateDoc(doc(coordinator, ...evaluationPath), {
      ratings: { professionalism: 1 },
    })));

  await check('Admin cannot change supervisor comments', () =>
    assertFails(updateDoc(doc(admin, ...evaluationPath), {
      comments: 'Changed by admin',
    })));

  await check('Student cannot forge submitted status', () =>
    assertFails(setDoc(doc(student, 'evaluation_status', 'forged-status'), {
      studentId: 'student1',
      academicYear: '2026-2027',
      status: 'submitted',
      createdAt: new Date(),
    })));

  await check('Coordinator cannot create pending status directly', () =>
    assertFails(setDoc(doc(coordinator, 'evaluation_status', 'new-pending-status'), {
      studentId: 'student1',
      academicYear: '2026-2027',
      status: 'pending',
      createdAt: new Date(),
    })));

  await check('Admin cannot create pending status directly', () =>
    assertFails(setDoc(doc(admin, 'evaluation_status', 'admin-pending-status'), {
      studentId: 'student1',
      academicYear: '2026-2027',
      status: 'pending',
      createdAt: new Date(),
    })));

  await check('Coordinator cannot create confidential evaluation directly', () =>
    assertFails(setDoc(doc(coordinator, 'supervisor_evaluations', 'coordinator-direct-create'), {
      studentId: 'student1',
      coordinatorId: 'coordinator1',
      academicYear: '2026-2027',
      status: 'pending',
      archived: false,
    })));

  await check('Admin cannot create confidential evaluation directly', () =>
    assertFails(setDoc(doc(admin, 'supervisor_evaluations', 'admin-direct-create'), {
      studentId: 'student1',
      academicYear: '2026-2027',
      status: 'pending',
      archived: false,
    })));
  await check('Coordinator cannot create a submitted status', () =>
    assertFails(setDoc(doc(coordinator, 'evaluation_status', 'forged-submission'), {
      studentId: 'student1',
      academicYear: '2026-2027',
      status: 'submitted',
      createdAt: new Date(),
    })));

  await check('Coordinator cannot change pending status to submitted', () =>
    assertFails(updateDoc(doc(coordinator, 'evaluation_status', 'status-eval-2'), {
      status: 'submitted',
    })));

  await check('Assigned coordinator can clear sync-pending flag', () =>
    assertSucceeds(updateDoc(doc(coordinator, ...evaluationPath), {
      statusSyncPending: false,
    })));

  console.log('All multiple-evaluation security tests passed.');
} finally {
  await env.cleanup();
}