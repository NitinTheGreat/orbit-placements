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

**Status:** not started

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
