# nx-mac

> **바람의나라 (Kingdom of the Winds) on macOS.** **7.3 seconds** from double-click to login. Zero background processes.

[한국어](./README.md) · [English](./README.en.md)

![바람의나라 Kingdom of the Winds running on macOS](docs/screenshots/baram-ingame.png)

---

A one-click macOS launcher for the Korean MMORPG 바람의나라 (Kingdom of the Winds). You don't have to touch Wine settings — the builder applies one verified preset automatically, and after that it's just a `.app` to double-click.

Built on the Sikarugir Wine wrapper (CX 24.0.7). A **builder, AppleScript URL router, and SwiftUI splash** form the launch chain. The project doesn't tune Wine itself — it trusts the free upstream stack and focuses on **one verified preset per game**, applied automatically.

## Key metrics

| Metric | Value |
|---|---|
| Cold-start (click → Plug login window) | **7.3 s** (measured, Apple Silicon) |
| Warm reuse | 2–3 s |
| Idle processes | **0** (full wine tree teardown on exit) |
| Korean IME composition | working |
| GameGuard (NGS) passthrough | verified to in-game |
| Runtime cost | $0 |

## Supported

| Game | Status | Notes |
|---|---|---|
| 바람의나라 | end-to-end verified | v0.1 release target |

Other Nexon titles are untested. See [Compatibility](#compatibility) for predictions.

---

# Install

**Requirements:** macOS 14+ · Apple Silicon · ~25 GB free disk.

Two paths — pick one.

## 1. One-liner (recommended)

Paste a single line into Terminal. It chains Xcode CLT → Homebrew → Sikarugir → repo clone → builder. The only manual step is clicking through Sikarugir Creator once to make the wrapper.

```bash
curl -fsSL https://raw.githubusercontent.com/dgv7/nx-mac/main/install.sh | bash
```

Follow the prompts; `~/Applications/Sikarugir/NX Launcher.app` is installed at the end. Then jump to [gulim.ttc placement](#3-place-gulimttc-korean-font) and [First launch](#4-first-launch).

> **Safe to interrupt** — every step is idempotent. Re-running the same command picks up where it stopped.

## 2. Manual install

If you'd rather do it step by step:

### 0. Prerequisites

<details>
<summary><b>Install Xcode Command Line Tools / Homebrew / Git</b> (click to expand)</summary>

```bash
# Xcode Command Line Tools — provides git, clang, codesign
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# (Apple Silicon only) add brew to PATH
eval "$(/opt/homebrew/bin/brew shellenv)"
```

</details>

### 1. Install Sikarugir Creator & create the wrapper

```bash
brew tap Sikarugir-App/sikarugir
brew install --cask sikarugir
open -a Sikarugir
```

In Sikarugir Creator, click **New Blank Wrapper** and fill in:

| Setting | Value |
|---|---|
| Name | `Baram` |
| Engine | `WS12WineCX24.0.7` |
| OS | `Windows 10` |

The engine must be **CX 24.0.7** exactly — no other version reproduces the Korean IME fix.

When done, `~/Applications/Sikarugir/Baram.app` is created.

### 2. Run the nx-mac builder

```bash
git clone https://github.com/dgv7/nx-mac
cd nx-mac
./scripts/build-baram-app.sh
```

The builder automates:

- libinotify dylib symlinks (both `wine/lib/` and `SharedSupport/`)
- `dosdevices/c:` absolute-path correction
- winetricks Korean environment (`corefonts → cjkfonts → vcrun2019`)
- NexonPlug installation
- **Disabling the `Nexon Launcher` Windows service** — the key to the 50 s → 7 s cold-start
- exit-watcher placement
- `NX Launcher.app` creation + `nexonplug://` URL-handler registration
- SwiftUI Splash compile + bundle

> **First run takes 10–20 minutes** — don't kill the terminal during the `cjkfonts` download step even if it goes quiet. It's fetching several GB of font packages.

### 3. Place gulim.ttc (Korean font)

Copy `C:\Windows\Fonts\gulim.ttc` from your own Windows PC to:

```
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/prefix/drive_c/windows/Fonts/gulim.ttc
```

<details>
<summary><b>If you don't have a Windows PC</b></summary>

- **Borrow a friend's or PC bang (PC 방) Windows**, copy via USB — most practical
- **Office or parent's work laptop** — any Windows install has the font
- **Parallels Desktop / UTM trial**: install Windows in a VM and grab `C:\Windows\Fonts\gulim.ttc`
- **Borrow a used Windows laptop** briefly

The game launches without it, but **Korean text renders as squares (□)**. The font is Microsoft proprietary so we can't bundle it.

</details>

### 4. First launch

Double-click `~/Applications/Sikarugir/NX Launcher.app`.

> **If macOS says "unidentified developer"**
>
> The app is ad-hoc signed, so Gatekeeper blocks the first launch.
> - **Option 1**: **Right-click** `NX Launcher.app` → **Open** → click **Open** again in the warning dialog (once)
> - **Option 2**: System Settings → Privacy & Security → scroll to "`NX Launcher` was blocked…" → **Open Anyway**

The splash appears immediately and auto-dismisses when the Plug login window is detected.

> **Ignore the "게임 실행에 실패했습니다" popup**
>
> After clicking `게임시작` in Plug, the popup below briefly appears — **but the game actually launches normally**. Click `확인` to dismiss it; the OTP prompt or game window comes up right behind.
>
> ![plug false-error popup](docs/screenshots/plug-false-error.png)
>
> A false alarm from Plug misreading the game process's exit code under Wine. Auto-dismiss is deliberately not implemented — OTP and real service notices use the same dialog style, and silencing all of them risks hiding something the user actually needs to read.

---

# Troubleshooting

<details>
<summary><b>The splash window won't go away</b></summary>

If Plug's login window is up but the splash is still there:

1. Press `ESC` or click the splash's **Cancel** button (kills the full Wine tree)
2. `pkill -f "NX Splash"` in Terminal to force-close
3. If one stage text has been stuck for 30+ seconds, Wine may be hung — press `ESC` and relaunch `NX Launcher.app`

</details>

<details>
<summary><b>How do I quit the game cleanly?</b></summary>

Safest order:

1. **Log out in-game** (back to the character select screen)
2. **Close the Plug window** via its `X` button
3. `baram-exit-watcher` then tears down the entire Wine tree automatically

If you need to force-quit:
```bash
pkill -9 -f 'NexonPlug|wine/bin|gamer.exe'
```

Every launch is a cold start (zero-idle policy).

</details>

<details>
<summary><b>Cold-start is taking more than 60 seconds</b></summary>

Check whether the builder successfully disabled the `Nexon Launcher` Windows service:

```bash
~/Applications/Sikarugir/Baram.app/Contents/SharedSupport/wine/bin/wine \
  sc query "Nexon Launcher"
```

`STATE: STOPPED` (or an error) is expected. If it shows `RUNNING`, re-run the builder:

```bash
cd ~/nx-mac && ./scripts/build-baram-app.sh
```

The builder is idempotent, so re-running is safe.

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

`gulim.ttc` is missing or in the wrong path. Revisit [3. Place gulim.ttc](#3-place-gulimttc-korean-font).

</details>

<details>
<summary><b>I want to uninstall completely</b></summary>

```bash
# Remove NX Launcher and the Sikarugir wrapper
rm -rf ~/Applications/Sikarugir/NX\ Launcher.app
rm -rf ~/Applications/Sikarugir/Baram.app

# Remove Sikarugir Creator (only if you don't use other wrappers)
brew uninstall --cask sikarugir

# Remove the nx-mac project
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
- **"실행 실패" popup** ([see First launch](#4-first-launch)) — a Plug false alarm. Click `확인` and the game proceeds. Auto-dismiss is avoided because OTP and real notices share the same dialog style.
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
