# Firebase and Supabase setup

This design stays within Firebase's Spark plan. It does not deploy Cloud
Functions and does not use Firebase Storage.

## 1. Firebase

The Firebase Web app `integratedschoolmanageme-8a7ef` is configured in
`lib/firebase_options.dart`.

1. In that Firebase project, enable **Authentication → Email/Password**.
2. Create a Firestore database.
3. Deploy the included rules from this folder:

   ```powershell
   firebase deploy --only firestore
   ```

Do not weaken the Firestore rules for development. Every authenticated session
uses Firebase and all displayed records come from Firestore.

## 2. Supabase Storage

1. Create a Supabase project on its free plan.
2. In **Authentication → Third-party Auth**, connect the same Firebase project.
   Choose **Firebase** and enter project ID
   `integratedschoolmanageme-8a7ef`. Without this integration, Storage rejects
   Firebase's RS256 token with `"alg" Header Parameter value not allowed`.
3. Run `supabase_storage_policies.sql` in the Supabase SQL editor. This creates a
   private `internship-documents` bucket and its row-level security policies.
4. Put the Supabase URL and **publishable key** in `config/local.json`.

Never put the Supabase secret/service-role key in the Flutter app. The app sends
the current Firebase ID token to Supabase. File paths begin with the Firebase UID,
and Storage policies enforce ownership. Admin and coordinator file review uses
the `app_role` Firebase custom claim.

## 3. Create users without Blaze or Cloud Functions

Students can select **Create student account** on the login screen. The security
rules permit that form to create only an active `student` profile for the signed-in
Firebase UID; it cannot create an administrator or coordinator.

Administrator and coordinator accounts are intentionally created with the local
admin helper below. This prevents public users from assigning themselves a
privileged role.

The local admin helper creates the Firebase Auth user, Firestore profile, and the
two claims Supabase needs. Download a Firebase service-account JSON for local
administration only; never place it in this project.

```powershell
cd tools
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS='C:\secure\service-account.json'
node create_user.mjs --email=admin@example.com --password=StrongPassword123! --name="System Admin" --role=admin
node create_user.mjs --email=coordinator@example.com --password=StrongPassword123! --name="Program Coordinator" --role=coordinator
node create_user.mjs --email=student@example.com --password=StrongPassword123! --name="Student Intern" --role=student --studentNumber=2026-0001
```

Existing users must sign out and back in after claims change so Firebase issues a
new ID token.

Students who created their own account still need the Firebase custom claim
before they can use Supabase Storage. This one-time local command adds the claim
without changing their password or Firestore profile:

```powershell
cd tools
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS='C:\secure\service-account.json'
node set_user_claims.mjs --email=student@example.com --role=student
```

The app force-refreshes the Firebase token when an upload starts, so the student
can retry immediately after the command completes.

## 4. Configure the real submission bins

The interface does not use hard-coded demonstration submissions. Run this
one-time administration script to create the actual requirement definitions
that students will see. The coordinator can edit every title, instruction,
program, deadline, official-form URL, and sample-form URL in the Requirements
module afterward.

```powershell
cd tools
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS='C:\secure\service-account.json'
node seed_requirement_definitions.mjs
```

This creates definitions only. It does not create fake students, submissions,
MOAs, notifications, or internship records.

## 5. Run with the real backend

Without file uploads, run the Firebase-backed Web app from the project root:

```powershell
flutter pub get
flutter run -d edge
```

After adding the Supabase URL and publishable key to `config/local.json`, run:

```powershell
flutter run -d edge --dart-define-from-file=config/local.json
```

## Firestore collections

- `users/{uid}` — profile, active flag, app role, and coordinator assignment
- `requirements/{id}` — student file metadata and review state
- `requirement_definitions/{id}` — dynamic submission bins, forms, and deadlines
- `requirement_versions/{id}` — retained document versions after resubmission
- `internship_profiles/{studentId}` — placement, supervisor, status, and hours target
- `dtr_entries/{id}` — attendance, breaks, rendered hours, review state, and remarks
- `notifications/{id}` — role-targeted notices and active/inactive state
- `moas/{id}` — partner agreements, Supabase file path, and validity dates
- TOR records use requirement documents whose title contains `TOR` or
  `Transcript of Records`
- `activity_logs/{id}` — append-only audit events
- `supervisor_evaluations/{token}` — expiring, one-time external evaluations
- `academic_archives/{id}` — archive run summaries and record counts

## 6. Build and optionally host the Web application

Evaluation links must use a URL the company supervisor can open. For a deployed
Web build, run the following only after confirming this Firebase project/site is
dedicated to Practicum Connect:

```powershell
flutter build web --release --dart-define-from-file=config/local.json
firebase deploy --project integratedschoolmanageme-8a7ef --only firestore,hosting
```

The included hosting rewrite preserves Flutter Web query parameters such as
`?evaluation=...`. Localhost evaluation links work only on the same development
computer unless its server is exposed to the supervisor.
