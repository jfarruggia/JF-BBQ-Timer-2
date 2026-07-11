// ProbeUART.swift
// Grill Time Pro
//
// Pure encoding/decoding for the Combustion probe's UART command channel
// (Nordic UART Service). Foundation-only — no CoreBluetooth — so it is safe
// for both targets and fully unit-testable.
//
// Wire format transcribed from the Combustion BLE spec and cross-checked
// against combustion-ios-ble (Request.swift / Response.swift / Data+CRC.swift):
//   Request:  0xCA 0xFE | CRC16 LE (2) | type (1) | payload len (1) | payload
//   Response: 0xCA 0xFE | CRC16 LE (2) | type (1) | success (1) | payload len (1) | payload
// The CRC covers everything AFTER the CRC field (request: type+len+payload;
// response: type+success+len+payload) — never the sync bytes.

import Foundation

// MARK: - Message types

/// UART command identifiers (Combustion spec, UART messages). Only commands the
/// app actually sends are listed; extend as new commands are adopted.
enum ProbeUARTMessageType: UInt8 {
    case setPrediction = 0x05
}

// MARK: - Decoded response

/// One parsed UART response frame from the probe.
struct ProbeUARTResponse: Equatable {
    let type: ProbeUARTMessageType
    let success: Bool
    let payload: Data
}

// MARK: - ProbeUART

enum ProbeUART {

    static let requestHeaderLength  = 6
    static let responseHeaderLength = 7

    // MARK: CRC

    /// CRC-16-CCITT "false" variant: poly 0x1021, init 0xFFFF, unreflected, no
    /// final XOR — the checksum Combustion uses for UART frames.
    /// Standard check value: ASCII "123456789" → 0x29B1 (pinned in tests).
    static func crc16ccitt(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            for bit in 0..<8 {
                let inBit  = (byte >> (7 - bit)) & 1 == 1
                let topBit = (crc >> 15) & 1 == 1
                crc <<= 1
                if inBit != topBit { crc ^= 0x1021 }
            }
        }
        return crc
    }

    // MARK: Request encoding

    /// Frames a request: sync (2) | CRC16 LE (2) | type (1) | payload len (1) | payload.
    static func encodeRequest(type: ProbeUARTMessageType, payload: Data) -> Data {
        var body = Data([type.rawValue, UInt8(payload.count)])
        body.append(payload)
        let crc = crc16ccitt(body)
        var frame = Data([0xCA, 0xFE, UInt8(crc & 0xFF), UInt8(crc >> 8)])
        frame.append(body)
        return frame
    }

    /// Set Prediction request (type 0x05). Payload is one little-endian UInt16
    /// packing bits 0–9 = set point in 0.1 °C steps and bits 10–11 = prediction
    /// mode — matches combustion-ios-ble's `(mode << 10) | rawSetPoint`.
    /// The set point is clamped to the field's representable 0…102.3 °C range.
    static func encodeSetPrediction(setPointCelsius: Double, mode: PredictionMode) -> Data {
        let tenths = (setPointCelsius * 10).rounded()
        let raw = tenths.isFinite ? UInt16(min(1023, max(0, tenths))) : 0
        let packed = (UInt16(mode.rawValue) << 10) | raw
        return encodeRequest(
            type: .setPrediction,
            payload: Data([UInt8(packed & 0xFF), UInt8(packed >> 8)])
        )
    }

    // MARK: Response decoding

    /// Parses every complete response frame in `data`. A frame that fails
    /// validation (bad sync, bad CRC, truncated) stops parsing — same policy as
    /// the reference implementation. Frames with a valid checksum but an
    /// unrecognised message type are consumed and skipped.
    static func decodeResponses(_ data: Data) -> [ProbeUARTResponse] {
        let bytes = [UInt8](data)
        var responses: [ProbeUARTResponse] = []
        var offset = 0
        while bytes.count - offset >= responseHeaderLength {
            guard bytes[offset] == 0xCA, bytes[offset + 1] == 0xFE else { break }
            let payloadLength = Int(bytes[offset + 6])
            let frameLength = responseHeaderLength + payloadLength
            guard bytes.count - offset >= frameLength else { break }
            let wireCRC = UInt16(bytes[offset + 2]) | (UInt16(bytes[offset + 3]) << 8)
            let crcBody = Data(bytes[(offset + 4)..<(offset + frameLength)])
            guard crc16ccitt(crcBody) == wireCRC else { break }
            if let type = ProbeUARTMessageType(rawValue: bytes[offset + 4]) {
                responses.append(ProbeUARTResponse(
                    type: type,
                    success: bytes[offset + 5] != 0,
                    payload: Data(bytes[(offset + 7)..<(offset + frameLength)])
                ))
            }
            offset += frameLength
        }
        return responses
    }
}
