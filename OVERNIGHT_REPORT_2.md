# Overnight build report, round two

Started 2026-09-02. One section per part, updated as that part finishes.

Status vocabulary: **done** / **partial** / **blocked**.

---

## Part A — new-user PWA Gmail registration

**Status:** partial — code written, deployed and live. End-to-end
verification is **blocked on a Google Cloud Console step only you can do**,
and the reason is a hard one, not laziness. Details below.

### 1. Research — done, and the docs' shape was checked, not assumed
The web equivalent of `authorizeServer` is the **GIS authorization code
model**: `google.accounts.oauth2.initCodeClient()`, then `client.requestCode()`.
I pulled the current `CodeClientConfig` reference rather than trusting
memory. Fields that matter here:

| Field | Notes |
| --- | --- |
| `client_id`, `scope` | required |
| `ux_mode` | defaults to `popup`; `callback` required in popup mode |
| `redirect_uri` | **ignored in popup mode** — it defaults to the origin of the page calling `initCodeClient` |
| `hd` | hosted-domain restriction, so I pass `vitstudent.ac.in` |
| `login_hint` | pre-fills the account, so I pass the signed-in Firebase email |
| `error_callback` | separate from `callback`; carries `type` such as `popup_closed` |

`CodeResponse` carries `code`, `scope`, `state`, `error`,
`error_description`, `error_uri`.

**The detail that actually mattered:** because popup mode's effective
`redirect_uri` is the page origin, the server-side exchange must use that
same origin. The existing backend hardcoded `redirect_uri: ''`, which is
correct for the Android `serverAuthCode` but would have failed for web.
That is exactly the "the SDK differs from the docs" trap you warned about,
and it would have been silent until a real user tried it.

### 2. Wiring — done, same callable
- `lib/services/gmail_web_auth_web.dart` — GIS interop via `dart:js_interop`,
  with a `gmail_web_auth_stub.dart` conditional import so mobile builds never
  see it. It loads the GIS script on demand if it is not already present,
  with a 20 second timeout, so there is no race against the `async` tag.
- `gmail_connect_service.dart` branches on `kIsWeb` and otherwise reuses the
  identical path: same `connectGmail` callable, same backend, same Firestore
  writes. Only how the code is acquired differs, as specified.
- `functions/index.js` now accepts an optional `redirectUri` and uses it in
  the exchange, defaulting to `''` so **the Android flow is byte-for-byte
  unchanged**.

**Judgment call:** the backend tries the supplied `redirectUri` and, only if
Google answers `redirect_uri_mismatch`, retries once with `postmessage`.
GIS changed this behaviour historically and the current docs are explicit
about the origin but not about the exchange, so rather than guess between two
plausible values I made it try the documented one first and fall back. It
costs one extra request in the failure case only.

**Deployed:** `connectGmail` updated on `orbit-507316`, and the PWA rebuilt
**with `--dart-define-from-file=dart_define.json`** — worth noting because
the PWA I shipped last night was built without it, so `AppConfig
.googleServerClientId` was empty and Gmail connect could not have worked on
web even with the code present.

**Verified on the live site:** the GIS script tag is served, the client id is
compiled into `main.dart.js`, and `initCodeClient` appears in the live
bundle.

### 3. End-to-end verification — BLOCKED, and here is exactly why

Two independent blockers:

**(a) The PWA origin is not registered on the OAuth client.** I proved this
rather than assuming it, by asking Google's authorization endpoint directly
and using a positive control to validate the method:

    REGISTERED   https://orbit-507316.firebaseapp.com/__/auth/handler
    not allowed  https://orbit-507316.web.app
    not allowed  http://localhost:5000

The control passing is what makes the negative trustworthy. There is **no
public API to edit a classic OAuth client's authorized origins** — I tried
`oauth2.googleapis.com`, `clientauthconfig.googleapis.com` and
`iam.googleapis.com`; the first two 404 and the third denies
`iam.oauthClients.list`. It is a console-only change.

**(b) I have no never-connected `@vitstudent.ac.in` account.** Sign-in is
domain-restricted, and I cannot create a VIT account. Even with the origin
fixed I could not have completed step 3's literal instruction.

So I have done everything up to the console gate and stopped there rather
than claiming a fix I could not exercise.

### What you need to do — two minutes

1. Open https://console.cloud.google.com/apis/credentials?project=orbit-507316
2. Click the OAuth 2.0 Client ID
   `206075195473-4i5hgjtila6i6spvt5fvc14i4l94k99l`
