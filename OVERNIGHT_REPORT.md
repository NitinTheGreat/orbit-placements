# Overnight build report

Started 2026-09-02. One section per part. Each is updated as that part
finishes, not written at the end.

Status vocabulary: **done** / **partial** / **blocked**.

---

## Part A — independent UI fixes

**Status:** done

### 1. Tile name truncation
The name now takes the full tile width on its own line and wraps freely —
no `maxLines`, no ellipsis. The stage pill moved down into a `Wrap` under
the category line, which is what was squeezing the name before.

**Verified:** `flutter analyze` clean, 144 Dart tests pass. Longest real
company name in production is `Ethos Technologies (Ethos Life)` (31 chars).
**Assumed:** not yet seen rendered on a device.

### 2. List ordering
New pure function `orderDrives` in
`lib/features/companies/presentation/drive_ordering.dart`, four bands:
action needed → open with no action → everything else → concluded.

**Judgment call:** an in-progress drive that still has an outstanding
required step lands in the *action needed* band, not the "everything else"
band. Action needed is a student-facing urgency, so it outranks the drive's
own lifecycle stage. Tested explicitly.

**Judgment call:** concluded drives sort most-recent-deadline **first**
within their band, not oldest-first — a drive that closed yesterday is more
interesting than one from three months ago. Everything else is
soonest-deadline-first. Drives with no deadline sort last inside their band;
ties break on name.

**Verified:** 10 tests in `test/drive_ordering_test.dart`.

### 3. Branch-relevance hint
`lib/models/branch_eligibility.dart`.

**Verified against real data:** your regNo in Firestore is `23BCT0098`, so
the branch code is characters 2–5 (`BCT`) — two year digits, three branch
letters, four serial digits. The parser requires that exact shape and
returns null for anything else.

**Verified against real data:** the matcher was written against the actual
`eligibleBranches` strings in your 18 production companies, and those exact
strings are in the tests — Keyence's `B.Tech Mech,EEE,ECE related branches`,
Kinaxis's three role-scoped entries, WinWire's `CSE/IT/AIML/DS` list,
Urban Company's `All B.Techs (except CS/IT Related)`.

Safety rules, all tested: unknown branch code → no flag; empty
`eligibleBranches` → no flag; text naming no recognisable branch → no flag;
an exclusion clause naming nothing recognisable → no flag; any single entry
that admits you wins over every entry that doesn't. Only a confident
mismatch mutes the tile and adds the `Not open to your branch` tag. The
drive is never hidden.

**NEEDS YOUR ATTENTION — the code-to-name table.** I could not verify the
branch-code meanings empirically. I tried: the shortlist spreadsheets
attached to your placement mail are keyed by **NeoID only**, with no regNo
and no branch column, so there was no ground truth to derive the mapping
from. The table in `vitBranchCodes` is written from general knowledge of
VIT's registration-number scheme and is deliberately easy to edit.

The entry that matters most is **`BCT` → Computer Science and Engineering
(`BranchFamily.computerScience`)** — that is your own code, and it decides
every flag you personally see. If BCT is not a CSE-family branch, change
that one line. Codes not in the table are treated as unknown and never
produce a flag, so a missing entry is harmless; only a *wrong* entry is
dangerous.

### 4. Logo and launch animation
**Judgment call:** you said `logo_final.png`, and no file by that name
existed. The repo root had `logo.png` and `new logo final.png`. I took
`new logo final.png` (the orbit ring with the comet on the dark navy tile)
and copied it to `assets/brand/logo_final.png`. The old `assets/icon/`
folder and both `orbit_icon*.png` files are deleted; nothing references
them any more.

`assets/brand/logo_final_foreground.png` is a transparent-background
version I generated from it by masking on distance from the tile's
background colour, then re-cropping and padding to the adaptive-icon safe
zone. Used for the adaptive icon foreground, the monochrome layer, the
native splash bitmap, and the in-app entrance.

Launcher icons regenerated with flutter_launcher_icons 0.14.4 — I checked
the key names against the installed package's `config.dart` rather than
trusting the README. Adaptive background is now the flat brand navy
`#11152A` instead of an image.

