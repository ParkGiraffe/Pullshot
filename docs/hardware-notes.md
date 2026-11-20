# Hardware Notes

English | [한국어](hardware-notes.ko.md)

These are facts confirmed on 2026-11-15 by connecting a Nintendo Switch 2 (firmware 23.5.0) to a MacBook Pro (Mac15,6, macOS 26.5) with a USB-C data cable.
They are the basis for the plans for Phase 2 (library) and Phase 3 (app). The device serial number and the original photos and videos are not stored in this document or in the repo.
The raw dumps are in `LocalFixtures/switch2-23.5.0/`, which is not committed, and `LocalFixtureTests` replays them only when this dump is present.

The original Nintendo Switch (1st generation) could not be checked because no device was available. Product ID 0x201D is a value taken from the Tethersnap notes, and the app marks it as experimental support.

## Device Information

| Item | Value |
|---|---|
| Manufacturer, model | Nintendo, Nintendo Switch 2 |
| PTP version | 100 |
| Supported operations | Only the 10 operations 0x1001 to 0x100A. There is no DeleteObject (0x100B), so photos and videos on the device cannot be deleted. |
| Storage | One, "Album". Both capacity and free space come back as 0xFF, so they are unknown. |
| Storage ID | Changes every session (0x00060001, 0x00070001, 0x00090001), so it cannot be used as a key for the history. |
| Serial number | Stays the same across sessions and USB resets, so it can be used as a key to tell devices apart. |

## USB States

| State | VID:PID | Interfaces |
|---|---|---|
| Copy to PC mode | 0x057E:0x2061 | Photo transfer (class 6, subclass 1, protocol 1) |
| Otherwise (standby) | 0x057E:0x2060 | HID only. |

- An IOKit search that specifies only the vendor ID finds nothing, so the list of product IDs must be specified as well.
- Sending a USB device reset makes the Switch leave Copy to PC mode and reconnect as 0x2060. The user then has to turn Copy to PC on again on the console, so the app should use a USB reset only as a last resort and, after a reset, ask the user to turn Copy to PC on again.
- When the device is connected as 0x2060, the app can conclude "connected but not in Copy to PC mode" and show guidance.
- The path where the same process reconnects after the user turns Copy to PC back on following a USB reset (a 5-second retry when the photo transfer interface appears late) has not yet been verified on a real device.

## Album Structure

- Game folders sit directly under the root, and photos and videos are inside them. There were no deeper subfolders.
- Korean game names come through as they are (for example, "파이어 엠블렘 만자천홍", "모여봐요 동물의 숲").
- The Switch actually has a folder named "기타" ("Other"), which collides with the name "기타" that Pullshot uses to group photos and videos outside game folders, so Phase 2 has to decide whether to distinguish the two.
- There were 12 game folders with 3,082 files (2,902 photos, 180 videos), about 6.9GB in total, and scanning everything takes about 16 seconds.

## File Names and Metadata

- File names have the form `YYYYMMDDhhmmss` + a two-digit sequence number + `_s` or `_c` + extension (for example, `2026010112000000_s.jpg`).
  - Files taken in the same second are told apart by the sequence number (`…0900_s.jpg`, `…0901_s.jpg`).
  - The counts were 2,460 `_s.jpg`, 442 `_c.jpg`, 165 `_s.mp4`, and 15 `_c.mp4`. The meaning of `_s` and `_c` could not be determined.
- The CaptureDate value in ObjectInfo is filled in but has no time zone notation, so it is read as the console's local time.
- The format codes are 0x3801 for photos (EXIF JPEG) and 0xB982 for videos (MP4).
- GetThumb is supported for both photos (about 19KB) and videos (about 15KB).

## Transfer

- In the data phase, the 12-byte header arrives first on its own, and the body comes from the next read.
- The size of each received file matched the size shown by `list` down to the byte. The video (5,616,157 bytes) plays for 8.3 seconds with 2 tracks, and the photo is 1920×1080.
- Receiving a single 45.1MB video takes about 0.3 seconds. Receiving all 3,082 files (about 6.9GB) took about 87 seconds including the scan, with no failures.
- On every connection, one read that drains the bytes left by the previous connection ends in a timeout (0xE00002D6, 0.3 seconds), which delays the connection by that much.

## When Another App Is Using the Switch

