# PHP-to-Flutter migration map

The supplied PHP prototype used five dashboard names, while the approved access
matrix uses three application roles. The Flutter app therefore treats the access
matrix as the source of truth.

| PHP prototype | Flutter destination |
| --- | --- |
| `login.php` | Responsive Firebase email/password login |
| `dashboards/intern.php` | Student dashboard, requirements, repository |
| `dashboards/coordinator.php` | Coordinator operational modules |
| `dashboards/school.php` | Administrative oversight modules |
| `dashboards/company.php` | Administrative partner/MOA scope |
| `dashboards/supervisor.php` | Expiring public supervisor evaluation link |
| `assets/css/style.css` | Material 3 theme using the original blue/charcoal palette |
| MySQL `users` | Firebase Auth plus `users/{uid}` Firestore profiles |
| MySQL `documents` | Firestore metadata plus private Supabase Storage objects |
| MySQL `notifications` | Firestore role-targeted notifications |

## First working backend slice

- Requirement submission → Supabase upload → Firestore metadata → coordinator
  review → student status/remarks
- DTR entry → automatic rendered-hour calculation → live dashboard/report totals
- Notification creation → audience targeting → dashboard display
- Role authorization in both the Flutter UI and Firestore rules

## Advanced workflows completed

- Date-filtered PDF/Excel/CSV report export
- External company-supervisor evaluation links with one-time submission
- Academic-year archiving and retained-record viewer
