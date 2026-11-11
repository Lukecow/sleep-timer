import SwiftUI

@main
struct SleepTimerApp: App {
    @StateObject private var model = TimerModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: TimerModel
    var body: some View {
        if model.isRunning {
            HStack(spacing: 3) {
                Image(systemName: "moon.zzz.fill")
                Text(model.shortRemaining).monospacedDigit()
            }
        } else {
            Image(systemName: "moon.zzz")
        }
    }
}