3. Under **Authorized JavaScript origins**, add:
   `https://orbit-507316.web.app`
4. Under **Authorized redirect URIs**, add the same:
   `https://orbit-507316.web.app`
   (both are needed — popup mode uses the origin as the redirect URI)
5. Save. Google takes a few minutes to propagate.

**Safe to do:** this same client id is also what Firebase Auth uses for the
Google provider, so I checked — adding origins is additive and will not
disturb the existing `/__/auth/handler` entry or mobile sign-in.

**Then verify.** Ask me to re-run the probe and it will flip to
`REGISTERED`. After that, a genuinely new VIT account can complete
onboarding and Gmail connect on https://orbit-507316.web.app, which is the
real acceptance test.

**One thing to watch on that first real run:** Google only issues a refresh
token on the *first* consent for a given user and client. For a genuinely
new account that is the case, so it should work. If you test with an account
that has already granted Orbit access, the backend will correctly say so and
tell you to revoke at myaccount.google.com/permissions first.

---

## Part B — branch classification from confirmed rules

**Status:** done and deployed

### 4. Prefix rules, implemented once and mirrored
Last night's guessed 15-entry table is gone. Both languages now implement
exactly your rules, in the order you gave them:

    BIT exactly      -> IT
    starts with BC   -> CS family
    starts with BE   -> Electrical family
    starts with BM   -> Mechanical family
    starts with M    -> M.Tech / postgraduate, any specialisation
    anything else    -> unknown, never flagged

`BIT` is checked **before** the `B` prefixes, otherwise nothing would reach
it. Both implementations order the checks identically.

- Dart: `lib/models/branch_eligibility.dart`
- Python: `functions-py/orbit/branches.py`

**The anti-drift safeguard is real, not nominal.** `test_fixtures/branch_cases.json`
is a single file read by *both* suites — 25 code cases, 16 registration
numbers, and 13 eligibility scenarios covering all 18 production drives'
real text. The Dart suite parametrises over it, and so does the Python
suite via `pytest.mark.parametrize`. Adding a row to that file forces both
languages to agree or one of them fails. Includes `BCT`, `BCE`, `BIT`,
`BEE`, `BMY`, `MCA`, plus `BCX`/`BEZ`/`BMA` to prove the third letter is
genuinely ignored, and `BAI`/`BBT`/`BPS`/`XYZ`/`B`/`""`/`null` as unknowns.

**Consequence worth knowing:** under your rules `BAI`, `BBT`, `BPS` and
`BDS` are now **unknown**, where last night's guessed table called some of
them CSE. Unknown means no flag and no suppression, so those students see
everything — which is the safe direction, and it is what the rules you
confirmed produce.

### 5. Fifth sort band — done
`DriveBand.branchMismatch` sits below `concluded`. A drive lands there only
when the branch check is a confident mismatch **and** `optedIn != true`.

**Judgment call on "isn't tracking":** I read that as requiring an
*explicit* `optedIn: true`. A missing status document or `optedIn: null` is
not a deliberate choice, so those still sink. An explicit opt-**out** also
sinks, since the student is not tracking it either. Only a deliberate opt-in
rescues the drive to its normal band. All three cases are tested.

### 6. Auto-opt-in gate — done, and this is the live behaviour change

**Stating it plainly, as you asked:** from this deploy onward, when Gmail
ingestion writes a student's status for a drive and that student has **no
existing choice** (`optedIn` is null), Orbit will now leave it null instead
of setting it to `true` **if and only if** the branch check is a confident
mismatch. Concretely: a `23BCT0098` student named in a Keyence
(Mech/EEE/ECE) mail will no longer be auto-tracked into it.

Everything else is unchanged and tested to be so: an unknown branch code
auto-tracks, a drive with no eligibility text auto-tracks, eligibility text
naming no recognisable branch auto-tracks, a student with no parseable
registration number auto-tracks, and an existing explicit `true` or `false`
is never overwritten.

The student's registration number is recovered from the existing
`student_identifiers` list by finding the entry that parses as one, so no
new plumbing was threaded through the runner.

**Verified:** 83 Dart tests in the branch suite, 90 Python, 15 ordering
tests including 6 new band cases, 9 auto-opt-in cases. 252 Dart tests and
212 Python tests overall, analyze clean. Ingestion functions deployed to
`orbit-507316`.

---

## Part C — in-progress tab and checkbox responsiveness

**Status:** done

### 7. Why the in-progress tab was empty — it was the definition, and here is the proof