Native cold-start splash: `launch_background.xml` (and the v21 variant) now
paint `#11152A` with the mark centred, at five densities. Android 12+ gets
`values-v31` and `values-night-v31` with `windowSplashScreenBackground` and
`windowSplashScreenAnimatedIcon`, because the system splash on API 31+
ignores `windowBackground`.

In-Flutter entrance: `lib/core/widgets/launch_curtain.dart`, mounted in the
`MaterialApp.router` builder. The navy ground carries over from the native
splash so there is no colour jump; the mark settles in with a spring scale
and a slight counter-rotation, then pushes past the viewer — scaling up and
fading while the whole ground lifts away to reveal the app. It removes
itself from the tree when finished, and is skipped entirely when the OS
asks for reduced motion.

**Verified:** analyze clean, 144 tests pass, Android resources compile.
**Assumed:** the visual timing has not been watched on a device.

---

## Part B — bottom navigation and profile

**Status:** done

Four destinations in `lib/features/home/presentation/home_shell.dart`,
mounted at `/companies` in place of the bare list screen. The bar is built
from the existing tokens — `surfaceRaised` ground, `accentWash` pill behind
the active item, `accentInk` and `inkFaint` for the two states. No new
colours anywhere in this part.

- **Drives** — the existing screen, chips untouched.
- **Open now** — the same `CompanyListScreen`, locked to
  `CompanyStatus.registrationOpen`, chip switcher hidden.
- **Shortlisted** — same component, locked to `inProgress == true` or
  `overallStatus == 'selected'`.
- **Profile** — name and NeoID from onboarding, drives-tracked count,
  requirements-completion rate, and a `fl_chart` donut of the status split
  with a labelled legend. Sign out moved here from the drives header, which
  is where it belongs now that there is a profile.

The list screen took one parameter (`lock`) rather than being copied, so all
four list tabs share one code path, one pagination controller, and one
ordering pass.

**Judgment call:** "Open now" reads the drive's own `status` field, not the
deadline. A drive whose deadline has passed but which the placement cell has
not closed still appears — because the source of truth for "can I still
register" is what the mail said, and a passed deadline with an open status
usually means an extension. Tested explicitly.

**Judgment call:** the selected tab and the chip filter live in
`home_state.dart` as top-level notifiers rather than widget state, so they
survive opening a drive and coming back. That is what "persist for session"
needs, since the shell is rebuilt on that return trip.

fl_chart 1.2.0 added as a dependency.

**Verified:** 15 new tests in `test/profile_stats_test.dart` covering the
tracked count with and without a status doc, the completion rate over
required steps only, the empty case, every breakdown slice and its priority
order, and both locked tabs including the opted-out-but-selected edge.
`flutter analyze` clean, 159 Dart tests pass.
**Assumed:** not yet seen rendered on a device — chart sizing and bar
spacing are unverified visually.

---

## Part C — Android home-screen widget

**Status:** done, with one honest caveat about refresh timing

**Verified before building:** `home_widget` 0.9.3 is current on pub.dev and
requires Flutter >= 3.38.1 against our 3.47.2. I read the installed
package's own source for the API (`saveWidgetData`, `updateWidget` with
`qualifiedAndroidName`) and copied the receiver/provider wiring from its
example rather than from memory.

`OrbitWidgetProvider` extends the plugin's `HomeWidgetProvider`, renders a
`RemoteViews` layout on the brand navy with the mark, a headline, and up to
two rows. Tapping anywhere opens the app.

Content rules live in `lib/features/companies/presentation/widget_feed.dart`
as a pure function so they are testable without Android: shortlisted or
selected drives first (up to two, headline "You are through"), otherwise
registration-open drives not yet opted into (headline "Open now"), soonest
deadline first in both cases, concluded drives never shown.

### The refresh caveat — read this one

**Update on app foreground works** and is what the widget actually relies
on: `WidgetRefresher` observes the app lifecycle and republishes on every
resume.

**True background refresh is not reliable and I have not claimed it works.**
The `appwidget-provider` sets `updatePeriodMillis` to 30 minutes, but
Android treats that as a floor of 30 minutes and freely ignores it under
Doze, battery optimisation, and OEM task-killers — which on Indian OEM
skins (Xiaomi, Realme, Oppo, Vivo) is aggressive. Worse, that system update
only re-renders whatever the plugin last wrote to `SharedPreferences`; it
does **not** re-read Firestore, because nothing runs Dart. So between app
opens the widget can show stale data and there is no fix inside this
plugin's model. Making it genuinely live needs either a WorkManager job
calling back into a Dart isolate (`registerBackgroundCallback`) or an FCM
data message that triggers a widget update — the FCM route is the better
one and Part E is already putting that pipeline in place.

