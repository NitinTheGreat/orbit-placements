# Orbit

Orbit is a Flutter app that tracks every VIT placement drive — registrations, PPTs, shortlists, and OAs — so nothing gets missed. Students sign in with their VIT Google account, see a live feed of the companies coming to campus ordered by registration deadline, and open any drive to read its full details and requirements checklist. An admin surface, gated behind a Firebase custom claim, is used to enter drives by hand while automated ingestion is still to come.

## Folder structure

```
lib/
├── core/
│   ├── constants/  app constants, the allowed email domain
│   ├── routing/    go_router config and route names
│   ├── session/    auth/session state that drives redirects
│   ├── theme/      design tokens plus Material 3 light and dark themes
│   └── widgets/    shared widgets
├── features/
│   ├── auth/       splash, Google sign-in, onboarding, Gmail connect
│   ├── companies/  student-facing drive list and detail
│   └── admin/      manual drive entry, admin-claim gated
├── models/         Company, Student, StudentCompanyStatus, GmailSync
├── services/       Firebase Auth, Firestore, and Gmail connect clients
├── preview/        Firebase-free UI harness for previewing screens
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

The app needs the web client ID at build time. Keep it in `dart_define.json` at the project root (gitignored, since it is project-specific):

```json
{ "GOOGLE_SERVER_CLIENT_ID": "<web-client-id>.apps.googleusercontent.com" }
```

```bash
flutter run --dart-define-from-file=dart_define.json
```

The function needs two parameters and one secret:

```bash
cd functions && npm install
firebase functions:secrets:set GMAIL_OAUTH_CLIENT_SECRET
```

Copy `functions/.env.example` to `functions/.env` and fill in `GMAIL_OAUTH_CLIENT_ID` and `GMAIL_PUBSUB_TOPIC`. For this project those are the web client ID and `projects/orbit-507316/topics/gmail-notifications`. Deploy with `firebase deploy --only functions`.

The secret is set from a file rather than typed, so it never reaches a shell history:

```bash
firebase functions:secrets:set GMAIL_OAUTH_CLIENT_SECRET --data-file path/to/secret.txt
```

The file must contain the secret with no trailing newline; Secret Manager stores the bytes verbatim.

### This project's identifiers

| Thing | Value |
| --- | --- |
| GCP / Firebase project | `orbit-507316` (display name `orbit-placements`) |
| Firestore location | `asia-south1` (permanent) |
| Pub/Sub topic | `projects/orbit-507316/topics/gmail-notifications` |
| Dead-letter topic | `projects/orbit-507316/topics/gmail-notifications-dlq` |
| Android package / iOS bundle | `com.nitin.orbit` |

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

## Design system

Orbit is checked several times a day during a few high-stakes weeks, so the interface aims to be calm and legible rather than eventful. The organising idea is that **a drive is a deadline**: urgency is the primary visual signal, and everything else stays quiet so it can be read fast.

### Colour

Warm ink rather than blue-black, so long reading sessions feel less clinical. Amber carries achievement without reading as a tech-startup accent; coral and green are used only to mean something, never for decoration.

| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| `surface` | `#F5F3EF` | `#1A1815` | Page ground |
| `surfaceRaised` | `#FCFBF9` | `#232019` | Cards, inputs |
| `surfaceSunken` | `#EBE7E0` | `#141210` | Wells, disabled |
| `ink` | `#1A1815` | `#F5F3EF` | Primary text |
| `inkMuted` | `#6B655C` | `#A39B8E` | Secondary text |
| `inkFaint` | `#938C81` | `#7A736A` | Placeholders |
| `border` | `#E2DDD4` | `#332E26` | Hairlines |
| `accent` | `#C98A2B` | `#E0A945` | Button and badge fills |
| `accentEdge` | `#AD741F` | `#E0A945` | Focus rings, mid-tier rail |
| `accentInk` | `#7A5214` | `#F0D19A` | Amber text on wash |
| `urgent` | `#D65F4C` | `#E87A66` | Rails, borders |
| `urgentInk` | `#B33F2E` | `#E87A66` | Urgent text |
| `success` | `#2F7A5C` | `#4E9E7B` | Fills |
| `successInk` | `#2A6E53` | `#5AAD89` | Success text |

Each colour is split into a fill and an ink because the fills do not carry text contrast on their own. Amber `#C98A2B` measures only **2.65:1** on the light ground, so it is never used as a foreground: `accentEdge` (3.84:1) draws focus rings and rails, and `accentInk` (5.85:1 on its wash) carries text. The same split applies to coral and green — raw `urgent` on its wash is 3.12:1, while `urgentInk` reaches 4.77:1. Every text and edge pair in the app was measured; all clear WCAG AA for their size class.

### Type

Space Grotesk for display and titles, IBM Plex Sans for body and data. Numbers that get compared down a column — deadlines, CTC — use tabular figures so digits line up.

### Radius

Deliberately unequal: `card` 18, `sheet` 20, `control` 12, `rail` 3, `pill` for badges. Chips read as tokens, cards read as surfaces.

### What the design avoids

No gradients, no glassmorphism, and no uniform drop shadows — cards are separated by a hairline border and a slight lift in surface tone instead. Cards are **not** identical: a drive closing within two days takes a coral border and a coral rail, so the list is scannable without reading a word. No all-caps eyebrow labels, no middot-joined metadata, no arrows appended to button labels.

### Motion

