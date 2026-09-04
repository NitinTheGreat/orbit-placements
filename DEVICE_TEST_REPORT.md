# Device test session

Started 2026-09-05.

Result vocabulary: **PASS** / **FAIL-FIXED** / **FAIL-PENDING-DEPLOY** /
**BLOCKED-BILLING** / **BLOCKED-NO-DEVICE**.

---

## Part 0 — Setup

**Status: PASS** (after you enabled USB debugging). Device
`10BD1R00760005L`, iQOO Neo7 (I2214), Android 16, 1080x2400 @ 440dpi, one
authorized device.

`stay_on_while_plugged_in` was **0** originally, set to 3 for the session, and
**restored to 0** at the end, confirmed by reading it back.

### Original blocker, kept for the record
**Was BLOCKED-NO-DEVICE.** The phone is plugged in and Windows sees it,
but it is not exposing an ADB interface, so `adb devices` is empty. This is
not an authorization prompt — there is nothing for ADB to talk to.

    $ adb devices -l
    List of devices attached
    (nothing)

The phone enumerates as exactly two USB interfaces:

    USB\VID_2D95&PID_6002\10BD1R00760005L          USB Composite Device
    USB\VID_2D95&PID_6002&MI_00\...                USB Mass Storage Device
    USB\VID_2D95&PID_6002&MI_01\...                iQOO Neo7   (class WPD)

`MI_00` is vivo's driver CD gadget and `MI_01` is MTP file transfer. An
ADB-enabled vivo/iQOO enumerates an **additional** interface and normally a
different product id; `PID_6002` is the charge/MTP composite with no ADB
function. Restarting the ADB server made no difference, and no device ever
appeared as `unauthorized`, which is what an unaccepted prompt would look
like.

**So: USB debugging is not active over this cable.** See "Needs your
attention" for the exact steps.

Because every one of Parts 1, 3 and 4 requires the device, they are all
blocked. I did the work that does not need it — see Parts 1 (build only),
2 (server baseline) and 5 below — rather than idling.

---

## Part 1 — Fresh build

**Status: PASS.** `adb install -r` succeeded over the installed v1.0.0 with no
signature rejection and **no uninstall**, so the Gmail connection survived.
Reinstalled three more times as fixes landed.

Round-3 elements confirmed running: the **channel tag** on tiles, the
four-destination nav, and the Ask Orbit button.

### Build artefact

`build/app/outputs/flutter-apk/app-release.apk`, 60.3 MB, built 5 September
from the current tree, so it contains everything from rounds 2 and 3 **plus**
the notification deep link added in this session.

The debug keystore at `~/.android/debug.keystore` is the same one that signed
the installed v1.0.0, so `adb install -r` should update in place without an
uninstall. I have not run it, because there is no device to run it against.
Nothing has been uninstalled and the Gmail connection is untouched.

Install is one command the moment ADB works:

    adb install -r build/app/outputs/flutter-apk/app-release.apk

---

## Part 2 — What is actually up

**Status: done.** Determined empirically from this machine, not inferred.
Every later device failure must be classified against this.

| Subsystem | Verdict | Evidence |
| --- | --- | --- |
| Firestore read | **WORKING** | streamed 50 company documents |
| Firestore write | **WORKING** | wrote and deleted a scratch config doc |
| `syncNow` | **DOWN-DUE-TO-BILLING** | see below |
| `askOrbit` | **DOWN-DUE-TO-BILLING** | see below |
| `connectGmail` | **DOWN-DUE-TO-BILLING** | see below |
| Scheduled ingestion | **DOWN-DUE-TO-BILLING** | Google says so verbatim |

### The callables are serving errors, not auth errors
A healthy Firebase callable answers an unauthenticated POST with a JSON
`UNAUTHENTICATED`. All three instead return Google's own HTML error page:

    503 Server Error — The service you requested is not available yet.

Cloud Run's own view of the service is *healthy*:

    RoutesReady:         CONDITION_SUCCEEDED
    ConfigurationsReady: CONDITION_SUCCEEDED
    terminalCondition:   Ready / CONDITION_SUCCEEDED

