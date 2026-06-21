// ProbeModels.swift
// Grill Time Pro
//
// Domain models for the Combustion Predictive Probe.
// Foundation-only — safe to compile into both iOS and watchOS targets.
// All temperatures are stored in °C (the probe's native unit).

import Foundation

// MARK: - ProbeMode

/// Operating mode of the probe (bits 0–1 of the ModeId byte).
enum ProbeMode: UInt8, CaseIterable {
    case normal      = 0
    case instantRead = 1
    case reserved    = 2
    case error       = 3
}

// MARK: - ProbeColor

/// Colour identifier for the probe (bits 2–4 of the ModeId byte).
/// Values 0x00–0x07 map to colour1…colour8.
enum ProbeColor: UInt8, CaseIterable {
    case color1 = 0
    case color2 = 1
    case color3 = 2
    case color4 = 3
    case color5 = 4
    case color6 = 5
    case color7 = 6
    case color8 = 7
}

// MARK: - ProbeID

/// Numeric identifier for the probe (bits 5–7 of the ModeId byte).
/// Values 0x00–0x07 map to ID1…ID8.
enum ProbeID: UInt8, CaseIterable {
    case id1 = 0
    case id2 = 1
    case id3 = 2
    case id4 = 3
    case id5 = 4
    case id6 = 5
    case id7 = 6
    case id8 = 7
}

// MARK: - BatteryStatus

/// Battery level indicator (bit 0 of the Battery+Virtual Sensors byte).
enum BatteryStatus: UInt8 {
    case ok  = 0
    case low = 1
}

// MARK: - Virtual sensor enums

/// Which physical thermistor is currently acting as Core (bits 1–3 of virtual-sensor nibble).
/// Raw value 0x00–0x05 maps to T1–T6; values outside range default to T1.
enum CoreSensor: UInt8 {
    case t1 = 0
    case t2 = 1
    case t3 = 2
    case t4 = 3
    case t5 = 4
    case t6 = 5

    /// Failable init — returns nil for values outside the valid range.
    init?(raw: UInt8) {
        self.init(rawValue: raw)
    }

    /// Thermistor index (1-based) for use with `ProbeTemperatures.temperature(forSensorIndex:)`.
    var thermistorIndex: Int { Int(rawValue) + 1 }
}

/// Which physical thermistor is currently acting as Surface (bits 4–5 of virtual-sensor nibble).
/// Raw value 0x00–0x03 maps to T4–T7; values outside range default to T4.
enum SurfaceSensor: UInt8 {
    case t4 = 0
    case t5 = 1
    case t6 = 2
    case t7 = 3

    init?(raw: UInt8) {
        self.init(rawValue: raw)
    }

    /// Thermistor index (1-based).
    var thermistorIndex: Int { Int(rawValue) + 4 }
}

/// Which physical thermistor is currently acting as Ambient (bits 6–7 of virtual-sensor nibble).
/// Raw value 0x00–0x03 maps to T5–T8; values outside range default to T5.
enum AmbientSensor: UInt8 {
    case t5 = 0
    case t6 = 1
    case t7 = 2
    case t8 = 3

    init?(raw: UInt8) {
        self.init(rawValue: raw)
    }

    /// Thermistor index (1-based).
    var thermistorIndex: Int { Int(rawValue) + 5 }
}

// MARK: - PredictionState

/// Prediction state field (bits 0–3 of prediction block byte 0).
enum PredictionState: UInt8 {
    case probeNotInserted       = 0
    case probeInserted          = 1
    case cooking                = 2
    case predicting             = 3
    case removalPredictionDone  = 4
    // 5–14 reserved
    case unknown                = 15

    init(raw: UInt8) {
        self = PredictionState(rawValue: raw) ?? .unknown
    }

    /// True when the probe is actively computing a time-to-removal.
    var isActivePrediction: Bool {
        self == .predicting
    }
}

// MARK: - PredictionMode

/// Prediction mode field (bits 4–5 of prediction block byte 0).
enum PredictionMode: UInt8 {
    case none        = 0
    case timeToRemoval = 1
    case removal     = 2
    case reserved    = 3
}

