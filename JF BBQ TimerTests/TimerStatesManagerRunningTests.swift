// TimerStatesManagerRunningTests.swift
// Grill Time Pro
//
// Swift Testing suite for TimerStatesManager.anyTimerRunning — the published
// aggregate the Preheat bar's disabled state depends on. `states` only
// publishes on add/remove, so this aggregate must track individual timers'
// isRunning flips on its own.

import Testing
import Foundation
@testable import JF_BBQ_Timer

struct TimerStatesManagerRunningTests {
    private func makeManager(timerCount: Int) -> TimerStatesManager {
        let manager = TimerStatesManager()
        let timers = (0..<timerCount).map { i in
            BBQTimer(id: UUID(), name: "T\(i)", preset1: 300, preset2: 60)
        }
        manager.initializeTimerStates(timers: timers)
        return manager
    }

    @Test func falseInitially() {
        let manager = makeManager(timerCount: 2)
        #expect(manager.anyTimerRunning == false)
    }

    @Test func flipsTrueWhenATimerStarts() {
        let manager = makeManager(timerCount: 2)
        manager.states[0].isRunning = true
        #expect(manager.anyTimerRunning == true)
    }

    @Test func staysTrueWhileAnotherStillRuns() {
        let manager = makeManager(timerCount: 2)
        manager.states[0].isRunning = true
        manager.states[1].isRunning = true
        manager.states[0].isRunning = false
        #expect(manager.anyTimerRunning == true)
    }

    @Test func flipsFalseWhenLastTimerStops() {
        let manager = makeManager(timerCount: 2)
        manager.states[0].isRunning = true
        manager.states[0].isRunning = false
        #expect(manager.anyTimerRunning == false)
    }

    @Test func tracksStatesAddedLater() {
        let manager = makeManager(timerCount: 1)
        let extra = BBQTimer(id: UUID(), name: "Late", preset1: 120, preset2: 30)
        let state = manager.addTimerState(for: extra)
        state.isRunning = true
        #expect(manager.anyTimerRunning == true)
    }

    @Test func reflectsAlreadyRunningStateOnAdd() {
        let manager = makeManager(timerCount: 1)
        manager.states[0].isRunning = true
        let extra = BBQTimer(id: UUID(), name: "Late", preset1: 120, preset2: 30)
        _ = manager.addTimerState(for: extra)
        #expect(manager.anyTimerRunning == true)
    }
}