So the revision is fine and deployed; the platform simply will not schedule a
container. That is the billing-disabled signature, not a code fault.

### Scheduled ingestion is gone, in Google's words
The two Cloud Scheduler jobs (`reconcileInboxes` every 2 hours,
`renewGmailWatches` daily) no longer list at all:

    GET cloudscheduler/v1/projects/orbit-507316/locations/us-central1/jobs
    403 "This API method requires billing to be enabled. Please enable
         billing on project #orbit-507316 ..."

### Nothing has run since 4 September
Last log entry from any function:

    connectgmail             2026-09-04T21:19:57Z
    ingestgmailnotification  2026-09-04T21:14:01Z
    reconcileinboxes         2026-09-04T20:08:22Z
    syncnow                  2026-09-04T19:56:30Z

Nothing at all on 5 September. **Ingestion has been stopped for roughly a
day**, so any new placement mail since then has not been picked up. That
backlog will be processed once billing is restored and the watch is renewed —
though note the Gmail watch itself expires on a 7-day cycle, so if billing
stays off long enough `renewGmailWatches` will miss its window and the
connection will need re-establishing.

**Consequence for this session:** Ask Orbit, pull-to-refresh and Gmail
connect *cannot* work on the device no matter what the client does. Those
items are pre-classified **BLOCKED-BILLING** rather than being chased as
client bugs.

---

## Part 3 — The nine items on device

| # | Item | Result |
| --- | --- | --- |
| 7 | Ask Orbit | **FAIL-FIXED** + BLOCKED-BILLING |
| 8 | Shortlisted | **PASS**, one path unexercisable |
| 9 | Open now | **PASS** |
| 10 | Channel tags | **PASS** |
| 11 | Profile breakdown | **PASS** |
| 12 | Action needed / In progress | **FAIL-FIXED** |
| 13 | Selected empty | **PASS** |
| 14 | Ordering and colour | **PASS** |
| 15 | M.Tech suppression | **PASS** |

### 12. Action needed and In progress, a real bug found and fixed
`03-in-progress.png`: **In progress was empty** while the student had two
qualifying drives. Not a stale-clock artefact.

**Root cause.** The drives list pages 20 at a time and there are now **76**
company documents, but the tabs filtered only the *loaded* page. The matches
sat past page one, so the tab rendered empty, and because an empty list cannot
be scrolled the loader never fired again. It would have stayed empty forever.
The profile chart had the identical fault.

**Fixed** in `a4213bb`: a narrowed view keeps pulling pages until the
collection is exhausted, showing a spinner rather than an empty state
meanwhile; the profile reads the full company stream.

**Re-verified on device** (`04`, `11`): In progress shows Cognizant and
Accenture; Action needed shows 5 drives, matching the profile count exactly.

**I corrected my own reading here.** I first believed four drives should be in
progress, from EY GDS and Goldmansachs documents. Querying as the app does
showed **six students now use Orbit** (18 status docs across 6 uids); those two
belong to other students. For this student exactly two qualify.

**Action needed being small is correct**, checked against real deadlines: every
other open drive has passed its deadline, and the only open drive with a future
one (FlamAI, 7 Sep) is M.Tech-only and correctly suppressed.

### 9. Open now, PASS
`07`, `08`. **WinWire (Part of NTT DATA) is absent** as required, its status
still `registration_open` but its deadline 1 Sep. The sixteen other stale-open
drives are likewise absent.

### 15. M.Tech suppression, PASS
`08`. **FlamAI** and **Haleon** render dimmed, carry **Not open to your
branch**, and sit at the bottom. The client-side gate works on device even
though the server half cannot deploy.

### 10. Channel tags, PASS
Three distinct values on tiles: **Multiple steps**, **NeoPAT**, **Google
Form**. Also on the detail header (`15`) beside the stage pill.

### 11. Profile, PASS
`10`. **5 + 1 + 20 + 35 = 61 = the tracked count.** Four slices, not one.
Branch reads Computer Science and Engineering. The NeoID card renders with its
warning; **I did not tap Change**.

In progress is 1 here and 2 in the tab because an outstanding step outranks
in-progress in the chart priority, so Cognizant counts under Action needed.
Documented ordering, not a discrepancy.

