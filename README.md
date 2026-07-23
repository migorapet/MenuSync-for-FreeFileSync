# MenuSync for FreeFileSync

A small native macOS menu bar companion for FreeFileSync. It does exactly three
things:

1. Runs one FreeFileSync `.ffs_batch` job.
2. Displays the latest result reported by FreeFileSync's JSON output.
3. Schedules the same job at a fixed interval.

It never compares files, watches the filesystem, or edits FreeFileSync
configuration files.

> **Unofficial project:** MenuSync for FreeFileSync is an independent companion
> application. It is not affiliated with, endorsed by, or distributed by the
> FreeFileSync project. FreeFileSync remains a separate application and must be
> installed by the user.

## Beta status and requirements

- This project is currently beta software.
- Development is taking place on the macOS 27 beta.
- The deployment target is macOS 14 or later, but releases have not yet been
  fully compatibility-tested across every macOS version between 14 and 27.
- FreeFileSync must be installed. `/Applications/FreeFileSync.app` is the
  default, but any installation location can be selected in Preferences.
- A batch job created and maintained in FreeFileSync is required.

## Build and run

1. Open `MenuSyncForFreeFileSync.xcodeproj` in Xcode.
2. Select the **MenuSyncForFreeFileSync** scheme.
3. Build and run.
4. Open **Preferences…** from the menu bar and select a `.ffs_batch` file.

For **Launch at Login**, copy the built app to `/Applications` and run it from
there. macOS may reject login-item registration for an app launched directly
from Xcode's build directory.

## FreeFileSync integration

Synchronization always launches exactly:

```text
"/selected/path/FreeFileSync.app/Contents/MacOS/FreeFileSync" "/path/to/job.ffs_batch"
```

The app decodes the JSON emitted on standard output and combines `syncResult`
with the process termination status. It does not inspect HTML logs. **Open Last
Log** hands the path back to macOS, and **Open Batch in FreeFileSync** starts
FreeFileSync in edit mode.

## Menu bar status

The menu bar shows a single flat template icon without a text label. Built-in
states use SF Symbols for setup, freshness, upcoming runs, overdue runs,
syncing, paused scheduling, warnings, and errors. Template rendering lets macOS
automatically match the icon color to the current menu bar appearance.

The latest FreeFileSync result and completion timestamp are persisted in the
app's user defaults. This lets the app detect an overdue sync after relaunching.
An overdue job runs immediately at launch. Three consecutive failures pause
automatic scheduling; a successful manual run clears the counter and resumes
the normal schedule.

Each status icon can be replaced by drawing a small vector icon in Preferences.
The drawing can be previewed immediately in the menu bar before saving. Up to
20 drawings are cached; drawings currently assigned to a status are pinned,
and the oldest unassigned drawing is evicted first. Hover over an unassigned
drawing to delete it after confirmation; drawings in use cannot be deleted.
Each status can independently apply no animation, rotate, shake, sway, or breathe
to either a custom drawing or its system icon. Each effect uses a one-second
motion cycle and can run for one to five seconds before returning to a static
icon. None always uses a zero-second duration; selecting an animated effect
starts with a two-second default. Reduce Motion disables icon animation
automatically. **Reset All Preferences** preserves the selected batch job and
drawing history while restoring SF Symbols, disabling icon animations, setting
a five-minute interval, enabling failure notifications, and turning Launch at
Login off.

## Local packaging

Run:

```bash
./scripts/package_local.sh
```

This produces an ad-hoc signed universal application and ZIP in `dist/`.
Ad-hoc signing is suitable for local testing. Public distribution requires an
Apple Developer ID Application certificate, hardened-runtime signing, and Apple
notarization. The recipient must install FreeFileSync separately and select its
location in Preferences if it is not in `/Applications`.