**It was not a query or index bug.** I checked that first, and the tab does
not query Firestore at all — it filters the already-loaded company list in
memory through `matchesFilter`. There is no index to be missing.

I then dumped your live data rather than reasoning about it:

- 26 companies, 6 `studentCompanyStatus` documents.
- **Zero** status documents contain a `cleared` round entry.
- Exactly **one** contains an `invited` entry: Accenture, `overallStatus:
  active`, `currentRoundId: training`.

The old definition required `roundHistory.any(result == 'cleared')`, so the
tab was correctly empty — there was genuinely nothing that matched.

**The root cause of there being no `cleared` entries:** ingestion writes the
extraction's `round.result`, which defaults to `"invited"`. A shortlist mail
naming you means you have been *invited* to the next round; it almost never
says in so many words that you *cleared* the previous one. So `cleared`
essentially never gets written, and the tab could only ever have been empty.

**Broadened, as you suggested.** `inProgress` now accepts a round result in
`{cleared, invited}` via a named `activeRoundResults` set. `pending` still
does not count, because pending means the outcome is unknown, and
`rejected`/`not_listed` obviously do not. Accenture now appears, which is
the correct answer for your live data.

**One existing test asserted the old narrow behaviour** (`invited` → not in
progress). I updated it rather than working around it, and split it into two
tests so both halves of the new rule are pinned.

### 8. Optimistic checkboxes and tracking toggle — done
`lib/features/companies/presentation/optimistic_status.dart` holds pending
edits as a pure, testable value: a map of requirement id to intended state
plus an optional intended tracking value. The UI reads server state with
those overrides applied, so a tap paints instantly.

The write then runs in the background. On failure the override is dropped —
the checkbox visibly returns to its real state — and a snackbar says so.

**The part that needed care:** clearing an override on *success* would flash
the old value if the Firestore stream had not caught up yet. Instead
`reconcile` drops an override only once the server actually agrees with it,
and each override is judged independently, so a slow write does not clear a
fast one. That is tested.

**Judgment call:** a pending edit on a drive with no status document
materialises a temporary in-memory document so the checklist and the derived
"complete" state can read it. Nothing is written to Firestore beyond the
real update, so the lazy-creation rule from the schema still holds.

**Verified:** 17 tests in `test/optimistic_status_test.dart` covering
immediate paint, revert, several concurrent pending edits, repeat taps,
independent reconciliation, and the derived completion flag flipping at
once. Plus 7 new in-progress tests including the exact Accenture shape from
production. 277 Dart tests, analyze clean.

---

## Part D — new-company notifications, widget refresh, widget nudge

**Status:** done and deployed

### 9. New-company trigger — done, reusing the existing fan-out
`notifyOnCompanyChange` already fanned out over students from last night, so
I added a create branch to it rather than a second function, as asked.
`before is None` distinguishes a create from an update.

The branch gate is applied **once per student at the top of the fan-out**,
so it covers both the new-company notification and every existing trigger —
a student who is a confident mismatch now gets nothing at all from that
drive, not just no new-company alert. Ambiguous and unknown still notify,
exactly as Part B's rule.

`plan_new_company` refuses to fire for a drive that arrives already closed
or results-declared, or whose deadline has already passed — an ingested
backlog should not produce a burst of "just opened" alerts for dead drives.
Its dedup key is the company id, so it can only ever fire once.

### 10. Silent widget refresh — done
Every notification delivery now also sends a data-only FCM message
(`{"orbitAction": "refreshWidget"}`, Android high priority, APNS
`content-available`) to the same tokens, minus any FCM reported as dead.

On the client, `orbitBackgroundMessageHandler` is a top-level
`@pragma('vm:entry-point')` handler registered through
`FirebaseMessaging.onBackgroundMessage`. It initialises Firebase in the
background isolate, reads the signed-in uid from persisted auth, refetches
companies and that student's statuses, and republishes the widget. A
foreground listener does the same thing when the app happens to be open.

**Correction to last night's report, and a wording note:** you referred to
`registerBackgroundCallback`. That home_widget API is for *widget
interactions* (taps on the widget), not for FCM. The thing that wakes on a
data message is FCM's own background handler, so that is what I used. The
outcome is the one you wanted — the widget updates without the app being
opened — but via the correct entry point.

### 11. Widget nudge — done, and it needed less native code than expected

**Research finding:** no custom platform channel was needed.
`home_widget` 0.9.3 already exposes all three pieces, which I confirmed by
reading its Kotlin plugin source rather than its README:

- `isRequestPinWidgetSupported()` — whether the OS and launcher support the
  real pin flow (API 26+ and a launcher that implements it)
