import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const dueDate = (daysFromNow) => {
  const date = new Date();
  date.setDate(date.getDate() + daysFromNow);
  return Timestamp.fromDate(date);
};

const definitions = [
  {
    id: 'recommendation-letter',
    title: 'Recommendation Letter',
    category: 'Pre-deployment',
    description: 'Official endorsement from a faculty member.',
    instructions: 'Upload a clear PDF copy of the signed recommendation letter.',
    dueInDays: 14,
  },
  {
    id: 'curriculum-vitae',
    title: 'Curriculum Vitae',
    category: 'Pre-deployment',
    description: 'Updated CV with academic background and relevant experience.',
    instructions: 'Use the official format when provided and upload a PDF.',
    dueInDays: 14,
  },
  {
    id: 'internship-contract',
    title: 'Internship Contract Agreement',
    category: 'Agreement',
    description: 'Signed agreement between the student and partner institution.',
    instructions: 'Upload all signed pages as one PDF document.',
    dueInDays: 21,
  },
  {
    id: 'student-pledge',
    title: 'Student Pledge and Commitment',
    category: 'Pre-deployment',
    description: 'Signed statement of compliance with internship policies.',
    instructions: 'Read, sign, scan, and upload the complete form.',
    dueInDays: 21,
  },
  {
    id: 'medical-certificate',
    title: 'Medical Certificate',
    category: 'Medical',
    description: 'Medical clearance from a licensed physician.',
    instructions: 'The certificate must state that you are fit for internship duties.',
    dueInDays: 14,
  },
  {
    id: 'moa',
    title: 'Memorandum of Agreement',
    category: 'Agreement',
    description: 'Applicable agreement for the assigned partner institution.',
    instructions: 'Upload the signed MOA copy provided by the coordinator.',
    dueInDays: 30,
  },
  {
    id: 'weekly-report',
    title: 'Weekly Accomplishment Report',
    category: 'Monitoring',
    description: 'Weekly summary of completed internship activities.',
    instructions: 'Submit the signed weekly report using the prescribed format.',
    dueInDays: 7,
  },
  {
    id: 'dtr',
    title: 'Daily Time Record',
    category: 'Monitoring',
    description: 'Attendance and rendered-hour record.',
    instructions: 'Upload the signed DTR for the reporting period.',
    dueInDays: 7,
  },
  {
    id: 'performance-assessment',
    title: 'Performance Assessment',
    category: 'Evaluation',
    description: 'Supervisor assessment of internship performance.',
    instructions: 'Upload only when requested by the coordinator.',
    dueInDays: 90,
  },
  {
    id: 'final-report',
    title: 'Final Report',
    category: 'Completion',
    description: 'Complete narrative report for the internship.',
    instructions: 'Combine the approved final report and required appendices into one PDF.',
    dueInDays: 120,
  },
  {
    id: 'tor',
    title: 'Transcript of Records',
    category: 'Academic',
    description: 'Latest official or certified transcript of records.',
    instructions: 'Upload a clear PDF copy showing the latest completed semester.',
    dueInDays: 14,
  },
];

const batch = db.batch();
definitions.forEach((definition, index) => {
  const { id, dueInDays, ...data } = definition;
  batch.set(
    db.collection('requirement_definitions').doc(id),
    {
      ...data,
      program: 'All Programs',
      dueDate: dueDate(dueInDays),
      sortOrder: index,
      active: true,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
});

await batch.commit();
console.log(`Configured ${definitions.length} real requirement bins.`);
