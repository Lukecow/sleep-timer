import AppKit
import Foundation

/// Small helpers that talk to macOS: volume, media pause, sleep.
enum SystemActions {

    // MARK: Volume (0–100). "set volume" needs no special permission.

    static func getVolume() -> Int? {
        var error: NSDictionary?
        let script = NSAppleScript(source: "output volume of (get volume settings)")
        guard let result = script?.executeAndReturnError(&error), error == nil else { return nil }
        let v = Int(result.int32Value)
        return (0...100).contains(v) ? v : nil
    }

    static func setVolume(_ value: Int) {
        let v = min(100, max(0, value))
        var error: NSDictionary?
        NSAppleScript(source: "set volume output volume \(v)")?.executeAndReturnError(&error)
    }

    // MARK: Media pause
    //
    // Sends a real "pause" (not play/pause toggle) to whatever app is currently
    // playing (Safari/YouTube, Music, TV, Spotify, QuickTime, ...), the same way
    // the pause key / Control Centre does. Never starts anything playing.

    private typealias MRSendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool
    private static let sendCommand: MRSendCommand? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let sym = dlsym(handle, "MRMediaRemoteSendCommand") else { return nil }
        return unsafeBitCast(sym, to: MRSendCommand.self)
    }()

    static func pauseMedia() {
        let kMRPause: UInt32 = 1
        let ok = sendCommand?(kMRPause, nil) ?? false
        log("Pause media sent (ok: \(ok))")
    }

    // MARK: Sleep / screen off. `pmset sleepnow` does not need an admin password.

    static func sleepMac() { runPmset("sleepnow") }
    static func turnOffScreen() { runPmset("displaysleepnow") }

    private static func runPmset(_ arg: String) {
        if UserDefaults.standard.bool(forKey: "dryRun") {
            log("DRY RUN: would run pmset \(arg)")
            return
        }
        log("Running pmset \(arg)")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = [arg]
        try? p.run()
    }

    // MARK: Logging (only to a file when dry-run testing is on)

    static func log(_ message: String) {
        NSLog("SleepTimer: %@", message)
        guard UserDefaults.standard.bool(forKey: "dryRun") else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SleepTimer.log")
        let line = "\(Date()): \(message)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