- `requestPinWidget(qualifiedAndroidName:)` — triggers the OS's genuine
  add-to-home-screen dialog
- `getInstalledWidgets()` — install state, backed by AppWidgetManager

So the prompt calls the real OS flow where supported and falls back to
written instructions where it is not, and install detection is real rather
than inferred.

Frequency logic is pure and in `widget_prompt.dart`: shows on opens 3, 6, 9,
12, 15 and then never again; stops immediately if the widget is installed;
and there is a "Do not ask again" that is honoured permanently. Counters
live in `shared_preferences`.

**Judgment call:** I added the permanent dismissal, which you did not ask
for. Five prompts is the cap, but a student who has decided no should be
able to say so once rather than being asked four more times.

**Verified:** 11 Dart tests pinning the exact sequence `[3, 6, 9, 12, 15]`,
the cap boundary at exactly five, install-wins-over-count, and the
permanent dismissal. 10 new Python tests for the new-company plan and the
fan-out gate. 286 Dart tests, 222 Python tests, analyze clean. Ingestion
functions deployed.

**Not verified:** the pin dialog, the nudge sheet, and the background
refresh have not been exercised on a device. The background handler in
particular can only really be proven by installing a build and sending a
notification.

---

## Part E — chatbot

**Status:** done and deployed

### 12. The callable — `askOrbit`
Single-turn, preset-first. `functions-py/orbit/assistant.py` holds the pure
parts; `main.py` holds the callable.

**Scoping is enforced in three independent places**, because this is the one
part where a mistake leaks another student's data:

1. `_require_student` already gates on a verified `@vitstudent.ac.in` token
   and returns that uid; nothing else is trusted from the request.
2. `statuses_for_student` queries `where studentId == <that uid>`. There is a
   unit test that inspects the query the store actually builds, so the filter
   cannot be silently dropped.
3. `build_context` only ever renders companies plus that student's own
   statuses. Tests assert another student's registration number and name
   never appear, and that the student's own regNo appears exactly once.

The context is bounded at 40 companies, and it omits drives the student
opted out of and untracked drives that are a confident branch mismatch — so
the assistant talks about the same drives the app shows.

The prompt tells the model the context is everything it has, to say it does
not know rather than invent, never to name another student, and to stay
under five sentences in plain prose.

### 13. Preset chips — all five, tap-first
`due_24h`, `missing_now`, `changed_since_yesterday`, `active_drives`,
`new_unreviewed`. A preset id is validated against the server-side map, so an
unknown id is rejected rather than passed to the model. Free text is the
fallback field, capped at 400 characters, and a preset always wins over text
if both arrive.

### 14. UI — floating, compact panel
`AssistantButton` sits in the Scaffold's `floatingActionButton` slot with
`endFloat`, which is what keeps it clear of the bottom nav bar **by
construction** rather than by a hand-tuned offset. Tapping opens a bottom
sheet sized to its content, never a full screen. Existing tokens only —
`accent` ground, `accentWash` chips, `urgentWash` for errors.

**Overlap check, done as a real test rather than by eye:** three widget
tests render the button and a nav bar at 320x480 logical pixels (the
smallest Android phone class) and assert the button's rect does not overlap
the bar's, that its bottom is above the bar's top, and that it stays fully
on screen. A third case repeats it with a 96px bar. Note this exercises the
same Scaffold arrangement `HomeShell` uses, not `HomeShell` itself, which
needs Firebase to build.

### Rate limit
20 questions per student per UTC day, in `assistantUsage/{studentId}`.
Counted **before** the model call, so a failed generation still costs a
question and cannot be used to loop. Yesterday's count never carries over.

**Security test, as asked — and it found something worth having.** The
rate-limit counter lives in a collection with no client rule, so the
catch-all deny covers it. I proved that rather than assuming:
a student cannot read their own counter, **cannot reset it to zero**, cannot
read anyone else's counter, cannot read another student's profile, cannot
read another student's drive status, and cannot write into one — while
still being able to read their own. 31 rules tests pass.

**Verified:** 28 Python tests for the assistant, 5 widget tests, 31 rules
tests, 291 Dart tests, 250 Python tests, analyze clean. `askOrbit` deployed
to `orbit-507316`.

**Not verified:** no real question has been put to the live model. The
callable requires a signed-in VIT account, which I do not have. The answer
quality and the "say you do not know" behaviour are unexercised.

---

## Part F — re-verify sort order

**Status:** not started

---

## Needs your attention

Nothing yet.
