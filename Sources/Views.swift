import SwiftUI

private let accent = Color.indigo

// MARK: - Root

struct MenuContent: View {
    @EnvironmentObject var model: TimerModel

    var body: some View {
        VStack(spacing: 14) {
            header
            if model.showSettings {
                SettingsPage()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if model.isRunning {
                RunningPage()
                    .transition(.opacity)
            } else {
                PickerPage()
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(width: 300)
        .animation(.snappy(duration: 0.25), value: model.showSettings)
        .animation(.snappy(duration: 0.25), value: model.isRunning)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if model.showSettings {
                Button { model.showSettings = false } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle())
                Text("Settings").font(.system(size: 15, weight: .semibold))
            } else {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(accent)
                    .font(.system(size: 15))
                Text("Sleep Timer").font(.system(size: 15, weight: .semibold))
            }
            Spacer()
            if !model.showSettings {
                Button { model.showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 14))
                }
                .buttonStyle(IconButtonStyle())
                .help("Settings")
            }
        }
    }
}

// MARK: - Choosing a time

struct PickerPage: View {
    @EnvironmentObject var model: TimerModel

    var body: some View {
        VStack(spacing: 14) {
            TimeWheels(hours: $model.pickedHours, minutes: $model.pickedMinutes)

            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 14)

            Button { model.start(minutes: model.pickedTotalMinutes) } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(fill: accent, foreground: .white))
            .disabled(model.pickedTotalMinutes == 0)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var summary: String {
        let total = model.pickedTotalMinutes
        guard total > 0 else { return "Scroll to pick a time" }
        let end = Date().addingTimeInterval(TimeInterval(total * 60))
        let verb = model.endAction == .sleep ? "Mac sleeps" : "Screen turns off"
        return "\(verb) at \(end.formatted(date: .omitted, time: .shortened))"
    }
}

/// Two iPhone-style scroll wheels: hours and minutes.
struct TimeWheels: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    private let rowHeight: CGFloat = 36

    var body: some View {
        ZStack {
            // The grey band that marks the chosen row.
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(height: rowHeight)

            HStack(spacing: 0) {
                WheelColumn(range: 0...12, selection: $hours, rowHeight: rowHeight,
                            unit: { $0 == 1 ? "hour" : "hours" })
                    .frame(maxWidth: .infinity)
                WheelColumn(range: 0...59, selection: $minutes, rowHeight: rowHeight,
                            unit: { _ in "min" })
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: rowHeight * 5)
    }
}

// MARK: - Timer running

struct RunningPage: View {
    @EnvironmentObject var model: TimerModel

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.progress)

                VStack(spacing: 6) {
                    Text(model.longRemaining)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .monospacedDigit()
                    if let end = model.endDate {
                        Label(end.formatted(date: .omitted, time: .shortened),
                              systemImage: model.endAction == .sleep ? "moon.zzz.fill" : "display")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 190, height: 190)
            .padding(.top, 4)

            HStack {
                Button("Cancel") { model.cancel() }
                    .buttonStyle(CircleButtonStyle(fill: Color.primary.opacity(0.1), foreground: .primary))
                Spacer()
                Button("+15 min") { model.extend(minutes: 15) }
                    .buttonStyle(CircleButtonStyle(fill: accent.opacity(0.22), foreground: accent))
            }
            .padding(.horizontal, 8)

            Button(model.endAction == .sleep ? "Sleep now" : "Screen off now") { model.finishNow() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings

struct SettingsPage: View {
    @EnvironmentObject var model: TimerModel

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("When time's up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: $model.endAction) {
                    ForEach(EndAction.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                row("Pause videos and music", isOn: $model.pauseMedia)
                Divider().padding(.leading, 12)
                row("Fade volume in last minute", isOn: $model.fadeVolume)
                Divider().padding(.leading, 12)
                row("Open when Mac starts", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05)))

            Button { NSApp.terminate(nil) } label: {
                Text("Quit Sleep Timer").frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(fill: Color.primary.opacity(0.07), foreground: .primary))
        }
    }

    private func row(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Button styles

struct PillButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(Rectangle())
    }
}

struct CircleButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 70, height: 70)
            .background(Circle().fill(fill))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Circle())
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.0)))
            .contentShape(Circle())
    }
}
