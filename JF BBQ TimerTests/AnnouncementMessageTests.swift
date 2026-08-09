// AnnouncementMessageTests.swift
// Grill Time Pro
//
// Swift Testing suite for AnnouncementMessage — the shared name-first
// completion-phrase builder used by both real announcements and the
// Settings test button.

import Testing
@testable import JF_BBQ_Timer

struct AnnouncementMessageTests {
    @Test func defaultMessageIsNameFirst() {
        #expect(AnnouncementMessage.spoken(custom: "timer is complete", timerName: "Ribeye")
                == "Ribeye timer is complete")
    }

    @Test func emptyMessageFallsBackNameFirst() {
        #expect(AnnouncementMessage.spoken(custom: "", timerName: "Ribeye")
                == "Ribeye timer is complete.")
    }

    @Test func whitespaceOnlyMessageFallsBack() {
        #expect(AnnouncementMessage.spoken(custom: "   ", timerName: "Ribeye")
                == "Ribeye timer is complete.")
    }

    @Test func customMessageIsPrependedWithName() {
        #expect(AnnouncementMessage.spoken(custom: "is ready to flip", timerName: "Veggies")
                == "Veggies is ready to flip")
    }

    @Test func timerPlaceholderControlsPlacement() {
        #expect(AnnouncementMessage.spoken(custom: "Go check the {timer} now", timerName: "Ribeye")
                == "Go check the Ribeye now")
    }

    @Test func legacyDefaultMigratesToNewDefault() {
        #expect(AnnouncementMessage.migratedStoredMessage("Your timer has completed")
                == AnnouncementMessage.defaultMessage)
    }

    @Test func legacyDefaultMigratesCaseInsensitively() {
        #expect(AnnouncementMessage.migratedStoredMessage("your timer has completed ")
                == AnnouncementMessage.defaultMessage)
    }

    @Test func emptyStoredMessageMigratesToDefault() {
        #expect(AnnouncementMessage.migratedStoredMessage("")
                == AnnouncementMessage.defaultMessage)
    }

    @Test func customStoredMessageIsPreserved() {
        #expect(AnnouncementMessage.migratedStoredMessage("Dinner bell for {timer}!")
                == "Dinner bell for {timer}!")
    }
}
