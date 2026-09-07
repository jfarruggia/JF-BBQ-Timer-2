// DurationPickerMathTests.swift
// Grill Time Pro
//
// Swift Testing suite for DurationPickerMath — the pure split/recombine
// logic behind the shared "tap the value, spin two wheels" duration control
// (duration-picker-spec.md). No UI, no wall clock; just seconds in, two
// wheel values out, and back.

import Testing
@testable import JF_BBQ_Timer

struct DurationPickerMathTests {

    // MARK: - .minutesSeconds components

    @Test func minutesSecondsExactValue() {
        let result = DurationPickerMath.components(seconds: 300, style: .minutesSeconds)
        #expect(result == (5, 0))
    }

    @Test func minutesSecondsExactValueWithSeconds() {
        let result = DurationPickerMath.components(seconds: 330, style: .minutesSeconds)
        #expect(result == (5, 30))
    }

    @Test func minutesSecondsZero() {
        let result = DurationPickerMath.components(seconds: 0, style: .minutesSeconds)
        #expect(result == (0, 0))
    }

    @Test func minutesSecondsClampsAboveWheelMax() {
        // The wheel tops out at 59:55 — it cannot express 60:00.
        let result = DurationPickerMath.components(seconds: 3600, style: .minutesSeconds)
        #expect(result == (59, 55))
    }

    @Test func minutesSecondsRoundsDownToNearestFive() {
        let result = DurationPickerMath.components(seconds: 37, style: .minutesSeconds)
        #expect(result == (0, 35))
    }

    @Test func minutesSecondsRoundsUpToNearestFive() {
        let result = DurationPickerMath.components(seconds: 38, style: .minutesSeconds)
        #expect(result == (0, 40))
    }

    // MARK: - .hoursMinutes components

    @Test func hoursMinutesUnderAnHour() {
        let result = DurationPickerMath.components(seconds: 720, style: .hoursMinutes)
        #expect(result == (0, 12))
    }

    @Test func hoursMinutesExactlyOneHour() {
        let result = DurationPickerMath.components(seconds: 3600, style: .hoursMinutes)
        #expect(result == (1, 0))
    }

    @Test func hoursMinutesMaxValue() {
        let result = DurationPickerMath.components(seconds: 21600, style: .hoursMinutes)
        #expect(result == (6, 0))
    }

    @Test func hoursMinutesRoundsToNearestMinute() {
        // 90 seconds is 1.5 minutes — must round to 2, not truncate to 1.
        let result = DurationPickerMath.components(seconds: 90, style: .hoursMinutes)
        #expect(result == (0, 2))
    }

    // MARK: - Negative input

    @Test func negativeSecondsClampsToZeroMinutesSeconds() {
        let result = DurationPickerMath.components(seconds: -100, style: .minutesSeconds)
        #expect(result == (0, 0))
    }

    @Test func negativeSecondsClampsToZeroHoursMinutes() {
        let result = DurationPickerMath.components(seconds: -100, style: .hoursMinutes)
        #expect(result == (0, 0))
    }

    // MARK: - Recombine

    @Test func recombineClampsAboveMinutesSecondsMax() {
        let result = DurationPickerMath.seconds(from: (60, 0), style: .minutesSeconds)
        #expect(result == 59 * 60 + 55)
    }

    @Test func recombineClampsAboveHoursMinutesMax() {
        let result = DurationPickerMath.seconds(from: (7, 0), style: .hoursMinutes)
        #expect(result == 6 * 3600 + 59 * 60)
    }

    @Test func recombineClampsNegativeToZero() {
        let result = DurationPickerMath.seconds(from: (-1, -1), style: .minutesSeconds)
        #expect(result == 0)
    }

    // MARK: - Round trip (values already on a valid stop)

    @Test func roundTripMinutesSeconds() {
        let stops = [0, 5, 30, 60, 300, 330, 600, 1800, 3595]
        for stop in stops {
            let components = DurationPickerMath.components(seconds: stop, style: .minutesSeconds)
            let recombined = DurationPickerMath.seconds(from: components, style: .minutesSeconds)
            #expect(recombined == stop, "round trip failed for \(stop)")
        }
    }

    @Test func roundTripHoursMinutes() {
        let stops = [0, 60, 720, 3600, 7200, 21600, 6 * 3600 + 59 * 60]
        for stop in stops {
            let components = DurationPickerMath.components(seconds: stop, style: .hoursMinutes)
            let recombined = DurationPickerMath.seconds(from: components, style: .hoursMinutes)
            #expect(recombined == stop, "round trip failed for \(stop)")
        }
    }
}