`flutter_animate` runs one staggered entrance on the drive list (45ms apart, 320ms fade and rise) and nowhere else. A `Hero` carries the company name between list and detail. Taps use a spring scale via `Pressable`. A status badge change animates only the badge, through an `AnimatedSwitcher`, rather than rebuilding the card. Every one of these checks `prefersReducedMotion` first and renders statically when the platform asks for reduced motion.

### Previewing the UI

The real screens construct Firebase services, so they cannot render before `flutterfire configure` has been run. `lib/preview/preview_app.dart` is a harness that renders the genuine widgets against sample data with no Firebase at all:

```bash
flutter run --target=lib/preview/preview_app.dart
```

It has a light/dark toggle in the header. Verified running on an Android 36 emulator.

### Windows build notes

This machine needed three things to build for Android, none of which are project changes:

- `GRADLE_USER_HOME` is set to `F:\gradle-home`, because `C:` had under 3 GB free.
- The NDK (`28.2.13676358`, released as r28c) lives at `F:ndroid-ndkndroid-ndk-r28c` and is exposed to the SDK through a directory junction at `%LOCALAPPDATA%\Android\sdk
dk8.2.13676358`. AGP's own download failed for lack of space on `C:`.
- `F:\gradle-home\gradle.properties` sets `kotlin.incremental=false`; incremental compilation could not close its caches on this filesystem and failed the build.

The AVD also lives on `F:` via `ANDROID_AVD_HOME`.

## Gmail ingestion pipeline

Placement mail is turned into drive records by a LangGraph graph running as a
Python Cloud Function in `functions-py/`. Pub/Sub triggers it when Gmail
reports new mail; `syncNow` runs the same graph on demand.

### The graph

```
        cheap_filter ──reject──> END
             │
        dedup_check ──known hash──> company_write
             │ new
        llm_extract ──> company_write ──> match_student ──no match──> END
                                              │ matched
                                        check_opt_in ──opted out──> END
                                              │
                                   update_student_status ──> END
```

`llm_extract` is the only node that calls a model. Every other node is
deterministic, so a rerun on the same mail produces the same writes.
`company_write` runs regardless of any student's opt-in, because the drive
directory is shared; only `update_student_status` is per-student.

Before the graph runs at all, `processedMessages/{messageId}` is checked, so a
Pub/Sub redelivery acks and skips rather than writing twice. The cutoff date
lives in `config/ingestion` and is read once per cold start.

### Data model

`companies/{companyId}` gains `rounds: [{ id, name, order, type, announcedAt }]`
where `id` is a slug of the name (`technical-round-1`), colliding ids get `-2`,
and `order` is explicit rather than array position. `requirements` entries now
carry a stable `id`. `status` is coarse — `registration_open`, `in_progress`,
`results_declared`, `closed` — and bumps from `registration_open` to
`in_progress` the moment a first round is created.

`studentCompanyStatus/{uid}_{companyId}` replaces the old `stage` enum with
`roundHistory: [{ roundId, result, updatedAt, sourceMessageId }]`, keyed by
`roundId` so a repeat result overwrites in place rather than appending.
`currentRoundId` and `overallStatus` are recomputed on every write and never
read back from a stored value. `optedIn` is three-state: unset becomes `true`
the first time a student is genuinely named in a drive's mail, an explicit
`false` always suppresses, and nothing ever auto-sets `false`.

This was a model change against an empty database, not a migration.

### Extraction model

`llm_extract` calls Gemini through the `google-genai` SDK with API-key auth,
asking for `response_mime_type='application/json'` against the `ExtractionResult`
Pydantic model, so the response comes back on `response.parsed` already
validated. The model defaults to `gemini-3.7-flash` and is overridable with
`ORBIT_EXTRACTION_MODEL`. Only this node changed when the provider was swapped;
the graph, its branches, and every other node were untouched.

Attachment parsing uses `openpyxl` for xlsx and `pypdf` for pdf, with the
standard library for csv.

### Working on functions-py

Python dependencies live in a virtualenv rather than on the machine:

```bash
cd functions-py
python -m venv venv
venv\Scriptsctivate        # Windows
source venv/bin/activate      # macOS and Linux
pip install -r requirements.txt
python -m pytest tests/ -q
```

### Secrets, then deploy

Copy `functions-py/.env.example` to `functions-py/.env` and fill in
`GEMINI_API_KEY`. Push it to Secret Manager as a separate step before
deploying, never as part of the deploy:

```bash
python functions-py/scripts/push_secrets.py --project orbit-507316
firebase deploy --only functions:ingestion
```

The script writes each value to a temporary file with no trailing newline and
hands it to `firebase functions:secrets:set --data-file`, so the value never
reaches shell history and Secret Manager stores the exact bytes.

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
- LangGraph ingestion pipeline: cutoff filter, broadcast dedup, one LLM
  extraction call, company and round upsert, deterministic student matching
  with attachment fallback, and opt-in gating
- `syncNow` callable behind a 30 second per-student server-side cooldown, wired
  to pull-to-refresh on the drive list
- Per-drive tracking toggle on company detail

## Pending

- Renewing Gmail watches before their seven-day expiry
- A reconciliation sweep for mail missed while a watch was expired
- Requirement checkboxes, which is why `requirements[].id` exists already
- Push notifications (`fcmTokens` is modelled but never written yet)
- Firebase Hosting for the web admin dashboard
- Student-facing UI for setting your own stage on a drive
