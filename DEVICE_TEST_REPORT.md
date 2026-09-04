# Device test session

Started 2026-09-05.

Result vocabulary: **PASS** / **FAIL-FIXED** / **FAIL-PENDING-DEPLOY** /
**BLOCKED-BILLING** / **BLOCKED-NO-DEVICE**.

---

## Part 0 — Setup

**Status: BLOCKED-NO-DEVICE.** The phone is plugged in and Windows sees it,
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

**Status: partial — APK built and waiting, cannot install.**

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

**Status: BLOCKED-NO-DEVICE** for all items.

---

## Part 4 — Everything never seen on a device

**Status: BLOCKED-NO-DEVICE** for all items.

---

## Part 5 — Fixes

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
