// NXSplash — nx-mac v0.1 splash window
// Honest, time-free UX: step text driven by real shell markers, no ETA/timers.
// Auto-dismisses when Plug window appears.
// Communicates with router via /tmp/nx-launcher-status.

import Cocoa
import SwiftUI

// ─────────────────────────── config ───────────────────────────
let statusFile = "/tmp/nx-launcher-status"
let hardTimeout: TimeInterval = 180
let plugDetectMinElapsed: TimeInterval = 3
let windowSettleDelay: TimeInterval = 0.8
let fadeOutDuration: TimeInterval = 0.35
let slowHintThreshold: TimeInterval = 15   // waiting > 15s on same state -> soft hint

// ─────────────────────────── state ────────────────────────────
final class SplashState: ObservableObject {
    @Published var stepText: String = "준비 중..."
    @Published var hintText: String? = nil
    @Published var isDismissing: Bool = false
}

// ─────────────────────────── view ─────────────────────────────
struct SplashView: View {
    @ObservedObject var state: SplashState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("NX Launcher")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("바람의나라")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.85)
                .padding(.vertical, 2)

            Text(state.stepText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(height: 18)
                .id(state.stepText)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: state.stepText)

            ZStack {
                Color.clear.frame(height: 30)
                if let hint = state.hintText {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: state.hintText)

            Button(action: onCancel) {
                Text("취소").frame(minWidth: 58)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 38)
        .frame(width: 320, height: 240)
        .opacity(state.isDismissing ? 0 : 1)
        .animation(.easeOut(duration: fadeOutDuration), value: state.isDismissing)
    }
}

// ─────────────────────────── helpers ──────────────────────────
func writeStatus(_ s: String) {
    try? s.write(toFile: statusFile, atomically: true, encoding: .utf8)
}

func readStatus() -> String? {
    guard let s = try? String(contentsOfFile: statusFile, encoding: .utf8) else { return nil }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

func runShell(_ cmd: String) {
    let p = Process()
    p.launchPath = "/bin/sh"
    p.arguments = ["-c", cmd]
    try? p.run()
}

func stepTextFor(_ status: String?) -> String {
    switch status {
    case "booting"?:  return "준비 중..."
    case "cleanup"?:  return "이전 세션 정리"
    case "symlink"?:  return "환경 점검"
    case "spawn"?:    return "Plug 시작"
    case "waiting"?:  return "로그인 창 준비 중"
    case "ready"?, "READY"?, "DONE"?: return "완료"
    default:          return "준비 중..."
    }
}

// Detect any visible Plug/Wine window above trivial size.
func detectPlugWindow() -> Bool {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return false
    }
    for info in list {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
        let w = bounds["Width"] ?? 0
        let h = bounds["Height"] ?? 0
        if w < 200 || h < 150 { continue }

        let owner = (info[kCGWindowOwnerName as String] as? String ?? "").lowercased()
        let title = (info[kCGWindowName as String] as? String ?? "").lowercased()

        let matchers = ["nexonplug", "nexon plug", "넥슨플러그", "넥슨",
                        "baram", "바람", "plug.exe",
                        "wine64-preloader", "wine-preloader"]
        for m in matchers {
            if owner.contains(m) || title.contains(m) {
                return true
            }
        }
    }
    return false
}

// ─────────────────────────── app setup ────────────────────────
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let state = SplashState()

let win = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
    styleMask: [.titled, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
win.title = "NX Launcher"
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.isMovableByWindowBackground = true
win.level = .floating
win.center()
win.collectionBehavior = [.moveToActiveSpace]
win.isReleasedWhenClosed = false
win.standardWindowButton(.miniaturizeButton)?.isHidden = true
win.standardWindowButton(.zoomButton)?.isHidden = true
win.standardWindowButton(.closeButton)?.isHidden = true

let fx = NSVisualEffectView()
fx.material = .sidebar
fx.blendingMode = .behindWindow
fx.state = .active
win.contentView = fx

let hosting = NSHostingView(rootView: SplashView(state: state, onCancel: {
    writeStatus("CANCEL")
    runShell("pkill -9 -f 'NexonPlug|wine/bin|wineserver|gamer\\.exe' 2>/dev/null || true")
    state.isDismissing = true
    DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration + 0.05) {
        NSApp.terminate(nil)
    }
}))
hosting.translatesAutoresizingMaskIntoConstraints = false
fx.addSubview(hosting)
NSLayoutConstraint.activate([
    hosting.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
    hosting.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
    hosting.topAnchor.constraint(equalTo: fx.topAnchor),
    hosting.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
])

win.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)

// ─────────────────────────── main loop ────────────────────────
// Note: do NOT write "booting" here — the AppleScript router writes it
// before spawning the splash, and the shell cmd may have already advanced
// the state by the time we start. Read-only from here.

let startedAt = Date()
var lastStatus: String? = readStatus()
var lastStatusChangeAt = Date()
state.stepText = stepTextFor(lastStatus)
var plugFirstSeen: Date? = nil

func dismiss() {
    guard !state.isDismissing else { return }
    state.isDismissing = true
    DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration + 0.05) {
        NSApp.terminate(nil)
    }
}

Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    let now = Date()
    let elapsed = now.timeIntervalSince(startedAt)
    let status = readStatus()

    // Signal-driven step text
    if status != lastStatus {
        lastStatus = status
        lastStatusChangeAt = now
        state.stepText = stepTextFor(status)
        state.hintText = nil  // reset hint on state change
    }

    // External terminal signals
    if status == "READY" || status == "DONE" { dismiss(); return }
    if status == "CANCEL" { NSApp.terminate(nil); return }

    // Plug window detection (primary readiness)
    if elapsed >= plugDetectMinElapsed && detectPlugWindow() {
        if plugFirstSeen == nil { plugFirstSeen = now }
        if let t = plugFirstSeen, now.timeIntervalSince(t) >= windowSettleDelay {
            dismiss()
            return
        }
    }

    // Soft hint when a state sticks longer than expected
    let stickDuration = now.timeIntervalSince(lastStatusChangeAt)
    if status == "waiting" && stickDuration > slowHintThreshold && state.hintText == nil {
        state.hintText = "시간이 조금 걸리고 있어요.\n계속하려면 기다려 주세요 (ESC로 취소)"
    }

    if elapsed >= hardTimeout { dismiss(); return }
}

app.run()