**Verified:** 8 tests in `test/widget_feed_test.dart` covering the
shortlisted-wins priority, the selected case, the opted-into exclusion, the
two-slot cap, ordering, concluded exclusion, and both line formats. A debug
APK builds clean, so the provider, layout, XML and manifest receiver all
compile.
**Assumed:** the widget has not been placed on a real home screen. Layout
sizing at different widget dimensions is unverified.

### iOS
Not attempted, per your instruction that the iOS widget rides on Part H.

---

## Part D — "not shortlisted" detection

**Status:** done (code and tests; **not yet deployed** — see below)

### 7. rosterType
`roster_type` added to `RoundInfo` in the extraction schema, and the system
prompt now spells out the gate: null unless the email carries a list of
students, `complete_final` only when the email's own words frame the list as
definitive and entire ("final shortlist", "the following students only",
"no further additions"), and `partial_or_unclear` for anything else —
explicitly including "additional shortlist", "first list", "more names to
follow", and a bare list with no framing. The prompt ends with "when in any
doubt, choose partial_or_unclear".

### 8. The not_listed gate
New `not_listed_check` node. `match_student` no longer halts on a miss; it
routes there instead, and the node halts with a specific reason so you can
see in the logs exactly why a roster did or did not produce a write. All
four conditions must hold, each tested:

| Condition | Halt reason if it fails |
| --- | --- |
| `roster_type == 'complete_final'` | `roster_not_final`, or `student_not_named` when there is no roster at all |
| a round was identified for this mail | `no_round_for_roster` |
| a prior `studentCompanyStatus` doc exists | `no_prior_engagement` |
| that doc has at least one `roundHistory` entry | `no_prior_engagement` |

**Judgment call — two guards I added that you did not ask for.** Both are in
the "a false not-shortlisted is worse" direction:

1. A student who has opted out is skipped (`opted_out`). Writing a rejection
   into a drive they explicitly stopped tracking would be noise at best.
2. If the student is already recorded as `cleared` for this exact round, the
   write is skipped (`already_cleared`) rather than downgrading them. A
   later mail claiming to be the complete final list for a round the student
   has already cleared is more likely a mis-extraction than a real reversal.

### 9. overallStatus derivation
`not_listed` on the **highest-order round** resolves `overallStatus` to
`rejected`, which ends active tracking. On an earlier round it does not —
tracking continues, since a student can be added to a later round. The
stored `roundHistory` result stays the distinct string `not_listed`, so the
wording can be softened or audited later without a schema change.
`resolve_current_round_id` skips `not_listed` entries the same way it skips
`rejected` ones.

### 10. UI
`RoundResult.notListed` added on the Dart side, and a `notShortlisted`
outcome tag that renders in exactly the same urgent red as `rejected`.

**Ambiguity I had to resolve:** you wrote both "'Not shortlisted' text" and
"the distinction from 'rejected' is data-model-only, not user-facing yet".
Those pull in opposite directions, since different text *is* user-facing. I
read the second sentence as ruling out a different *visual treatment*, not
different wording, so: same red, but the tag reads "Not shortlisted" for a
roster miss and "Not selected" for an explicit rejection. If you meant them
to read identically, change the one `DriveOutcomeTag.notShortlisted` case in
`stage_pill.dart`.

**Verified:** 14 new Python tests in `functions-py/tests/test_not_listed.py`
(81 Python tests total), 5 new Dart tests, 178 Dart tests total, analyze
clean.

**NEEDS YOUR ATTENTION — not deployed.** The Python changes are committed
but I have not pushed them to Cloud Functions. Deploying changes live
ingestion behaviour on real mail, and a bad `complete_final` classification
writes a rejection into a real student's record. I would rather you say go.
Deploy with:

    cd functions-py && firebase deploy --only functions --project orbit-507316

---

## Part E — notifications

**Status:** done (code and tests; **not yet deployed** — same reason as Part D)

