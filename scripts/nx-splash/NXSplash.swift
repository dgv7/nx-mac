// NXSplash — nx-mac v0.1 splash window
// Shows immediate feedback during Wine cold-start (~50s).
// Auto-dismisses when Plug window appears, or after hard timeout.
// Communicates with router/exit-watcher via /tmp/nx-launcher-status.

import Cocoa
import SwiftUI

// ─────────────────────────── config ───────────────────────────
let statusFile = "/tmp/nx-launcher-status"
let hardTimeout: TimeInterval = 120
let plugDetectMinElapsed: TimeInterval = 5
let fadeOutDuration: TimeInterval = 0.35

// ─────────────────────────── state ────────────────────────────
final class SplashState: ObservableObject {
    @Published var stepText: String = "준비 중..."
    @Published var elapsed: Int = 0
    @Published var isDismissing: Bool = false
}

// ─────────────────────────── view ─────────────────────────────
struct SplashView: View {
    @ObservedObject var state: SplashState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 2) {
                Text("NX Launcher")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("바람의나라")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.85)
                .padding(.vertical, 4)

            VStack(spacing: 3) {
                Text(state.stepText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(height: 16)
                Text("\(state.elapsed)초 / 약 50초")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Button(action: onCancel) {
                Text("취소")
                    .frame(minWidth: 58)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
            .padding(.top, 2)
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

func pgrepExists(_ pattern: String) -> Bool {
    let p = Process()
    p.launchPath = "/usr/bin/pgrep"
    p.arguments = ["-f", pattern]
    p.standardOutput = Pipe()
    p.standardError = Pipe()
    do {
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    } catch {
        return false
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

        let matchers = ["nexonplug", "nexon plug", "넥슨플러그", "넥슨", "baram", "바람",
                        "plug.exe", "wine64-preloader", "wine-preloader"]
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

// Window
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

// Visual effect background (sidebar blur, native rounded corners)
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

// ─────────────────────────── step/poll loop ───────────────────
writeStatus("booting")

let startedAt = Date()
var plugFirstSeen: Date? = nil

func dismiss(reason: String) {
    guard !state.isDismissing else { return }
    state.isDismissing = true
    DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration + 0.05) {
        NSApp.terminate(nil)
    }
}

func updateStepText(elapsed t: Int, statusHint: String?) {
    // Status file hint overrides time-based text when available.
    if let h = statusHint {
        switch h {
        case "cleanup": state.stepText = "이전 Wine 프로세스 정리"
        case "symlink": state.stepText = "환경 검증 및 심링크 확인"
        case "spawn":   state.stepText = "Plug 프로세스 시작"
        case "waiting": state.stepText = "로그인 창 로딩 중"
        case "ready":   state.stepText = "준비 완료"
        default: break
        }
        if ["cleanup", "symlink", "spawn", "waiting", "ready"].contains(h) { return }
    }
    switch t {
    case 0..<3:   state.stepText = "Wine 환경 준비"
    case 3..<8:   state.stepText = "이전 프로세스 정리"
    case 8..<14:  state.stepText = "환경 검증"
    case 14..<22: state.stepText = "Plug 프로세스 시작"
    case 22..<38: state.stepText = "런처 초기화"
    case 38..<55: state.stepText = "로그인 창 로딩"
    default:      state.stepText = "거의 완료..."
    }
}

Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    let elapsed = Int(Date().timeIntervalSince(startedAt))
    state.elapsed = elapsed

    let status = readStatus()
    updateStepText(elapsed: elapsed, statusHint: status)

    // External signals
    if status == "READY" || status == "DONE" {
        dismiss(reason: "status:\(status ?? "")")
        return
    }
    if status == "CANCEL" {
        // someone else cancelled — just bail
        NSApp.terminate(nil)
        return
    }

    // Detect Plug window (primary readiness signal)
    if Double(elapsed) >= plugDetectMinElapsed && detectPlugWindow() {
        if plugFirstSeen == nil { plugFirstSeen = Date() }
        // Small settle delay so Plug fully renders before we vanish
        if let t = plugFirstSeen, Date().timeIntervalSince(t) >= 1.0 {
            dismiss(reason: "window-detected")
            return
        }
    }

    // Hard timeout
    if Double(elapsed) >= hardTimeout {
        dismiss(reason: "timeout")
        return
    }
}

app.run()