- If the Tethersnap app is using the interface, opening fails with 0xE00002C9. The IORegistry `UsbExclusiveOwner` has the form "pid N, Tethersnap", so the name of the app in use can be included in the guidance.
- Launching Preview or Image Capture makes ptpcamerad use the Switch, which fails with the same 0xE00002C9, and quitting that app resolved it.
- 0xE00002C5 (exclusive access) did not appear in this check.

## When a Session Is Left Behind

If a process ends without closing its session, such as with `kill -9`, the session remains on the Switch.

1. GetDeviceInfo without a session responds with an empty data phase and 0x2004.
2. OpenSession is rejected with 0x201E (already open).
3. CloseSession sent with transaction ID 0 is also rejected with 0x2004.
4. A PTP device reset (class request) ends in a stall (0xE0005000).
5. Sending the last resort, a USB device reset, resolves it, but the Switch leaves Copy to PC mode.

So the current code drains any remaining data and sends CloseSession even after cancellation and errors, so that no session is left behind.
0x2004 is a response saying the transaction ID is wrong, so saving the last transaction ID to disk should let the session be closed without a USB reset even after a forced termination, and this was verified on 2026-11-20. On a Switch (system version 23.5.0) left with a session by a forced termination, sending CloseSession with transaction IDs counting up from 1 closed the session with 0x2001 at 3279, the next ID the previous connection would have used, in about 2 seconds. Afterwards a sessionless GetDeviceInfo returned 0x2001 and the Switch stayed in Copy to PC mode. So the session can be closed without a USB reset even without saving the ID, by trying IDs in order. The app does not use this method yet.

A Switch whose Copy to PC mode was turned off and on again did not reject GetDeviceInfo without a session. The rejection that Tethersnap recorded on firmware 22.5.0 did not reproduce on 23.5.0, but the code keeps a path that prepares for a rejection.

## Cancellation and Disconnection

- When Ctrl-C was received through a signal handler, the USB read in progress was cut off with 0xE00002EB and the session got out of sync, so SIGINT is now ignored and detected only through a dispatch source.
- Cancel during a scan: it stops between objects and closes the session, and the next connection opened immediately without a reset.
- Cancel during a download: it reads through the rest of the data phase of the 45.1MB video and discards it, deletes the partially received file, and closes the session. The next connection opened immediately without a reset.
- Cable unplugged during a download: the read ends with 0xE00002EB, and later calls fail with 0x10000003. The "The Switch was disconnected" message appears, and no partially received file (`.pullshot-partial`) was left.
  - `pull` stops at the first disconnection and summarizes it as "Saved 1470, Skipped 0, Failed 1", and the remaining files it could not attempt do not appear in the summary.
  - Even after the cable is reconnected, the Switch stays in Copy to PC mode. The session that was open when the cable was pulled was not left behind either, so the next connection opened without a reset, starting from GetDeviceInfo without a session.

## Phase 2 Verification (2026-11-15)

The transferred history was saved separately in a test folder (`--ledger-folder`) for verification.

- Receiving new items: for a game with 13 files, `pull --new` received 13, and the second run's result was `Saved: 0`. The creation and modification dates of the received files match the capture time down to the second.
- Numbering: files were numbered in the order they were taken, starting from `001_20220909_153710.jpg`, and in an empty folder the `--dry-run` preview and the 13 actual file names were all identical. Videos follow the same rule (`004_….mp4`).
- Finding in a folder: when the received folder was specified, 13 files were added to the history, and those files dropped out of `list --new`. Specifying a nonexistent folder stops before connecting to the Switch and does not create a history file either.
- If the Preview app is running, ptpcamerad uses the interface and the connection fails with 0xE00002C9, and guidance appears telling the user to quit Preview and Photos. Quitting the apps connected immediately.
- Splitting into plays: with a 60-minute threshold, a game with 2,625 files was split into 29 plays. A per-play view was judged unnecessary, so the feature was removed, and the app's default view is newest first.
- Even after all the checks were done, the next connection opened without a USB reset.

## Follow-up Work for Phases 2 and 3

- The key for imported history is determined by the serial number and file name; the storage ID and object handle, which change every session, are not used.
- Make sure the Switch's "기타" folder does not collide with the name used for photos and videos outside game folders.
- The app looks at the 0x2060 state and shows "Turn on Copy to PC", and if it performed a USB reset, it reports that fact together with what the user needs to do.
- Verify on a real device how to close the session by saving the last transaction ID, so that the next launch does not perform a USB reset even if the app was force-quit.
- Show the number of files that could not be attempted in the summary after a disconnection.

