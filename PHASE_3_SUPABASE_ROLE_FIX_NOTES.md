# Phase 3 Supabase document access fix

## Root cause
Supabase third-party Firebase authentication expects the Firebase JWT `role`
claim to be the PostgreSQL role `authenticated`. Practicum Connect stores its
application authorization separately in `app_role` (`admin`, `coordinator`, or
`student`).

Several staff helper scripts incorrectly changed the Firebase `role` claim to
`admin` or `coordinator`. That can make Supabase Storage fail before the RLS
policy is evaluated, including `StorageException` database errors such as code
`22023` / HTTP 500 when Preview, Download, Retrieve, or Open Full Document is
used.

## Correct claim shape
- CAS College Coordinator / SIP Admin: `role=authenticated`, `app_role=admin`
- Program Coordinator: `role=authenticated`, `app_role=coordinator`
- Student Intern: `role=authenticated`, `app_role=student` when a claim is set

## Fixed files
- `lib/services/practicum_repository.dart`
- `tools/staff_claims_core.mjs`
- `tools/coordinator_approval_core.mjs`
- `tools/create_admin.mjs`
- `tools/set_user_claims.mjs`

The repository now treats a staff token as storage-ready only when both the
application role and Supabase database role are correct. This means an existing
broken staff token will trigger the secure `/api/staff-claims` repair endpoint
instead of trying Storage with `role=admin` or `role=coordinator`.