### 11. FCM token registration
**Checked first, as asked:** `fcmTokens` already existed on the `Student`
model and in `toFirestore` from the original schema work, but nothing ever
wrote to it and no messaging plugin was installed. So the field was
scaffolding only — I built the rest.

`lib/services/push_service.dart` requests permission, reads the token,
writes it with `arrayUnion` so multiple devices accumulate, and subscribes
to `onTokenRefresh`. Driven from `SessionController`: registration starts
when a student profile loads, and sign-out removes that device's token and
deletes it. Every step is wrapped so a permission refusal or a missing
Play Services never breaks sign-in. `POST_NOTIFICATIONS` added to the
manifest for Android 13+.

Two Android channels are created client-side, matching the ids the server
sends to: `orbit_updates` (default importance) and `orbit_deadlines` (max
importance).

### 12–13. Triggers
The comparison logic is a pure function, `plan_notifications` in
`functions-py/orbit/notifications.py`, taking before/after for **both** the
status doc and the company doc. All four triggers:

- `action_needed` on a false→true flip
- `deadline_hour` when action is still needed and the deadline is inside one
  hour — Android high-importance channel with `priority: high`, iOS
  `apns-priority: 10` and `interruption-level: time-sensitive`
- `round_result` when an entry changes to cleared, rejected, or not_listed
- `new_round` when `currentRoundId` moves to a round with no prior history

**Judgment call — I wired two triggers, not one.** You specified the trigger
on `studentCompanyStatus`. Built exactly that way, the feature would have
been mostly dead: both examples you gave for the action-needed flip (a new
drive needing action, a required item reopening a completed one) are changes
to the **company** document, not the status document. Worse, a brand-new
drive has *no* status doc at all — creation is lazy by Part B's design — so
there is nothing to trigger on. I therefore added `notifyOnCompanyChange`
alongside `notifyOnStatusChange`; both call the same pure planner. The
company trigger fans out over students, which is fine at this cohort size
but is the thing to revisit if Orbit ever has thousands of users.

**Judgment call:** a student who has opted out of a drive gets nothing at
all from it.

### 14. Dedup
A `notificationLog/{studentId}_{companyId}` document holds the keys already
sent. Each notification carries a key that encodes its state, so repeats are
impossible while the state holds but a genuine change produces a new key:

- action needed → the sorted set of outstanding required ids, so completing
  one step and having another added later is a new notification, while the
  same outstanding set never re-fires
- deadline hour → the deadline timestamp, so one crossing sends once and an
  extended deadline is a fresh crossing
- round result → round id plus result, so a correction re-fires but a repeat
  write does not
- new round → the round id

The log is capped at the most recent 200 keys per drive. Tokens that FCM
reports as unregistered are removed from the student document automatically.

**Verified:** 29 tests in `functions-py/tests/test_notifications.py` covering
every flip direction, every non-firing case, all four triggers, the urgent
tier's window boundaries, and dedup. 110 Python tests total, 178 Dart tests,
analyze clean. I also constructed both message shapes against the installed
`firebase_admin` 7.5.0 and printed them to confirm the channel ids,
priorities and APNS headers come out right, rather than trusting the field
names.

**NEEDS YOUR ATTENTION — three things**

1. **Not deployed.** Same caution as Part D: `firebase deploy --only
   functions` will start sending real push to your device.
2. **iOS time-sensitive needs an entitlement.** The
   `com.apple.developer.usernotifications.time-sensitive` entitlement is not
   in the project, because there is no signed iOS build to put it in. On
   iOS the urgent tier will arrive as a normal high-priority alert until
   that exists. Android's high-importance channel works today.
3. **APNs is not configured in Firebase.** Even with the entitlement, iOS
   push needs an APNs key uploaded to the Firebase console, which needs the
   Apple Developer account discussed in Part H.

---

## Part F — App Check, monitoring mode

**Status:** done, enforcement deliberately left off

### 15. Client
`firebase_app_check` 0.4.7 added and activated in `main()` before `runApp`.

**Verified against the installed package, not the docs:** the `activate`
call's `androidProvider`/`appleProvider` parameters are deprecated in this
version, so I used the current `providerAndroid`/`providerApple` with the
provider classes — `AndroidPlayIntegrityProvider` and
`AppleAppAttestWithDeviceCheckFallbackProvider` in release,
`AndroidDebugProvider`/`AppleDebugProvider` under `kDebugMode` so debug
builds keep working. The whole call is wrapped so a failure to attest never
stops the app launching.

