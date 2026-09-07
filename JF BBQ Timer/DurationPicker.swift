// DurationPicker.swift
//
// The one shared "tap the value, spin two wheels" duration control used by
// every duration field in Settings (Preheat Duration, Flip Time, Extend Cook
// Time, and the Add-timer sheet's Flip Time / Extend Cook Time). Replaces the
// old +/- steppers per duration-picker-spec.md — Jim compared four options on
// a throwaway screen (DurationEntryOptionsPreview, now deleted) and picked
// this one for being "simple and elegant."

import SwiftUI

/// Which two wheels a field shows. Every duration in the app is either
/// "under an hour, seconds matter" or "hours long, seconds do not".
enum DurationPickerStyle {
    case minutesSeconds   // 0…59 min + 0…59 sec, second wheel steps by 5 s
    case hoursMinutes     // 0…6 hr  + 0…59 min
}

/// Pure split/recombine math for `DurationPickerStyle`, kept separate from
/// the views so it can be unit-tested without any UI. Both wheels have a
/// largest representable stop (the wheel cannot express the field's old
/// 60:00 stepper cap); values above that clamp down to it, and values that
/// don't sit on a valid stop (an odd stored second, a fractional minute)
/// round to the nearest one.
enum DurationPickerMath {
    /// Largest total seconds the `.minutesSeconds` wheels can show: 59 min,
    /// 55 sec (the second wheel steps by 5 and tops out at 55, not 59).
    private static let maxMinutesSecondsTotal = 59 * 60 + 55

    /// Largest total seconds the `.hoursMinutes` wheels can show: 6 hr, 59 min.
    private static let maxHoursMinutesTotal = 6 * 3600 + 59 * 60

    /// Split seconds into the two wheel values for a style, snapping to the
    /// nearest valid stop (seconds round to the nearest 5).
    static func components(seconds: Int, style: DurationPickerStyle) -> (Int, Int) {
        let clamped = max(0, seconds)
        switch style {
        case .minutesSeconds:
            let roundedTotal = Int((Double(clamped) / 5.0).rounded()) * 5
            let cappedTotal = min(roundedTotal, maxMinutesSecondsTotal)
            return (cappedTotal / 60, cappedTotal % 60)
        case .hoursMinutes:
            let roundedTotalMinutes = Int((Double(clamped) / 60.0).rounded())
            let cappedTotalMinutes = min(roundedTotalMinutes, maxHoursMinutesTotal / 60)
            return (cappedTotalMinutes / 60, cappedTotalMinutes % 60)
        }
    }

    /// Recombine two wheel values back into seconds, clamped to 0...max.
    static func seconds(from components: (Int, Int), style: DurationPickerStyle) -> Int {
        switch style {
        case .minutesSeconds:
            let total = components.0 * 60 + components.1
            return min(max(0, total), maxMinutesSecondsTotal)
        case .hoursMinutes:
            let total = components.0 * 3600 + components.1 * 60
            return min(max(0, total), maxHoursMinutesTotal)
        }
    }
}

/// A tappable duration row: label on the left, the value on the right in the
/// accent colour with a chevron, opening a wheel sheet. Accent means
/// tappable in this app — that's why this reads as a control without extra
/// chrome, and why the value must never be accent when it isn't tappable.
struct DurationRow: View {
    let label: String
    let style: DurationPickerStyle
    @Binding var seconds: Int
    /// Called after Done commits a new value. Used for `settings.save()`
    /// when the binding's own setter doesn't already save.
    var onCommit: () -> Void = {}
    /// Shown in place of the formatted value when `seconds == 0`. Nil (the
    /// default) keeps today's behaviour for every existing caller — a zero
    /// duration renders as a normal time. Total Time (the first optional
    /// duration in the app) passes `"Off"`: the wheel sheet is unchanged —
    /// spinning both wheels to zero *is* how you turn it off.
    var offLabel: String? = nil

    @State private var showSheet = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 4) {
                Text(formattedValue)
                    .foregroundColor(Color("TimerAccent"))
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color("TimerAccent"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showSheet = true }
        .sheet(isPresented: $showSheet) {
            DurationWheelSheet(title: label, style: style, seconds: $seconds, onCommit: onCommit)
        }
    }

    private var formattedValue: String {
        if seconds == 0, let offLabel {
            return offLabel
        }
        switch style {
        case .minutesSeconds:
            return TimeFormatter.compactTimeString(from: seconds)
        case .hoursMinutes:
            return TimeFormatter.timeString(from: seconds)
        }
    }
}

/// The wheel sheet shared by every `DurationRow`. Edits a scratch value
/// seeded in `.onAppear` from `seconds` — Cancel must not write, only Done
/// writes back into the binding and calls `onCommit`.
private struct DurationWheelSheet: View {
    let title: String
    let style: DurationPickerStyle
    @Binding var seconds: Int
    var onCommit: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var first: Int = 0
    @State private var second: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    seconds = DurationPickerMath.seconds(from: (first, second), style: style)
                    onCommit()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding()

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Picker(firstUnit, selection: $first) {
                        ForEach(firstRange, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    Text(firstUnit)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                VStack(spacing: 2) {
                    Picker(secondUnit, selection: $second) {
                        ForEach(secondRange, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    Text(secondUnit)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.vertical, 8)
            .background(
                // Near-opaque dark panel behind just the wheels — this is
                // where the legibility problem actually is (dimmed unselected
                // rows + the min/sec captions), so the darkness is localised
                // here rather than flattening the whole sheet. The header
                // (Cancel / title / Done) is large/bold and already reads
                // fine on the lighter ember behind it. Flat fill only — not
                // a second glass surface, per the app's no-glass-on-glass rule.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                    .padding(.horizontal, 12)
            )

            Spacer(minLength: 0)
        }
        .onAppear {
            let seeded = DurationPickerMath.components(seconds: seconds, style: style)
            first = seeded.0
            second = seeded.1
        }
        .presentationDetents([.height(320)])
        // Moderate scrim between the content and the ember bed so the sheet
        // still reads as part of the app; the wheels get their own darker
        // panel above for the legibility-critical text. Layered here (before
        // .immersiveGlassBackground() adds the ember behind everything) it
        // sits above the ember and below the content. Not a second glass
        // surface — just a flat scrim, per the app's no-glass-on-glass rule.
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .immersiveGlassBackground()
    }

    private var firstRange: [Int] {
        switch style {
        case .minutesSeconds: return Array(0..<60)
        case .hoursMinutes: return Array(0..<7)
        }
    }

    private var secondRange: [Int] {
        switch style {
        case .minutesSeconds: return Array(stride(from: 0, to: 60, by: 5))
        case .hoursMinutes: return Array(0..<60)
        }
    }

    private var firstUnit: String {
        switch style {
        case .minutesSeconds: return "min"
        case .hoursMinutes: return "hr"
        }
    }

    private var secondUnit: String {
        switch style {
        case .minutesSeconds: return "sec"
        case .hoursMinutes: return "min"
        }
    }
}
