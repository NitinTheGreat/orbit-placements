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

**Status:** not started

---

## Part D — new-company notifications, widget refresh, widget nudge

**Status:** not started

---

## Part E — chatbot

**Status:** not started

---

## Part F — re-verify sort order

**Status:** not started

---

## Needs your attention

Nothing yet.
