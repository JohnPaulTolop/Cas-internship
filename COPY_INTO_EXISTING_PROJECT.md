# Files to copy into an existing Flutter project

Copy these folders and files into the root of `websystem_internship`:

```text
websystem_internship/
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── core/
│   │   ├── app_config.dart
│   │   └── app_theme.dart
│   ├── models/
│   │   ├── app_feature.dart
│   │   ├── app_user.dart
│   │   ├── records.dart
│   │   └── workflow_models.dart
│   ├── screens/
│   │   ├── advanced_reports_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── coordinator_dashboard_screen.dart
│   │   ├── document_workflow_screens.dart
│   │   ├── dynamic_screens.dart
│   │   ├── login_screen.dart
│   │   ├── module_screens.dart
│   │   ├── moa_management_screen.dart
│   │   ├── notification_panel_screen.dart
│   │   ├── public_evaluation_screen.dart
│   │   ├── student_profile_screen.dart
│   │   └── workflow_shared.dart
│   └── services/
│       ├── app_controller.dart
│       ├── auth_service.dart
│       ├── practicum_repository.dart
│       └── report_export_service.dart
├── config/
│   └── example.json
├── test/
│   ├── dtr_record_test.dart
│   └── role_access_test.dart
├── tools/
│   ├── create_user.mjs
│   ├── seed_requirement_definitions.mjs
│   ├── set_user_claims.mjs
│   └── package.json
├── firebase.json
├── firestore.indexes.json
├── firestore.rules
├── PHASE_STATUS.md
├── supabase_storage_policies.sql
└── pubspec.yaml
```

Do not copy the generated `android`, `ios`, `web`, `windows`, `linux`, or `macos`
folders from this package. Keep the platform folders already generated in your
project.

## Required dependencies

If you prefer to keep your existing `pubspec.yaml`, merge only these entries
under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^6.10.0
  file_picker: ^13.1.0
  firebase_auth: ^6.7.0
  firebase_core: ^4.15.0
  intl: ^0.20.2
  pdf: ^3.13.1
  supabase_flutter: ^2.17.2
  url_launcher: ^6.3.2
```

Then run:

```powershell
flutter pub get
```

## Real backend configuration

Copy the configuration template:

```powershell
Copy-Item "config\example.json" "config\local.json"
```

Replace the Supabase `replace-me` values in `config/local.json`, then start the
app:

```powershell
flutter run -d edge --dart-define-from-file=config/local.json
```

Firebase Web settings are already in `lib/firebase_options.dart`. The app never
falls back to local or sample accounts.
