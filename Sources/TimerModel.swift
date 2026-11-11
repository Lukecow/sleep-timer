import AppKit
import Combine
import Foundation
import ServiceManagement

enum EndAction: String, CaseIterable, Identifiable {
    case sleep, screenOff
    var id: String { rawValue }
    var label: String { self == .sleep ? "Sleep Mac" : "Screen off" }
}

/// The whole timer. Nothing runs (no ticking) unless a timer is active.
@MainActor
final class TimerModel: ObservableObject {
    static let shared = TimerModel()

    @Published private(set) var endDate: Date?
    @Published private(set) var now = Date()

    /// The time chosen on the scroll wheels.
    @Published var pickedHours: Int {
        didSet { defaults.set(pickedHours, forKey: "pickedHours") }
    }
    @Published var pickedMinutes: Int {
        didSet { defaults.set(pickedMinutes, forKey: "pickedMinutes") }
    }
    /// Full length of the current timer (for the progress ring).
    @Published var totalDuration: TimeInterval = 1   // settable so screenshots can show a part-used ring
    /// Whether the settings page is showing in the menu.
    @Published var showSettings = false
    @Published var endAction: EndAction {
        didSet { defaults.set(endAction.rawValue, forKey: "endAction") }
    }
    @Published var pauseMedia: Bool {
        didSet { defaults.set(pauseMedia, forKey: "pauseMedia") }
    }
    @Published var fadeVolume: Bool {
        didSet {
            defaults.set(fadeVolume, forKey: "fadeVolume")
            if !fadeVolume { restoreVolume() }
        }
    }

    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            SystemActions.log("Launch at login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private let defaults = UserDefaults.standard
    private var ticker: Timer?
    private var lastSetVolume: Int?

    /// Volume before fading started. Saved to disk so it is restored even after a restart.
    private var savedVolume: Int? {
        get { defaults.object(forKey: "savedVolume") as? Int }
        set { defaults.set(newValue, forKey: "savedVolume") }
    }

    private init() {
        let d = UserDefaults.standard
        pickedHours = (d.object(forKey: "pickedHours") as? Int) ?? 0
        pickedMinutes = (d.object(forKey: "pickedMinutes") as? Int) ?? 30
        endAction = EndAction(rawValue: d.string(forKey: "endAction") ?? "") ?? .sleep
        pauseMedia = (d.object(forKey: "pauseMedia") as? Bool) ?? true
        fadeVolume = (d.object(forKey: "fadeVolume") as? Bool) ?? true

        // Put the volume back when the Mac / screen wakes up again.
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in TimerModel.shared.restoreVolume() }
            }
        }
        restoreVolume() // in case the app was quit mid-fade

        // Testing aid: `open -a "Sleep Timer" --args -testStartSeconds 70`
        let testSeconds = d.double(forKey: "testStartSeconds")
        if testSeconds > 0 {
            DispatchQueue.main.async { TimerModel.shared.start(seconds: testSeconds) }
        }
    }

    // MARK: State

    var isRunning: Bool { endDate != nil }
    var remaining: TimeInterval { max(0, (endDate ?? now).timeIntervalSince(now)) }
    var progress: Double { min(1, max(0, remaining / max(1, totalDuration))) }
    var pickedTotalMinutes: Int { pickedHours * 60 + pickedMinutes }

    /// Short text for the menu bar: "1:30", "25m", "<1m".
    var shortRemaining: String {
        let s = Int(remaining.rounded(.up))
        if s < 60 { return "<1m" }
        let m = (s + 59) / 60
        return m >= 60 ? String(format: "%d:%02d", m / 60, m % 60) : "\(m)m"
    }

    /// Longer text: "1:29:59" or "24:59".
    var longRemaining: String {
        let s = Int(remaining.rounded(.up))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Actions

    func start(minutes: Int) { start(seconds: TimeInterval(minutes * 60)) }

    func start(seconds: TimeInterval) {
        restoreVolume()
        endDate = Date().addingTimeInterval(seconds)
        totalDuration = seconds
        startTicker()
        SystemActions.log("Timer started: \(Int(seconds)) s")
    }

    func extend(minutes: Int = 15) {
        guard let end = endDate else { start(minutes: minutes); return }
        endDate = max(end, Date()).addingTimeInterval(TimeInterval(minutes * 60))
        totalDuration = max(totalDuration, end.timeIntervalSince(Date())) + TimeInterval(minutes * 60)
        restoreVolume()
        tick()
        SystemActions.log("Timer extended by \(minutes) min")
    }

    func cancel() {
        endDate = nil
        stopTicker()
        restoreVolume()
        SystemActions.log("Timer cancelled")
    }

    func finishNow() {
        guard isRunning else { return }
        finish()
    }

    // MARK: Ticking

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor in TimerModel.shared.tick() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        guard let end = endDate else { return }
        let left = end.timeIntervalSince(now)
        if left <= 0 { finish(); return }
        if left <= 60, fadeVolume { fade(secondsLeft: left) }
    }

    private func fade(secondsLeft: TimeInterval) {
        if savedVolume == nil {
            guard let v = SystemActions.getVolume() else { return }
            savedVolume = v
        }
        guard let start = savedVolume, start > 0 else { return }
        let target = Int((Double(start) * secondsLeft / 60).rounded())
        if target != lastSetVolume {
            SystemActions.setVolume(target)
            lastSetVolume = target
        }
    }

    private func restoreVolume() {
        lastSetVolume = nil
        guard let v = savedVolume else { return }
        savedVolume = nil
        SystemActions.setVolume(v)
    }

    private func finish() {
        endDate = nil
        stopTicker()
        SystemActions.log("Time's up")
        if pauseMedia { SystemActions.pauseMedia() }
        let action = endAction
        // Give the video a moment to pause, then sleep. The volume is put back
        // when the Mac wakes up (so nothing blares if a video didn't pause).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            switch action {
            case .sleep: SystemActions.sleepMac()
            case .screenOff: SystemActions.turnOffScreen()
            }
            if UserDefaults.standard.bool(forKey: "dryRun") {
                TimerModel.shared.restoreVolume()
            }
        }
    }
}
