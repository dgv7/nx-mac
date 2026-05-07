# nx-mac

> **바람의나라 (Kingdom of the Winds) on macOS.** **7.3 seconds** from double-click to login. Zero background processes.

[한국어](./README.md) · [English](./README.en.md)

![바람의나라 Kingdom of the Winds running on macOS](docs/screenshots/baram-ingame.png)

---

## Just the result

Install is **one command line + one font file + one double-click**.

```bash
curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash
```

Two follow-ups after the script finishes:

1. **Drop in `gulim.ttc`** once — copy `C:\Windows\Fonts\gulim.ttc` from your own Windows install to `~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/` ([alternatives](#sourcing-gulimttc))
2. **Right-click `NX Launcher.app` → Open** — Gatekeeper, just once

That's it. From then on, double-click → 7.3 seconds → login window.

| Metric | Value |
|---|---|
| Cold-start (click → Plug login window) | **7.3 s** (measured, Apple Silicon) |
| Warm reuse | 2–3 s |
| Idle processes | **0** (full wine tree teardown on exit) |
| Korean IME composition | working |
| GameGuard (NGS) passthrough | verified to in-game |
| Runtime cost | $0 |

**Requirements:** macOS 14+ · Apple Silicon · ~25 GB free disk
**Supported game:** 바람의나라 (v0.1) · other Nexon titles: see [Compatibility](#compatibility)

> The one-liner is safe to interrupt. Every step is idempotent — re-running picks up where it stopped.

---

## How "one line" became one line

It wasn't one line at first. **Three days, ~12 hours, 16 blockers** before it collapsed into a single command.

| Session | Breakthrough |
|---|---|
| Day 1 | Sikarugir + Wine 10 full chain working; Chromium black screen (`VizDisplayCompositor` flag); AppleScript URL handler; NexonLauncher pre-spawn trick |
| Day 2 | **Korean IME composition bug** — Wine 10 Mac driver doesn't forward pre-edit to IMM32. Fixed by swapping to **CX 24.0.7**. Discovered libinotify rpath also needs `SharedSupport/`, not just `wine/lib/` |
| Day 3 | **Where the 50 s cold-start really went** — phase profiling showed the 40 s auto-start timeout on the `Nexon Launcher` Windows service was the culprit. Disabled → **50 s → 7.3 s** |

What had to be solved (excerpt):

1. macOS Tahoe libinotify rpath — symlink 94 Frameworks dylibs
2. Wine drive Free Space 0 Bytes — `dosdevices` absolute paths
3. winetricks Korean stack (`corefonts → cjkfonts → vcrun2019`, in order)
4. NexonPlug self-update race — run NGM smallpatch standalone
5. Mac LSF URL scheme race — unregister Mac Plug.app + Router Viewer role
6. Plug Wine crash — replaced by Windows-service disable
7. Chromium GPU black screen — `--disable-features=VizDisplayCompositor --in-process-gpu`
8. Korean IME pre-edit — engine swap to **CX 24.0.7**
9. 50 s cold-start — disable `Nexon Launcher` service
10. 18.22 GB game download — handled by NGM
11. Wine tree leftovers on exit — hardened exit-watcher (zero idle)
12. ... GameGuard passthrough / OTP / character select / in-game

Full record: [STATUS.md](STATUS.md) · strategy branches & abort criteria: [ROADMAP.md](ROADMAP.md) · smoke checklist: [SMOKE_TEST.md](SMOKE_TEST.md)

All of it now lives inside [`build-baram-app.sh`](scripts/build-baram-app.sh). The user's job is the **three steps above** — nothing more.

---

## If you'd rather walk through it manually

<details>
<summary><b>Manual install (5 steps)</b></summary>

### 0. Prerequisites

```bash
# Xcode Command Line Tools — provides git, clang, codesign
xcode-select --install

# Homebrew (if missing)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 1. Install Sikarugir Creator & create the wrapper

```bash
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
open -a "Sikarugir Creator"
```

In Sikarugir Creator → **New Blank Wrapper** with:

| Setting | Value |
|---|---|
| Name | `Baram` |
| Engine | `WS12WineCX24.0.7` |
| OS | `Windows 10` |

The engine must be **CX 24.0.7** exactly — no other version reproduces the Korean IME fix.

### 2. Run the nx-mac builder

```bash
git clone https://github.com/dgv7/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

What the builder automates:

- libinotify dylib symlinks (both `wine/lib/` and `SharedSupport/`)
- `dosdevices/c:` absolute-path correction
- winetricks Korean environment (`corefonts → cjkfonts → vcrun2019`)
- NexonPlug installation
- **Disabling the `Nexon Launcher` Windows service** — the key to the 50 s → 7 s cold-start
- exit-watcher placement
- `NX Launcher.app` creation + `nexonplug://` URL-handler registration
- SwiftUI Splash compile + bundle

> First run takes 10–20 minutes — don't kill the terminal during the `cjkfonts` step even if it goes quiet. It's fetching several GB of font packages.

### 3. Place gulim.ttc

Copy `C:\Windows\Fonts\gulim.ttc` from your own Windows install to:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

#### Sourcing gulim.ttc

If you don't have a Windows PC:

- **Friend's PC / PC bang (PC방)** — copy via USB, the most practical route
- **Office or family laptop** — virtually every Windows install has the font
- **Parallels Desktop / UTM trial** — install Windows in a VM and grab the file
- **Cheap second-hand Windows laptop** for a one-time copy

The game launches without it, but **Korean text renders as squares (□)**. The font is Microsoft proprietary so we can't bundle it.

### 4. First launch

Double-click `~/Applications/Sikarugir/NX Launcher.app`.

> If macOS says "unidentified developer":
> - **Right-click → Open → Open** in the warning dialog (once)
> - Or: System Settings → Privacy & Security → "Open Anyway"

The splash appears immediately and auto-dismisses when the Plug login window is detected.

> **Ignore the "게임 실행에 실패했습니다" popup** — after clicking `게임시작` in Plug it briefly appears, but the game actually launches normally. Click `확인` and the OTP prompt or game window comes up right behind.
>
> ![plug false-error popup](docs/screenshots/plug-false-error.png)
>
> Plug misreads the game process's exit code under Wine. Auto-dismiss is deliberately not implemented — OTP and real service notices share the same dialog style, and silencing all of them risks hiding something the user actually needs to read.

</details>

---

## Troubleshooting

<details>
<summary><b>The splash window won't go away</b></summary>

If Plug's login window is up but the splash is still there:

1. Press `ESC` or click the splash's **Cancel** button (kills the full Wine tree)
2. `pkill -f "NX Splash"` to force-close
3. If a single stage text has been stuck for 30+ seconds, Wine may be hung — `ESC` and relaunch

</details>

<details>
<summary><b>How do I quit the game cleanly?</b></summary>

Safest order:

1. Log out in-game (back to character select)
2. Close the Plug window via its X button
3. `baram-exit-watcher` then tears down the entire Wine tree automatically

If you need to force-quit:

```bash
pkill -9 -f 'NexonPlug|wine/bin|gamer.exe'
```

Every launch is a cold start (zero-idle policy).

</details>

<details>
<summary><b>Cold-start is taking more than 60 seconds</b></summary>

The `Nexon Launcher` service may still be live:

```bash
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/wine/bin/wine \
  sc query "Nexon Launcher"
```

`STATE: STOPPED` (or an error) is expected. If `RUNNING`, re-run the builder (idempotent):

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

</details>

<details>
<summary><b>My config got reset after Sikarugir Creator "Refresh"</b></summary>

Creator's Refresh wipes the libinotify symlinks and the `Nexon Launcher` service override. Re-run the builder:

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

</details>

<details>
<summary><b>Korean text renders as squares (□)</b></summary>

`gulim.ttc` is missing or in the wrong path. Revisit [Place gulim.ttc](#3-place-gulimttc).

</details>

<details>
<summary><b>I want to uninstall completely</b></summary>

```bash
rm -rf ~/Applications/Sikarugir/NX\ Launcher.app
rm -rf ~/Applications/Sikarugir/Baram.app
brew uninstall --cask sikarugir         # only if you don't use other wrappers
rm -rf ~/nx-mac

# Rebuild the URL-handler database
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -kill -domain local -domain system -domain user
```

</details>

Anything not covered above? Open an [Issue](https://github.com/dgv7/nx-mac/issues).

---

# How it works

```
double-click
  │
  └─ NX Launcher.app (AppleScript router)
      │
      ├─ NX Splash.app (SwiftUI, reads status file → auto-dismiss)
      └─ shell cmd (cleanup → symlink verify → wine spawn)
          │
          └─ Baram.app (Sikarugir wrapper, WS12WineCX24.0.7)
              │
              └─ NexonPlug.exe (browser-less self-login)
                  │
                  └─ gamer.exe (Kingdom of the Winds)
```

The launcher also registers `nexonplug://` and `ngm://` URL handlers, so the classic browser path (`baram.nexon.com` login → `nxplug://` redirect) converges to the same router.

# Design notes

### 50 s → 7 s: where the cold-start really went

Initial measurements put cold-start at 50 seconds. **Phase profiling** across the boot sequence revealed the bottleneck was not Wine — it was a **40-second auto-start timeout on the `Nexon Launcher` Windows service** that Plug invokes on startup. Disabling auto-start and letting Plug spawn the service on demand dropped cold-start to **7.3 seconds**. No feature loss.

### Korean IME: an engine selection problem

Wine 10 with the macOS Mac driver does not forward IME pre-edit events to IMM32, breaking Korean chat input. **Swapping to CX 24.0.7 resolves it.** CX 24 has a different libinotify rpath (needs `SharedSupport/` in addition to the usual `wine/lib/`), so the builder symlinks both.

### Splash UX: no time estimates

Cold-start varies dramatically by machine — ~7 s on M-series, 30 s+ on older Intel. A fixed ETA would be dishonest on either end, so the splash shows none.

- The AppleScript shell writes stage markers to `/tmp/nx-launcher-status` (`cleanup` → `symlink` → `spawn` → `waiting`)
- The SwiftUI splash reads markers and updates only the current-state text (no numbers)
- `CGWindowListCopyWindowInfo` polls for the Plug window and auto-dismisses on detection
- If any stage sticks for more than 15 s, a subtle hint fades in with an ESC-to-cancel reminder

The spinner carries the "alive" signal; the text carries the "current state" signal. The two are never conflated.

### Zero-idle policy

When Plug or `gamer.exe` exits, `baram-exit-watcher.sh` tears down the entire wine tree. No background residents; every launch is a cold start. Deliberate — persistent processes clash with macOS's explicit open/close mental model and can confuse Nexon's session tracking.

### Why the router is a `.app`

macOS LaunchServices only binds URL schemes like `nexonplug://` and `ngm://` to `.app` bundles — a plain CLI binary cannot intercept them. The router is an AppleScript applet because `osacompile` builds the bundle without requiring a Swift toolchain, keeping the URL-handler path dependency-free.

## Compatibility

Predictions for other Nexon titles (untested):

| Likelihood | Games (representative) |
|---|---|
| High (2D, weak NGS) | CrazyArcade, KartRider Rush+ |
| Medium | Vindictus (older builds) |
| Low (strengthened NGS) | Mabinogi (current) |
| Very low (dual protection) | MapleStory (current), Dungeon & Fighter |
| None (hardcore anti-cheat) | SuddenAttack, FC Online |

**Roughly 30 % structure reuse, 70 % per-game experimentation.** The Plug / wine / router layers are shared, but each game's anti-cheat, patcher, and launch-arg pattern requires independent verification. v0.2+ will introduce `scripts/presets/` for per-game overrides. Field reports welcome in [Issues](https://github.com/dgv7/nx-mac/issues).

## Trade-offs

Conscious choices and accepted limitations:

- **User-supplied gulim.ttc** — MS proprietary font; substitutes render the UI off-metric.
- **"실행 실패" popup** — a Plug false alarm. Click `확인` and the game proceeds. Auto-dismiss is avoided because OTP and real notices share the same dialog style.
- **NGS rule changes, server-side** — current behavior is valid as of April 2026. Nexon can update anti-cheat rules without notice.
- **Sikarugir Creator "Refresh" wipes configuration** — the builder is idempotent; re-run to restore.
- **x86_64 Wine engine, not ARM-native** — Apple Game Porting Toolkit would be the ARM path but Chromium-in-Plug compatibility is weaker than CX 24 today. Re-evaluated under Plan B.

## Project layout

```
nx-mac/
├── install.sh                    # one-liner installer
├── scripts/
│   ├── build-baram-app.sh        # empty wrapper → ready-to-play
│   ├── baram-router.applescript  # URL handler + splash spawn
│   ├── baram-exit-watcher.sh     # zero-idle watcher
│   └── nx-splash/
│       ├── NXSplash.swift        # SwiftUI borderless splash
│       └── build-splash.sh       # universal-binary build
├── ROADMAP.md                    # Plan A / B / C strategy
├── STATUS.md                     # cumulative progress
└── SMOKE_TEST.md                 # smoke checklist
```

## References

- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) · [Creator](https://github.com/Sikarugir-App/Creator)
- [Apple Game Porting Toolkit 2.1](https://developer.apple.com/games/game-porting-toolkit/)
- [NexonPlug](https://nexonplug.nexon.com/)
- [nProtect GameGuard](https://gameguard.nprotect.com/kr/index.html)

## License

MIT — scripts, AppleScript, Swift, documentation. Game binaries, fonts, the Wine engine, and Sikarugir belong to their respective owners.