## Phase 3 Interim Verification (Without a Device, 2026-11-16)

The Switch could not be connected, so only the items from the Phase 3 plan's real-device verification (Task 13) that can be checked without a device were checked first on a Mac Studio (macOS 27.2).
The app was the release build made with `make app`, run with a demo album (`-demoAlbum YES`) and test history folders (`-ledgerFolder`, `-importFolder`).
This Mac's screen was locked, so clicks and key input did not reach the app. The per-game view, selection state, import progress and result, and the first-connection question were therefore brought up with uncommitted verification code and only checked on screen.

### What Was Verified

- Connection guidance: launched without a Switch, it shows "Connect your Switch" and a two-step guide, and the device field says "No Switch connected".
- Grid and views: the 60 demo photos and videos appear in a newest-first grid. The date view groups items by date under month headings, and the time zone of the capture is attached to the date heading.
- Video filter and search field: the video filter leaves only the 12 videos, and the count in the inspector changes with it. The game search field leaves only games whose names match, and when no game matches it shows "No matching folders".
- Size slider: thumbnail size 120 gives 7 columns and 360 gives 2 columns.
- Selection: when 8 items are selected, each cell gets an accent-color border and a checkmark, and the inspector shows stacked thumbnails, "Selected: 8", the number of photos and videos, the size, and the capture time.
  - Keyboard selection could not be pressed by hand, so only the passing of the `GridSelection` unit tests (click, ⌘, ⇧, arrow keys) was confirmed.
- Import and export buttons: in the demo, "Import N New" and "Export" are disabled, and "Export Whole Game" is enabled because it only selects everything.
- Numbering preview: with 8 items selected, choosing "Number in order taken" numbers them as `001_YYYYMMDD_hhmmss` starting with the earliest taken, and videos keep the `.mp4` extension. From 6 items on, the display omits the range between the first three and the last one, which matches the CLI naming rule confirmed in Phase 2.
- Quit: sending a quit event to the app run as the demo quit it in 0.16 seconds, and the preview source folder created in advance (`Pullshot-preview`) was deleted. The demo does not open a session, so the path that closes the session and quits (waiting up to 10 seconds) could not be checked.
- CLI: running `list` without a Switch prints "No Switch connected. Connect a data cable to the USB-C port on the bottom of the console, and turn on Copy to PC mode on the console." and exits with exit code 1, and no file was created in the test history folder.
- DMG: the DMG made by `make dmg` contains `Pullshot.app`, an `Applications` shortcut, and `LICENSE`.
  - The app is a universal build of x86_64 and arm64 and passes `codesign --verify --deep --strict`.
  - It is ad-hoc signed, so Gatekeeper assessment (`spctl`) rejects it, and on first launch you have to click "Open Anyway" as the README explains.
  - The app launched directly from the DMG also opened as the demo and quit with a quit event.

### Items That Need Real-Device Verification

- Step 1: After connecting, check that the screen changes automatically in the order "Connecting", "Reading the album", grid, that the number of games and files matches the CLI `list` result, and that the first-connection question can be dismissed with "Not Now".
- Step 2: Check that cells fill in starting with those whose real thumbnails are visible, that reopening shows them immediately from the disk cache, and that the Space bar preview opens the original for both photos and videos. Press the keyboard selection by hand at this time as well.
- Step 3: Check that the real import result is "Saved: N", that the game has no new-item dot when reopened, that the creation date of the received files is the capture time, and that "Find in Folder…" in the first-connection question works.
- Step 4: Check that the file names of the files imported by selection match the inspector preview, and that "Show in Finder" selects those files.
- Step 5: Check the guidance and the "Try Again" behavior when the cable is unplugged and reconnected during an import, and when reconnecting with the Preview app running.
- Step 6: Check that ⌘Q during an import quits within 10 seconds, and that the next connection opens immediately without USB reset guidance.
- Console menu names: the menu order in the official English documentation is Data Management > Manage Screenshots and Videos > Copy to PC. The app's guidance screen, the English strings, and the CLI error messages currently say only "Copy to PC in Data Management", which omits the middle step, so check the middle menu name on a Korean console and then fix the wording.