// MARK: - PredictionType

/// Prediction type field (bits 6–7 of prediction block byte 0).
enum PredictionType: UInt8 {
    case none    = 0
    case removal = 1
    case resting = 2
    case reserved = 3
}

// MARK: - ProbeTemperatures

/// The eight thermistor readings decoded from a 13-byte temperature block.
/// T1 is at the probe tip; T8 is at the handle end.
/// All values are in °C.
struct ProbeTemperatures {
    /// Raw °C values indexed T1…T8 (stored as 0-based array, so t[0] = T1).
    let values: [Double]  // always count == 8

    init(values: [Double]) {
        precondition(values.count == 8, "ProbeTemperatures requires exactly 8 values")
        self.values = values
    }

    /// Returns the temperature (°C) for a 1-based thermistor index (1…8).
    /// Returns nil for indices outside that range.
    func temperature(forSensorIndex index: Int) -> Double? {
        guard index >= 1 && index <= 8 else { return nil }
        return values[index - 1]
    }

    // Convenience accessors
    var t1: Double { values[0] }
    var t2: Double { values[1] }
    var t3: Double { values[2] }
    var t4: Double { values[3] }
    var t5: Double { values[4] }
    var t6: Double { values[5] }
    var t7: Double { values[6] }
    var t8: Double { values[7] }
}

// MARK: - ProbePrediction

/// Decoded prediction-status block from the probe.
struct ProbePrediction {
    let state: PredictionState
    let mode: PredictionMode
    let type: PredictionType

    /// Target core temperature the cook is aimed at (°C).
    let setPointTempC: Double

    /// Core temperature when the prediction engine started tracking (°C).
    let heatStartTempC: Double

    /// Estimated time until the meat hits the set point, in seconds.
    /// Fresh on every notification — this number drifts as cooking conditions change.
    let predictionSeconds: UInt32

    /// Probe's current estimated core temperature (°C).
    let estimatedCoreTempC: Double

    // MARK: Derived values

    /// Linear progress toward the target temperature.
    /// `(estimatedCore − heatStart) / (setPoint − heatStart)`, clamped 0…1.
    /// Returns nil when the denominator is ≤ 0 (set point ≤ heat start).
    var percentToRemoval: Double? {
        let denominator = setPointTempC - heatStartTempC
        guard denominator > 0 else { return nil }
        let raw = (estimatedCoreTempC - heatStartTempC) / denominator
        return max(0.0, min(1.0, raw))
    }

    /// Converts `predictionSeconds` to an absolute `Date` by adding to `now`.
    /// Returns nil when the probe is not in an active predicting state.
    /// The `now` parameter MUST be injected — never call `Date()` inside this method.
    func predictedReadyDate(from now: Date) -> Date? {
        guard state.isActivePrediction else { return nil }
        return now.addingTimeInterval(TimeInterval(predictionSeconds))
    }
}

// MARK: - ProbeReading

/// Fully decoded snapshot from a single Probe Status notification.
struct ProbeReading {
    // Log sequence range (decoded but no special handling required)
    let minLogSequence: UInt32
    let maxLogSequence: UInt32

    // All eight thermistor readings
    let temperatures: ProbeTemperatures

    // Mode/ID byte fields
    let mode: ProbeMode
    let probeColor: ProbeColor
    let probeID: ProbeID

    // Battery + virtual sensor fields
    let batteryStatus: BatteryStatus
    let coreSensor: CoreSensor
    let surfaceSensor: SurfaceSensor
    let ambientSensor: AmbientSensor

    // Resolved virtual-sensor temperatures (°C)
    var coreTempC: Double    { temperatures.temperature(forSensorIndex: coreSensor.thermistorIndex) ?? temperatures.t1 }
    var surfaceTempC: Double { temperatures.temperature(forSensorIndex: surfaceSensor.thermistorIndex) ?? temperatures.t4 }
    var ambientTempC: Double { temperatures.temperature(forSensorIndex: ambientSensor.thermistorIndex) ?? temperatures.t5 }

    // Prediction
    let prediction: ProbePrediction
}
