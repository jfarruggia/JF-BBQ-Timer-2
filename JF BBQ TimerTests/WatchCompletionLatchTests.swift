import Testing
import Foundation
@testable import JF_BBQ_Timer

struct WatchCompletionLatchTests {
    private let end = Date(timeIntervalSince1970: 1_000_000)

    @Test func catchUpWindowEdges() {
        #expect(WatchCompletionLatch.isInCatchUpWindow(endDate: end, now: end.addingTimeInterval(599)))
        #expect(!WatchCompletionLatch.isInCatchUpWindow(endDate: end, now: end.addingTimeInterval(600)))
        #expect(!WatchCompletionLatch.isInCatchUpWindow(endDate: end, now: end.addingTimeInterval(601)))
    }

    @Test func notDueBeforeEnd() {
        #expect(!WatchCompletionLatch.isInCatchUpWindow(endDate: end, now: end.addingTimeInterval(-1)))
        #expect(WatchCompletionLatch.isInCatchUpWindow(endDate: end, now: end))
    }

    @Test func samePairAlertsOnce() {
        var latch = WatchCompletionLatch()
        let c = WatchCompletionLatch.Candidate(timerId: "a", endDate: end)
        let r1 = latch.nextDue(from: [c], now: end.addingTimeInterval(1))
        #expect(r1 == c)
        let r2 = latch.nextDue(from: [c], now: end.addingTimeInterval(2))
        #expect(r2 == nil)
        let r3 = latch.claim(timerId: "a", endDate: end)
        #expect(!r3)
    }

    @Test func newEndDateAlertsAgain() {
        var latch = WatchCompletionLatch()
        let r4 = latch.claim(timerId: "a", endDate: end)
        #expect(r4)
        let later = end.addingTimeInterval(120)
        let c = WatchCompletionLatch.Candidate(timerId: "a", endDate: later)
        let r5 = latch.nextDue(from: [c], now: later.addingTimeInterval(1))
        #expect(r5 == c)
    }

    @Test func staleRunIsNotAlerted() {
        var latch = WatchCompletionLatch()
        let c = WatchCompletionLatch.Candidate(timerId: "a", endDate: end)
        let r6 = latch.nextDue(from: [c], now: end.addingTimeInterval(601))
        #expect(r6 == nil)
        let r7 = latch.nextDue(from: [c], now: end.addingTimeInterval(599))
        #expect(r7 == c)
    }

    @Test func otherTimerStillDueAfterFirstClaimed() {
        var latch = WatchCompletionLatch()
        let a = WatchCompletionLatch.Candidate(timerId: "a", endDate: end)
        let b = WatchCompletionLatch.Candidate(timerId: "b", endDate: end)
        let now = end.addingTimeInterval(1)
        let r8 = latch.nextDue(from: [a, b], now: now)
        #expect(r8 == a)
        let r9 = latch.nextDue(from: [a, b], now: now)
        #expect(r9 == b)
        let r10 = latch.nextDue(from: [a, b], now: now)
        #expect(r10 == nil)
    }

    @Test func notificationAfterTickDoesNotDouble() {
        var latch = WatchCompletionLatch()
        let r11 = latch.claim(timerId: "a", endDate: end)
        #expect(r11)
        let r12 = latch.claimForNotification(timerId: "a", rowEndDate: end, now: end)
        #expect(!r12)
        // Snapshot already moved on (no end date): still no second alert.
        let r13 = latch.claimForNotification(timerId: "a", rowEndDate: nil, now: end.addingTimeInterval(2))
        #expect(!r13)
    }

    @Test func notificationAloneAlertsOnce() {
        var latch = WatchCompletionLatch()
        let now = end.addingTimeInterval(1)
        let r14 = latch.claimForNotification(timerId: "a", rowEndDate: nil, now: now)
        #expect(r14)
        let r15 = latch.claimForNotification(timerId: "a", rowEndDate: nil, now: now.addingTimeInterval(1))
        #expect(!r15)
        let r16 = latch.claimForNotification(timerId: "a", rowEndDate: nil, now: now.addingTimeInterval(700))
        #expect(r16)
    }

    @Test func messageIsNameFirst() {
        #expect(WatchAlertMessage.timerComplete(name: "Ribeye") == "Ribeye timer is complete")
        #expect(WatchAlertMessage.timerComplete(name: "  ") == "Timer is complete")
    }
}