### 13. Selected, PASS and empty for the right reason
Confirmed in Firestore: **no document for this student carries
`overallStatus: selected`**. The filter is right; there is nothing to show.

### 8. Shortlisted, PASS with one path unexercisable
`09`. Cognizant (red rail, Closes tomorrow) and Accenture (muted rail, Closed
3 Sep). Urgency colours read correctly.

**Honest gap:** neither shortlisted drive sits on a *concluded* company, so the
concluded de-emphasis from round 3 never rendered. Unit-tested, unverified on
device.

### 14. Ordering and colour, PASS
`11` shows action-needed sorted urgency-first, two Closes today ahead of Closes
tomorrow. Bands hold across the list. One urgency scale on rails and deadline
text, one outcome scale on pills, one neutral chip for channel and off-branch
tags. No conflicting scales seen.

### 7. Ask Orbit, FAIL-FIXED then BLOCKED-BILLING
`12` shows the panel: compact, chips in a **horizontal row** (the round-3 fix),
input pinned.

**Bug found:** with the backend down the panel showed the literal string
**INTERNAL** to the student (`14`), a raw Firebase error code.

**Fixed** in `23dd74c`, re-verified on device (`25`): it now reads *Orbit
cannot reach the server right now. This is on our side, not yours.*

**Still BLOCKED-BILLING:** no answer can be obtained, so the long-answer scroll
check and the refuses-to-invent check could not be performed.

---

## Part 4 — Everything never seen on a device

### 16. Launch animation and splash, PASS with pixel proof
`launch-f3.png` caught the splash. I sampled pixels rather than eyeballing:

    launch-f3 background     = (17, 21, 42), uniform across the screen
    declared brand navy      = #11152A = (17, 21, 42)

Exactly equal, so **there is no colour jump** between the native splash and the
Flutter curtain. `launch-f4` shows the blend as the curtain lifts.

### 17. Optimistic checkbox, PASS and reverted
`17` was captured immediately after the tap with no sleep: already filled. The
paint does not wait for the network.

**Reverted.** The first revert tap did not register, `19` still showed it
ticked and Firestore still held the id. A second tap cleared it. The final
integrity check shows the only remaining completions (Keyence, Face Prep) are
**yours, pre-existing and untouched**.

That one swallowed tap happened while the optimistic state was reconciling.
Seen once, not reproduced deliberately, so I report it as an observation rather
than a diagnosed bug.

### 18. Widget, PASS
`26`. Already on the home screen, and `dumpsys appwidget` confirms a live
instance with bound RemoteViews. It renders:

    (orbit mark)  You are through
    Cognizant     Registration
    Accenture     Training

Exactly the documented rule, shortlisted first and at most two, and it agrees
with the In progress tab. **Not done:** I did not resize it, so only one size is
evidenced. I went nowhere near Do not ask again.

### 19. Longest company name, PASS
**RFPIO India Pvt. Ltd (DBA Responsive)** and **Haleon (formerly GSK Consumer
Healthcare)** both wrap to two lines and are not cut (`07`, `08`, `15`).

### 20. Pull-to-refresh, FAIL-FIXED then BLOCKED-BILLING
The gesture runs and the list re-renders (`23`). `syncNow` cannot succeed.

**Bug found by reading the code path:** `SyncService` surfaced `error.message`,
which for an infrastructure failure is the literal **INTERNAL**, the same fault
as Ask Orbit. Fixed in the same commit by routing both through one shared
helper. Last checked correctly did not advance.

---

## Part 5 — Fixes

Three fixes, each committed and pushed separately and re-verified on device:

| Commit | Fix | Re-verified |
| --- | --- | --- |
| `a4213bb` | tabs and profile filtered only one page of 76 | `04`, `11` |
| `23dd74c` | Ask Orbit showed the raw code INTERNAL | `25` |
| `23dd74c` | pull-to-refresh had the same fault | shared code path |

Nothing needed a function deploy, so there is no FAIL-PENDING-DEPLOY item.

### Notification tap opens the drive — done, shipped in this APK
You asked for this at the end of the brief and it needs no device to build.