### Server side, done through the service account
- Enabled `firebaseappcheck.googleapis.com`, which was not enabled on the
  project. Enabling the API does not enforce anything.
- Registered the Play Integrity provider for the Android app
  (`com.nitin.orbit`), 1 hour token TTL.
- Registered App Attest for the iOS app, same TTL.

### 16. Enforcement — confirmed OFF
I queried each service individually rather than assuming. All four report
no enforcement config, which is `UNENFORCED`:

    firestore.googleapis.com          UNENFORCED
    firebasestorage.googleapis.com    UNENFORCED
    identitytoolkit.googleapis.com    UNENFORCED
    cloudfunctions.googleapis.com     UNENFORCED

Nothing will be blocked. Tokens will start appearing in the App Check
metrics once a build with this change runs on a device, which is what gives
you the traffic data to decide from.

**NEEDS YOUR ATTENTION — do not flip enforcement on for this app yet, and
here is a reason beyond caution.** Play Integrity attestation requires the
app to be registered with Google Play and linked to the Firebase project.
Part G ships a sideloaded APK from a GitHub Release, which is *not*
distributed through Play. Sideloaded installs will therefore likely fail
attestation and produce zero valid tokens. If you turn enforcement on before
the app is on Play, you will lock yourself and every friend out of Firestore
entirely. Watch the metrics first — that is exactly what the unenforced mode
is for.

---

## Part G — Android release

**Status:** not started

---

## Part H — iOS, best effort

**Status:** not started

---

## Part I — mid-session additions

Requested while the session was running, after Part B was pushed:

1. Greeting alias — name `Guneet` or regNo `23BCT0210` greets as `Ms Aurora`.
2. One-time NeoID edit from the profile, with a warning that it is one time
   only.
3. iOS distribution — evaluate AltStore/Sideloadly sideloading and a PWA,
   with a working PWA as the floor if nothing else lands.

**Status:** 1 and 2 done, 3 folded into Part H.

### 1. Greeting alias — done
`lib/models/display_name.dart`. Matches on either the regNo `23BCT0210` or
the name token `guneet`, case-insensitively.

**Judgment call:** I match on *tokens*, not on a prefix, because the stored
names in your Firestore include the regNo inline — yours is literally
`Nitin Kumar Pandey 23BCT0098`. So the regNo is found whether it arrives in
the `regNo` field or embedded in the name, and `Guneeta` does **not** match
`Guneet`. Both are tested.

**Judgment call:** the alias applies to the profile heading as well as the
greeting, not just the `Hello,` line — otherwise the profile tab would still
say Guneet and give it away.

Also fixed while there: `firstNameOf` now skips a leading registration
number, so a student stored as `23BCT0098 Nitin` is greeted `Hello, Nitin`
rather than `Hello, 23BCT0098`.

### 2. One-time NeoID edit — done
A NeoID card on the profile shows the value, explains that shortlists are
matched on it, and offers `Change` only while it has never been edited.
The dialog states plainly that this is the one time it can change and that
the field locks afterwards. Once used, the card shows a lock icon and the
line "Already corrected once, so this is locked now."

Enforced server-side, not just in the UI: `students/{uid}` update now
permits a `neoId` change only when the document has no `neoIdEditedAt` and
the write sets both `neoId` and `neoIdEditedAt` and nothing else.

**A rules test caught a real hole here.** My first version used only
`hasOnly(['neoId','neoIdEditedAt'])`, and because `hasOnly` is satisfied by
a subset, a client could have changed `neoId` alone, never written the
stamp, and edited it unlimited times. Added `hasAll` alongside it. Without
that test the one-time lock would have shipped doing nothing.

**Verified:** 24 rules tests pass against the Firestore emulator (7 of them
new, covering the first edit, the missing stamp, the second attempt, an
empty value, smuggling `regNo` in alongside, unrelated profile edits still
working, and another student trying it). Rules deployed to `orbit-507316`.
6 Dart tests for the alias. analyze clean, 173 Dart tests pass.

---

## Needs your attention

Nothing yet.
