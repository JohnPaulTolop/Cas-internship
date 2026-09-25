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

const baseNotice = {
  message: 'Local emulator notification',
  type: 'general',
  priority: 'normal',
  scheduledFor: null,
  readBy: [],
  read: false,
  active: true,
  createdAt: new Date(),
  updatedAt: new Date(),
};

try {
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

      setDoc(doc(db, 'notifications', 'all-users'), {
        ...baseNotice,
        title: 'Everyone',
        targetRole: 'all',
        targetUserId: null,
        createdBy: 'admin1',
      }),
      setDoc(doc(db, 'notifications', 'students'), {
        ...baseNotice,
        title: 'Students',
        targetRole: 'student',
        targetUserId: null,
        createdBy: 'admin1',
      }),
      setDoc(doc(db, 'notifications', 'coordinators'), {
        ...baseNotice,
        title: 'Coordinators',
        targetRole: 'coordinator',
        targetUserId: null,
        createdBy: 'admin1',
      }),
      setDoc(doc(db, 'notifications', 'student1-only'), {
        ...baseNotice,
        title: 'Student 1 only',
        targetRole: 'user:student1',
        targetUserId: 'student1',
        createdBy: 'coordinator1',
      }),
      setDoc(doc(db, 'notifications', 'student2-only'), {
        ...baseNotice,
        title: 'Student 2 only',
        targetRole: 'user:student2',
        targetUserId: 'student2',
        createdBy: 'coordinator2',
      }),
      setDoc(doc(db, 'notifications', 'coordinator1-only'), {
        ...baseNotice,
        title: 'Coordinator 1 only',
        targetRole: 'user:coordinator1',
        targetUserId: 'coordinator1',
        createdBy: 'student1',
      }),
      setDoc(doc(db, 'notifications', 'inactive-student'), {
        ...baseNotice,
        title: 'Inactive',
        targetRole: 'student',
        targetUserId: null,
        active: false,
        createdBy: 'admin1',
      }),
    ]);
  });

  const student1 =
      env.authenticatedContext('student1').firestore();
  const student2 =
      env.authenticatedContext('student2').firestore();
  const coordinator1 =
      env.authenticatedContext('coordinator1').firestore();
  const coordinator2 =
      env.authenticatedContext('coordinator2').firestore();
  const admin =
      env.authenticatedContext('admin1').firestore();

  await check('Student can query active notices for everyone', () =>
    assertSucceeds(
      getDocs(
        query(
          collection(student1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'all'),
          where('targetUserId', '==', null),
        ),
      ),
    ));

  await check('Student can query active student role notices', () =>
    assertSucceeds(
      getDocs(
        query(
          collection(student1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'student'),
          where('targetUserId', '==', null),
        ),
      ),
    ));

  await check('Student can query notifications targeted to self', () =>
    assertSucceeds(
      getDocs(
        query(
          collection(student1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'user:student1'),
          where('targetUserId', '==', 'student1'),
        ),
      ),
    ));

  await check('Student cannot read another student targeted notice', () =>
    assertFails(
      getDoc(doc(student1, 'notifications', 'student2-only')),
    ));

  await check('Student cannot read inactive notification', () =>
    assertFails(
      getDoc(doc(student1, 'notifications', 'inactive-student')),
    ));

  await check('Coordinator can query active coordinator role notices', () =>
    assertSucceeds(
      getDocs(
        query(
          collection(coordinator1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'coordinator'),
          where('targetUserId', '==', null),
        ),
      ),
    ));

  await check('Coordinator can query notifications targeted to self', () =>
    assertSucceeds(
      getDocs(
        query(
          collection(coordinator1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'user:coordinator1'),
          where('targetUserId', '==', 'coordinator1'),
        ),
      ),
    ));

  await check('Coordinator cannot read another coordinator notice', () =>
    assertFails(
      getDocs(
        query(
          collection(coordinator1, 'notifications'),
          where('active', '==', true),
          where('targetRole', '==', 'user:coordinator2'),
          where('targetUserId', '==', 'coordinator2'),
        ),
      ),
    ));

  await check('Student can notify assigned coordinator', () =>
    assertSucceeds(
      setDoc(doc(student1, 'notifications', 'student-to-coordinator'), {
        ...baseNotice,
        title: 'Student workflow update',
        targetRole: 'user:coordinator1',
        targetUserId: 'coordinator1',
        createdBy: 'student1',
      }),
    ));

  await check('Student cannot notify another coordinator', () =>
    assertFails(
      setDoc(doc(student1, 'notifications', 'student-wrong-coordinator'), {
        ...baseNotice,
        title: 'Invalid target',
        targetRole: 'user:coordinator2',
        targetUserId: 'coordinator2',
        createdBy: 'student1',
      }),
    ));

  await check('Coordinator can notify assigned student', () =>
    assertSucceeds(
      setDoc(doc(coordinator1, 'notifications', 'coordinator-to-student'), {
        ...baseNotice,
        title: 'Coordinator workflow update',
        targetRole: 'user:student1',
        targetUserId: 'student1',
        createdBy: 'coordinator1',
      }),
    ));

  await check('Coordinator cannot notify unassigned student', () =>
    assertFails(
      setDoc(doc(coordinator1, 'notifications', 'wrong-student'), {
        ...baseNotice,
        title: 'Invalid student',
        targetRole: 'user:student2',
        targetUserId: 'student2',
        createdBy: 'coordinator1',
      }),
    ));

  await check('Admin can create student role-wide notification', () =>
    assertSucceeds(
      setDoc(doc(admin, 'notifications', 'admin-student-role'), {
        ...baseNotice,
        title: 'Admin announcement',
        targetRole: 'student',
        targetUserId: null,
        createdBy: 'admin1',
      }),
    ));

  await check('Student can mark own targeted notice read', () =>
    assertSucceeds(
      updateDoc(doc(student1, 'notifications', 'student1-only'), {
        readBy: ['student1'],
        updatedAt: new Date(),
      }),
    ));

  await check('Student cannot forge another reader on own notice', () =>
    assertFails(
      updateDoc(doc(student1, 'notifications', 'student1-only'), {
        readBy: ['student1', 'student2'],
        updatedAt: new Date(),
      }),
    ));

  await check('Student can add own read status to role-wide notice', () =>
    assertSucceeds(
      updateDoc(doc(student1, 'notifications', 'students'), {
        readBy: ['student1'],
        updatedAt: new Date(),
      }),
    ));

  await check('Another student can preserve readers and add self', () =>
    assertSucceeds(
      updateDoc(doc(student2, 'notifications', 'students'), {
        readBy: ['student1', 'student2'],
        updatedAt: new Date(),
      }),
    ));

  await check('Student cannot remove another existing reader', () =>
    assertFails(
      updateDoc(doc(student1, 'notifications', 'students'), {
        readBy: ['student1'],
        updatedAt: new Date(),
      }),
    ));

  await check('Student cannot mark another student notice read', () =>
    assertFails(
      updateDoc(doc(student1, 'notifications', 'student2-only'), {
        readBy: ['student1'],
        updatedAt: new Date(),
      }),
    ));

  await check('Admin can read every notification', () =>
    assertSucceeds(
      getDocs(collection(admin, 'notifications')),
    ));

  console.log('All notification security tests passed.');
} finally {
  await env.cleanup();
}