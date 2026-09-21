# Copy instructions

Copy this ZIP's contents into the root of:

`C:\Users\Jp\websystem_internship\`

Allow Windows to replace matching files. Do not replace or delete
`config/local.json`.

After copying:

1. Stop the Flutter app and local API.
2. Start the API again:
   ```powershell
   cd C:\Users\Jp\websystem_internship\tools
   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\service-account.json"
   node approval_server.mjs
   ```
3. Start Flutter again:
   ```powershell
   cd C:\Users\Jp\websystem_internship
   flutter analyze
   flutter run -d edge --dart-define-from-file=config/local.json
   ```
4. Sign out and sign back in once, then test Preview / Download / Retrieve.

No Firestore rule deployment is required for this hotfix.
