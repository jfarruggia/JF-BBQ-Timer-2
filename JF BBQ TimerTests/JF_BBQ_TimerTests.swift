//
//  JF_BBQ_TimerTests.swift
//  JF BBQ TimerTests
//
//  Created by James Farruggia on 3/29/25.
//

import Testing
import Foundation
@testable import JF_BBQ_Timer

struct JF_BBQ_TimerTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - TimerOrdering (main-screen drag-to-reorder)

struct TimerOrderingTests {
    private func timer(_ hexDigit: String, name: String) -> BBQTimer {
        BBQTimer(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(hexDigit)")!,
                 name: name, preset1: 300, preset2: 60)
    }

    @Test func emptyOrderKeepsNaturalOrder() {
        let timers = [timer("1", name: "A"), timer("2", name: "B")]
        #expect(TimerOrdering.apply(order: [], to: timers) == timers)
    }

    @Test func fullOrderIsApplied() {
        let a = timer("1", name: "A"), b = timer("2", name: "B"), c = timer("3", name: "C")
        let result = TimerOrdering.apply(order: [c.id.uuidString, a.id.uuidString, b.id.uuidString],
                                         to: [a, b, c])
        #expect(result == [c, a, b])
    }

    @Test func unknownIdsInOrderAreIgnored() {
        let a = timer("1", name: "A"), b = timer("2", name: "B")
        let deleted = UUID().uuidString
        let result = TimerOrdering.apply(order: [deleted, b.id.uuidString, a.id.uuidString],
                                         to: [a, b])
        #expect(result == [b, a])
    }

    @Test func timersMissingFromOrderFollowInNaturalOrder() {
        // e.g. timers added after the user last dragged
        let a = timer("1", name: "A"), b = timer("2", name: "B")
        let new1 = timer("3", name: "New1"), new2 = timer("4", name: "New2")
        let result = TimerOrdering.apply(order: [b.id.uuidString, a.id.uuidString],
                                         to: [a, b, new1, new2])
        #expect(result == [b, a, new1, new2])
    }

    @Test func duplicateIdsInOrderApplyOnce() {
        let a = timer("1", name: "A"), b = timer("2", name: "B")
        let result = TimerOrdering.apply(order: [b.id.uuidString, b.id.uuidString, a.id.uuidString],
                                         to: [a, b])
        #expect(result == [b, a])
    }
}