The server already includes `companyId` in every notification's `data`
payload (`push.py` `build_message`), so nothing had to change on the server —
which is fortunate, since nothing server-side can deploy right now.

`lib/services/notification_route.dart` extracts the company id;
`PushService` listens to `onMessageOpenedApp` **and** checks
`getInitialMessage()` so a notification that launched the app from cold is
handled too; `main.dart` performs the navigation.

**One thing that needed care.** A cold start delivers the tap before the
session is ready, and `resolveRedirect` bounces any non-ready user away from
`/companies/:id` — so navigating immediately would silently swallow it. The
tap is therefore *remembered* and replayed once the session reaches `ready`.
`main.dart` listens to both the pending value and the session.

**Judgment call:** the silent widget-refresh message also carries a
`companyId`, and it must never yank the user to a screen. It is explicitly
excluded as a tap target.

**Verified:** 10 tests covering all five server triggers as tap targets, the
widget-refresh exclusion, blank/non-string/missing ids, trimming, and that
listeners fire exactly once per tap. 408 Dart tests, analyze clean.
**Not verified:** no notification has been tapped on a device — and it cannot
be, because sending one requires the notification functions, which are down
for billing.

---

## Needs your attention

### Enable USB debugging so the session can run

On the iQOO Neo7:

1. **Settings → About phone → Software version**, tap it 7 times to unlock
   Developer options (skip if already unlocked).
2. **Settings → System management → Developer options**, turn on
   **USB debugging**.
3. On vivo/iQOO specifically, also turn on **USB debugging (Security
   settings)** if present, and set **Default USB configuration** to
   *File transfer* rather than *Charging only*.
4. Unplug and replug the cable. A dialog **"Allow USB debugging?"** should
   appear — tick *Always allow from this computer* and accept.

Then tell me, and I will re-run `adb devices` and continue from Part 1.

**Resolved during the session; everything below it ran.**

### Billing, since you asked how it worked earlier and not now

**It did work earlier, and I have the timestamps.** Functions deployed
successfully on 2 September, and the last execution of any function was
**2026-09-04 21:19**. Nothing since.

I re-checked with the same project and identity I deployed with:
`orbit-507316`, project number 206075195473, service account
`claude-code@orbit-507316.iam.gserviceaccount.com`, state ACTIVE. Not the wrong
place.

What I can prove:

- `billingEnabled: false` while `billingAccountName` is **still**
  `billingAccounts/018BC3-AA2EB7-BCDCD5`. Had the project been *unlinked* that
  name would be empty. Present-but-disabled is the signature of the **billing
  account itself** closing, not of a project change.
- Cloud Scheduler answers `403 This API method requires billing to be enabled`,
  and both jobs have vanished from the listing.
- Secret Manager answers the same on deploy.
- `syncNow` returns `503 The service you requested is not available yet`
  consistently across three attempts over 40 seconds, with a valid bearer
  token, and against the direct `*.run.app` URL bypassing the alias, while
  Cloud Run reports the revision `Ready / CONDITION_SUCCEEDED`. Deployed and
  healthy, but no container will be scheduled.
- No audit entry for a billing change exists **in this project**, which is
  expected: closing a billing account is recorded on the billing account
  resource, not the project.

What I cannot see: the billing account returns `PERMISSION_DENIED` to the
service account, so I cannot tell you *why* it closed. Usual causes are a
free-trial or credit expiry, or a failed payment. **Only you can see that**, at
https://console.cloud.google.com/billing/linkedaccount?project=orbit-507316

**One time-sensitive consequence:** the Gmail watch renews on a seven-day cycle
and `renewGmailWatches` is dead. If billing stays off past that window the watch
lapses and Gmail needs reconnecting rather than simply resuming. Ingestion has
already missed about a day of mail.

### Data quality worth a pass of its own
Duplicates have multiplied since round 3: **76 company documents**, including
FlamAI twice, Voxela twice, Premas twice, ExxonMobil and Exxonmobil, and
WinWire alongside WinWire (Part of NTT DATA). Both FlamAI cards are visible
side by side in `08`.
