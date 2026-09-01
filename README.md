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
│   ├── auth/       splash, Google sign-in, onboarding, Gmail connect
│   ├── companies/  student-facing drive list and detail
│   └── admin/      manual drive entry, admin-claim gated
├── models/         Company, Student, StudentCompanyStatus, GmailSync
├── services/       Firebase Auth, Firestore, and Gmail connect clients
├── firebase_options.dart
└── main.dart

functions/          connectGmail callable (token exchange + users.watch)
scripts/            one-off admin tooling
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
| `students` | `{uid}` | `vitEmail`, `name`, `neoId`, `regNo`, `createdAt`, `fcmTokens[]`, `gmailSync` |
| `gmailTokens` | `{uid}` | `refreshToken`, `scope`, `email`, `updatedAt` — server-only, no client access |
| `companies` | `{companyId}` | `name`, `category`, `ctc`, `stipend`, `eligibleBranches[]`, `eligibilityCriteria`, `registrationDeadline`, `visitDate`, `status`, `requirements[]`, `createdAt` |
| `studentCompanyStatus` | `{uid}_{companyId}` | `studentId`, `companyId`, `stage`, `updatedAt`, `source` |

`status` is one of `open`, `ppt_scheduled`, `shortlisting`, `oa_scheduled`, `results`, `closed`. `stage` is one of `applied`, `shortlisted_ppt`, `shortlisted_oa`, `selected`, `rejected`, `unknown`. Each entry in `requirements` is `{ type, label, url, required }`. `gmailSync` is `{ status, historyId, watchExpiration, connectedAt, lastError }`, where `status` is one of `none`, `connected`, `expired`, `error`, and is written only by Cloud Functions.

`ctc` and `stipend` are stored as strings, because drive notices state them in mixed units ("12 LPA", "45k/month"). Move them to numbers if range filtering is ever needed.

## Access rules

Sign-in is restricted to `@vitstudent.ac.in` in two places: the client checks the Google account's email and signs the user straight back out if it does not match, and [firestore.rules](firestore.rules) checks `request.auth.token.email` on every read and write. Any signed-in VIT student can read `companies` and their own `studentCompanyStatus` documents, and read/write only their own `students/{uid}` document. Only a user carrying the `admin == true` custom claim can write to `companies`.

## Gmail connection

Orbit reads placement mail from each student's inbox. Connecting is a mandatory onboarding step — a student who has never connected cannot reach the drive list, because the app has nothing to show them.

### How the OAuth flow works

Google no longer supports custom URI schemes on Android, and Android and iOS OAuth clients are not issued a client secret at all. Orbit therefore uses Google's documented hybrid server-side flow rather than a browser redirect:

1. The app calls `authorizeServer(['.../gmail.readonly'])` from `google_sign_in`, which returns a one-time `serverAuthCode`.
2. The app passes that code to the `connectGmail` callable function.
3. The function exchanges it for access and refresh tokens using the **web application** client ID and secret, with `redirect_uri` set to an empty string.
4. The function calls `users.watch()` against the Pub/Sub topic and writes `gmailSync` onto `students/{uid}`.

The refresh token is written to `gmailTokens/{uid}`, which is `allow read, write: if false;` — reachable only by the Admin SDK. `gmailSync` on the student document is readable by its owner but not writable by any client; the rules reject a client write that touches the key.

### Configuration

The app needs the web client ID at build time:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

The function needs two parameters and one secret:

```bash
cd functions && npm install
firebase functions:secrets:set GMAIL_OAUTH_CLIENT_SECRET
```

Copy `functions/.env.example` to `functions/.env` and fill in `GMAIL_OAUTH_CLIENT_ID` and `GMAIL_PUBSUB_TOPIC` (`projects/<project-id>/topics/gmail-notifications`). Deploy with `firebase deploy --only functions`.

### Google Cloud setup

1. Enable the **Gmail API**.
2. On the OAuth consent screen, add the scope `https://www.googleapis.com/auth/gmail.readonly` and add each tester under **Test users**.
3. Create three OAuth clients: a **Web application** client (its ID and secret are used by the function), an **Android** client (package `com.nitin.orbit` plus SHA-1), and an **iOS** client (bundle ID `com.nitin.orbit`).
4. Create the Pub/Sub topic and grant `gmail-api-push@system.gserviceaccount.com` the **Pub/Sub Publisher** role on it.

### Known constraints

`gmail.readonly` is a **restricted** scope. While the OAuth consent screen is in **Testing** status, it is capped at 100 test users and **refresh tokens expire after seven days**, so testers must reconnect weekly. Lifting that requires either publishing the app — which triggers Google verification plus an annual third-party CASA security assessment, because refresh tokens are stored on a server — or moving the project into the `vitstudent.ac.in` Workspace organization and marking the app Internal. This is unresolved and blocks real campus rollout.

A Gmail watch expires after seven days and Google recommends renewing it daily. `watchExpiration` is recorded, but nothing renews it yet.

### Requires manual verification

These paths cannot be covered by automated tests here, because they need a real Google account, a deployed function, and a live Firebase project. Verify by hand:

- `authorizeServer` returns a `serverAuthCode` on a real device, and returns null when the student declines the consent screen
- `connectGmail` exchanges the code and receives a refresh token — Google omits it if the user previously granted access, in which case the function returns an actionable error telling the student to revoke Orbit and retry
- `users.watch()` succeeds against the topic and the returned `historyId` and `expiration` land in `gmailSync`
- the security rules actually reject a client write to `gmailSync` and any read of `gmailTokens`
- the connect step is mandatory: a student who declines cannot reach the drive list

## Implemented

- Google sign-in restricted to `@vitstudent.ac.in`, enforced client-side and in Firestore rules
- First-run onboarding capturing NeoID and registration number, creating `students/{uid}`
- Session-driven routing: splash → login → onboarding → company list, with the admin route gated on the custom claim
- Company list bound to a live Firestore stream ordered by `registrationDeadline`
- Company detail with all fields and the requirements checklist
- Manual admin entry form for drives, with a repeatable requirements list
- Dart models with `fromFirestore` / `toFirestore` and matching security rules
- `scripts/set_admin_claim.js` for granting the admin claim
- Mandatory Gmail connect step in onboarding, using the hybrid server-side flow
- `connectGmail` callable function: token exchange, refresh-token storage, and `users.watch()` registration
- Gmail connection status banner on the drive list, linking back to reconnect

## Pending

- Processing the Pub/Sub notifications the watch produces — nothing consumes them yet
- Renewing Gmail watches before their seven-day expiry
- Extracting drives from mail and writing `studentCompanyStatus`
- Push notifications (`fcmTokens` is modelled but never written yet)
- Firebase Hosting for the web admin dashboard
- Student-facing UI for setting your own stage on a drive
