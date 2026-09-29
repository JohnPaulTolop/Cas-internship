Practicum Connect – Supervisor Evaluation UI Enhancement

Updated file:
  lib/screens/public_evaluation_screen.dart

What changed:
- Reference-inspired Practicum Connect supervisor portal header.
- Clean two-column desktop layout: Assigned Intern + Evaluation Form.
- Responsive stacked layout for smaller screens.
- Soft light colors, subtle borders, clean cards, no gradients.
- Assigned intern summary with institution, supervisor, and link expiry.
- Secure access verification panel.
- Cleaner 1–5 rating rows with visible score values.
- Improved optional feedback field.
- Final confirmation checkbox before submission.
- Stronger locked-after-submit warning.
- Branded footer and improved submitted/expired/invalid states.

Existing logic preserved:
- Secure email verification.
- Existing 1–5 rating workflow.
- Existing comments submission.
- Existing one-time submission behavior.
- Existing repository calls and token validation.
- No Firebase, Firestore, Supabase, or API changes.

The reference image contains editable-PDF download/upload controls. The current
Practicum Connect public evaluation workflow is a secure web rating form, so this
package mirrors the visual layout without inventing unsupported PDF functions.

After copying the file into your project, run:
  dart format .\lib\screens\public_evaluation_screen.dart
  flutter analyze
  flutter test
  flutter run -d chrome --dart-define-from-file=config/local.json
