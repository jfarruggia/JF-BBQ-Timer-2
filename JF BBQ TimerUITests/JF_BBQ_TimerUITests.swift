//
//  JF_BBQ_TimerUITests.swift
//  JF BBQ TimerUITests
//
//  Created by James Farruggia on 3/29/25.
//

import XCTest

class JF_BBQ_TimerUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Skip onboarding so a fresh simulator/test-clone lands on the main
        // screen (the app's own UI-test scaffolding, see applyUITestArguments).
        app.launchArguments += ["-UITEST_SKIP_ONBOARDING"]
        app.launch()
    }
    
    // MARK: - Basic Navigation Tests
    
    func testBasicNavigation() throws {
        // Test settings navigation
        let settingsButton = app.buttons["SettingsButton"]
        XCTAssertTrue(settingsButton.exists, "Settings button should be visible")
        settingsButton.tap()
        
        // Verify settings screen elements
        let soundToggle = app.switches["SoundAlerts"]
        XCTAssertTrue(soundToggle.exists, "Sound toggle should be visible")
        
        // Go back
        app.buttons["DoneButton"].tap()
    }
    
    // MARK: - Settings Tests
    
    func testSettingsOptions() throws {
        // Navigate to settings
        app.buttons["SettingsButton"].tap()

        // Test sound toggle
        let soundToggle = app.switches["SoundAlerts"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: 3), "Sound toggle should be visible")
        soundToggle.tap()

        // Test haptic toggle
        let hapticToggle = app.switches["HapticFeedback"]
        XCTAssertTrue(hapticToggle.exists, "Haptic toggle should be visible")
        hapticToggle.tap()

        // The Compact Mode toggle lives further down the settings list. List
        // rows are lazy, so the element doesn't exist until scrolled near —
        // swipe until it appears.
        let compactModeToggle = app.switches["CompactMode"]
        var swipes = 0
        while !compactModeToggle.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(compactModeToggle.exists, "Compact mode toggle should be visible")
        compactModeToggle.tap()
        // Restore the original value so the test doesn't leave compact mode on
        compactModeToggle.tap()

        // Go back
        app.buttons["DoneButton"].tap()
    }
    
    // MARK: - Premium Features Test
    
    func testPremiumUpgradeFlow() throws {
        // Navigate to settings
        app.buttons["SettingsButton"].tap()
        
        // Look for premium upgrade button
        let upgradeButton = app.buttons["UpgradeToPremium"]
        if upgradeButton.exists {
            upgradeButton.tap()
            
            // Close premium screen (assuming there's a close button)
            if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            }
        }
        
        // Go back
        app.buttons["DoneButton"].tap()
    }
    
    // MARK: - Timer Tests
    
    func testPreheatTimer() throws {
        // Relaunch in UI-test mode: the app auto-completes a started preheat
        // after ~0.4 s and shows the completion alert, instead of running the
        // real 10-minute countdown (which is why this test used to time out).
        app.launchArguments += ["-UITEST_MODE"]
        app.launch()

        // The preheat button is a fixed bottom bar — no scrolling needed.
        let preheatButton = app.buttons["PreheatButton"]
        XCTAssertTrue(preheatButton.waitForExistence(timeout: 5), "Preheat button should be visible")
        preheatButton.tap()

        // The UI-test-mode alert auto-dismisses after ~2 s, so poll rather
        // than sleep. Match on the alert's text — the container identifier
        // doesn't surface as a queryable element through the glass overlay.
        let alertText = app.staticTexts["Preheat Complete! 🔥"]
        XCTAssertTrue(alertText.waitForExistence(timeout: 5), "Preheat alert should appear")
    }
    
    // MARK: - Multiple Timers Test
    
    func testTimerDisplay() throws {
        // Look for a timer card by its stable accessibility identifier
        // ("Timer_<uuid>") — timer names are user-editable and the V2 cards
        // have no "Start" button, so the old name/label checks were brittle.
        let timerCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'Timer_'"))
            .firstMatch
        XCTAssertTrue(timerCard.waitForExistence(timeout: 5), "Timer elements should be visible")
        
        // Navigate to timer management
        app.buttons["SettingsButton"].tap()
        
        // Look for manage timers button
        let manageTimersButton = app.buttons["ManageTimers"]
        XCTAssertTrue(manageTimersButton.exists, "Manage Timers button should be visible")
        manageTimersButton.tap()
        
        // Try different ways to go back
        if app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
        } else if app.navigationBars.buttons["Settings"].exists {
            app.navigationBars.buttons["Settings"].tap()
        } else if app.buttons["DoneButton"].exists {
            app.buttons["DoneButton"].tap()
        }
        
        // Go back to main screen
        if app.buttons["DoneButton"].exists {
            app.buttons["DoneButton"].tap()
        }
    }
}
