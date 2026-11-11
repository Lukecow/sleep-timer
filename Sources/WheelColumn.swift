import AppKit
import SwiftUI

/// Where a wheel is currently turned to (a fractional row index while moving).
final class WheelState: ObservableObject {
    @Published var position: Double = 0
    var isSettled = true
}

/// One iPhone-style spinning column of numbers.
/// Turn it with a trackpad swipe, the mouse wheel, by dragging, or click a number.
struct WheelColumn: View {
    let range: ClosedRange<Int>
    @Binding var selection: Int
    let rowHeight: CGFloat
    /// The word shown beside the chosen number ("hours", "min"). Part of the scrollable area.
    let unit: (Int) -> String

    @StateObject private var state = WheelState()

    /// Each row is this many degrees around the drum.
    private let rowAngle = 20.0
    private var radius: Double { Double(rowHeight) / (rowAngle * .pi / 180) }
    private var count: Int { range.count }

    var body: some View {
        HStack(spacing: 0) {
            drum.frame(width: 58)
            Text(unit(selection))
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 64, alignment: .leading)
                .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(
            WheelInput(
                rowHeight: rowHeight,
                onMove: { points in move(by: points) },
                onSettle: { settle() },
                onStep: { steps in select(index: Int(state.position.rounded()) + steps) },
                onClickRow: { rows in select(index: Int(state.position.rounded()) + rows) }
            )
        )
        .onAppear { state.position = Double(selection - range.lowerBound) }
        .onChange(of: selection) { _, newValue in
            if state.isSettled { state.position = Double(newValue - range.lowerBound) }
        }
        .accessibilityElement()
        .accessibilityValue("\(selection) \(unit(selection))")
        .accessibilityAdjustableAction { direction in
            select(index: (selection - range.lowerBound) + (direction == .increment ? 1 : -1))
        }
    }

    private var drum: some View {
        let centre = Int(state.position.rounded())
        let visible = max(0, centre - 5)...min(count - 1, max(0, centre + 5))

        return ZStack {
            ForEach(Array(visible), id: \.self) { index in
                let angle = (Double(index) - state.position) * rowAngle
                if abs(angle) < 88 {
                    let rad = angle * .pi / 180
                    Text("\(range.lowerBound + index)")
                        .font(.system(size: 23, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(abs(angle) < rowAngle / 2 ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: rowHeight)
                        .rotation3DEffect(.degrees(-angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                        .opacity(pow(cos(rad), 1.6))
                        .offset(y: radius * sin(rad))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    /// `points` > 0 means the numbers move down (smaller numbers come into view).
    private func move(by points: CGFloat) {
        state.isSettled = false
        let limitLow = -0.45, limitHigh = Double(count - 1) + 0.45
        state.position = min(limitHigh, max(limitLow, state.position - Double(points / rowHeight)))
    }

    private func settle() {
        select(index: Int(state.position.rounded()))
    }

    private func select(index: Int) {
        let i = min(count - 1, max(0, index))
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            state.position = Double(i)
        }
        state.isSettled = true
        if selection != range.lowerBound + i { selection = range.lowerBound + i }
    }
}

// MARK: - Mouse / trackpad input

private struct WheelInput: NSViewRepresentable {
    let rowHeight: CGFloat
    let onMove: (CGFloat) -> Void
    let onSettle: () -> Void
    let onStep: (Int) -> Void
    let onClickRow: (Int) -> Void

    func makeNSView(context: Context) -> WheelInputView { WheelInputView() }

    func updateNSView(_ view: WheelInputView, context: Context) {
        view.rowHeight = rowHeight
        view.onMove = onMove
        view.onSettle = onSettle
        view.onStep = onStep
        view.onClickRow = onClickRow
    }
}

final class WheelInputView: NSView {
    var rowHeight: CGFloat = 36
    var onMove: (CGFloat) -> Void = { _ in }
    var onSettle: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onClickRow: (Int) -> Void = { _ in }

    private var settleWork: DispatchWorkItem?
    private var lastDragY: CGFloat = 0
    private var dragDistance: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            // Trackpad or Magic Mouse: follow the fingers, snap when they stop.
            onMove(event.scrollingDeltaY)
            scheduleSettle()
        } else if event.scrollingDeltaY != 0 {
            // Ordinary mouse wheel: one notch = one number.
            onStep(event.scrollingDeltaY > 0 ? -1 : 1)
        }
    }

    private func scheduleSettle() {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onSettle() }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    override func mouseDown(with event: NSEvent) {
        lastDragY = event.locationInWindow.y
        dragDistance = 0
    }

    override func mouseDragged(with event: NSEvent) {
        let y = event.locationInWindow.y
        let dy = y - lastDragY          // up is positive
        lastDragY = y
        dragDistance += abs(dy)
        onMove(-dy)
    }

    override func mouseUp(with event: NSEvent) {
        if dragDistance < 3 {
            // A click: pick the number that was clicked.
            let p = convert(event.locationInWindow, from: nil)
            let rowsFromCentre = Int(((bounds.midY - p.y) / rowHeight).rounded())
            onClickRow(isFlipped ? -rowsFromCentre : rowsFromCentre)
        } else {
            onSettle()
        }
    }
}
