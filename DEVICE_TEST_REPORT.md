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

**Status: partial — APK built, not installed.**

---

## Part 2 — What is actually up

**Status:** not started

---

## Part 3 — The nine items on device

**Status: BLOCKED-NO-DEVICE** for all items.

---

## Part 4 — Everything never seen on a device

**Status: BLOCKED-NO-DEVICE** for all items.

---

## Part 5 — Fixes

**Status:** in progress

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
