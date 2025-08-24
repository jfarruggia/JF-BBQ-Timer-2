//
//  TimerCenter+WatchSync.swift
//  JF BBQ Timer (iOS)
//
//  Adds a compact payload builder for watch sync. If `TimerCenter` doesn't
//  exist yet, this file also provides a minimal shell you can expand later.
//

import Foundation

#if os(iOS)

// MARK: - Minimal TimerCenter shell (extend or replace with the real impl)

/// Minimal timer manager for iOS used to sync with the watch. Replace or
/// extend with your existing timer engine when available.
@MainActor
public final class TimerCenter {
    public struct TimerModel: Identifiable, Equatable {
        public enum State: String { case running, paused, stopped }
        public let id: UUID
        public var name: String
        public var remainingSeconds: Int
        public var state: State
    }

    public static let shared = TimerCenter()

    /// Current timers shown in the iOS app
    public var timers: [TimerModel] = []

    private var commandObserver: NSObjectProtocol?

    public init() {
        // Listen for commands coming from the watch and apply them to the timers
        commandObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("receivedCommand"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let payload = note.userInfo as? [String: Any] else { return }
            // Hop to the main actor explicitly to satisfy Swift 6 concurrency rules
            Task { @MainActor in
                self.handleIncomingCommand(payload)
            }
        }
    }

    deinit {
        if let commandObserver { NotificationCenter.default.removeObserver(commandObserver) }
    }

    // MARK: - Public timer controls (stubs; integrate with your engine)

    public func resetTimer(_ id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].remainingSeconds = 0
            timers[index].state = .stopped
        }
    }

    public func pauseTimer(_ id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].state = .paused
        }
    }

    public func resumeTimer(_ id: UUID) {
        if let index = timers.firstIndex(where: { $0.id == id }) {
            timers[index].state = .running
        }
    }

    public func extendTimer(_ id: UUID, by seconds: Int) {
        guard seconds != 0 else { return }
        if let index = timers.firstIndex(where: { $0.id == id }) {
            let newValue = max(0, timers[index].remainingSeconds + seconds)
            timers[index].remainingSeconds = newValue
        }
    }

    // MARK: - Publishing

    /// Builds and sends the latest timers snapshot to the watch.
    public func publishTimersToWatch() {
        let payload = watchPayload(from: timers)
        WCSessionManager.shared.sendTimersSnapshot(payload)
    }

    // MARK: - Private helpers

    /// Compact, plist-safe payload consumed by the watch list UI.
    private func watchPayload(from timers: [TimerModel]) -> [String: Any] {
        let array: [[String: Any]] = timers.map { t in
            [
                "id": t.id.uuidString,
                "name": t.name,
                "remaining": Int(t.remainingSeconds),
                "state": t.state.rawValue
            ]
        }
        return ["timers": array]
    }

    private func handleIncomingCommand(_ dict: [String: Any]) {
        guard let action = dict["action"] as? String,
              let idString = dict["timerId"] as? String,
              let uuid = UUID(uuidString: idString) else { return }

        switch action {
        case "reset":
            resetTimer(uuid)
        case "pause":
            pauseTimer(uuid)
        case "resume":
            resumeTimer(uuid)
        case "extend":
            let seconds = (dict["seconds"] as? Int) ?? 60
            extendTimer(uuid, by: seconds)
        default:
            break
        }

        // Mirror changes back to the watch
        publishTimersToWatch()
    }
}

#endif


