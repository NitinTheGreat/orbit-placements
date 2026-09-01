# Orbit

Orbit is a Flutter app that tracks every VIT placement drive — registrations, PPTs, shortlists, and OAs — so nothing gets missed. Students sign in with their VIT Google account, see a live feed of the companies coming to campus ordered by registration deadline, and open any drive to read its full details and requirements checklist. An admin surface, gated behind a Firebase custom claim, is used to enter drives by hand while automated ingestion is still to come.

## Folder structure

```
lib/
├── core/
│   ├── constants/  app constants, the allowed email domain
│   ├── routing/    go_router config and route names
│   ├── session/    auth/session state that drives redirects
│   ├── theme/      Material 3 light and dark themes
│   └── widgets/    shared widgets
├── features/
│   ├── auth/       splash, Google sign-in, onboarding
│   ├── companies/  student-facing drive list and detail
│   └── admin/      manual drive entry, admin-claim gated
├── models/         Company, Student, StudentCompanyStatus
├── services/       Firebase Auth and Firestore clients
├── firebase_options.dart
└── main.dart
```

## Getting started

Requires the Flutter SDK on the stable channel, plus the Firebase and FlutterFire CLIs:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Point the project at your own Firebase project and generate `lib/firebase_options.dart`:

```bash
firebase login
flutterfire configure --project=<your-firebase-project-id> --platforms=android,ios
```

`flutterfire configure` also writes `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`, both of which are gitignored because they are tied to one Firebase project. `lib/firebase_options.dart` is committed as a placeholder that throws until you run the command, and is overwritten in place by it. Then:

```bash
flutter pub get
flutter run
```

Deploy the security rules with `firebase deploy --only firestore:rules`.

### Firebase console setup

1. Enable **Authentication → Sign-in method → Google**.
2. Enable **Cloud Firestore**.
3. Add your Android SHA-1 and SHA-256 debug keys under Project settings → Your apps, or Google sign-in will fail on Android.
4. Grant yourself the admin claim — see [scripts/README.md](scripts/README.md).

## Data model

| Collection | Document | Fields |
| --- | --- | --- |
| `students` | `{uid}` | `vitEmail`, `name`, `neoId`, `regNo`, `createdAt`, `fcmTokens[]` |
| `companies` | `{companyId}` | `name`, `category`, `ctc`, `stipend`, `eligibleBranches[]`, `eligibilityCriteria`, `registrationDeadline`, `visitDate`, `status`, `requirements[]`, `createdAt` |
| `studentCompanyStatus` | `{uid}_{companyId}` | `studentId`, `companyId`, `stage`, `updatedAt`, `source` |

`status` is one of `open`, `ppt_scheduled`, `shortlisting`, `oa_scheduled`, `results`, `closed`. `stage` is one of `applied`, `shortlisted_ppt`, `shortlisted_oa`, `selected`, `rejected`, `unknown`. Each entry in `requirements` is `{ type, label, url, required }`.

`ctc` and `stipend` are stored as strings, because drive notices state them in mixed units ("12 LPA", "45k/month"). Move them to numbers if range filtering is ever needed.

## Access rules

Sign-in is restricted to `@vitstudent.ac.in` in two places: the client checks the Google account's email and signs the user straight back out if it does not match, and [firestore.rules](firestore.rules) checks `request.auth.token.email` on every read and write. Any signed-in VIT student can read `companies` and their own `studentCompanyStatus` documents, and read/write only their own `students/{uid}` document. Only a user carrying the `admin == true` custom claim can write to `companies`.

## Implemented

- Google sign-in restricted to `@vitstudent.ac.in`, enforced client-side and in Firestore rules
- First-run onboarding capturing NeoID and registration number, creating `students/{uid}`
- Session-driven routing: splash → login → onboarding → company list, with the admin route gated on the custom claim
- Company list bound to a live Firestore stream ordered by `registrationDeadline`
- Company detail with all fields and the requirements checklist
- Manual admin entry form for drives, with a repeatable requirements list
- Dart models with `fromFirestore` / `toFirestore` and matching security rules
- `scripts/set_admin_claim.js` for granting the admin claim

## Pending

- Gmail OAuth and automated ingestion of placement mail
- Cloud Functions, including writing `studentCompanyStatus` from parsed mail
- Push notifications (`fcmTokens` is modelled but never written yet)
- Firebase Hosting for the web admin dashboard
- Student-facing UI for setting your own stage on a drive
