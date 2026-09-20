# Practicum Connect Flutter

Flutter conversion of the supplied PHP internship-management prototype. The app
uses three authoritative roles from the project requirements:

- **Admin** — all modules
- **Coordinator** — internship records, requirements, repository, document
  review, DTR, TOR, rendered hours, MOA, notifications, and reports
- **Student** — dashboard, status tracker, submission bins, document repository,
  and notifications

## Implemented

- Responsive login and light dashboard UI based on the supplied thesis figures
- Role-based navigation and route guarding
- Firebase email/password authentication
- Secure self-registration for student accounts
- Firestore user profiles, requirements, DTR records, and notifications
- Supabase Storage uploads protected with Firebase third-party JWTs
- Dynamic requirement bins, forms, instructions, deadlines, and program filters
- Student upload, status tracking, feedback, and document version history
- Searchable repository with signed preview/download links
- Coordinator review with revision, rejection, verification, and notifications
- Consolidated student internship profile and coordinator dashboard
- Coordinator/admin DTR entry and rendered-hour calculation
- DTR verification, correction remarks, and real-student selection
- Role- and student-targeted notification creation with per-user read state
- Notification activation/deactivation management
- Live report summary cards
- Live student/user lists with administrator account activation controls
- Coordinator student assignment and handlist tracking
- TOR review, secure document links, and revision resubmission
- MOA details, contacts, document upload, renewal, replacement, deletion, and
  expiry monitoring
- Rendered-hour totals and audit logs
- Spark-compatible Firestore rules; no Firebase Cloud Functions

Phase 4 is implemented with one-time external supervisor evaluation links,
PDF/Excel/CSV exports, and June–May academic-year archiving.

Students register from the login screen. Coordinator and administrator accounts
must be issued with the local admin helper described in `SETUP.md`; privileged
roles are never selected by a public signup form.

## Run the application

```powershell
flutter pub get
flutter run -d edge
```

The supplied Firebase Web app is already configured. Sign in with a real account
created using the helper in [SETUP.md](SETUP.md). Add Supabase settings before
using uploads or downloads.
