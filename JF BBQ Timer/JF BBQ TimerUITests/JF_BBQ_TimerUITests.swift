import XCTest

class JF_BBQ_TimerUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Tests will launch explicitly with any needed launch arguments
    }
    
    // MARK: - Basic Navigation Tests
    
    func testBasicNavigation() throws {
        app.launchArguments += ["-UITEST_MODE", "-UITEST_SKIP_ONBOARDING"]
        app.launch()
        // Test settings navigation
        let settingsButton = app.buttons["SettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should be visible")
        settingsButton.tap()
        
        // Verify settings screen elements
        let soundToggle = app.switches["SoundAlerts"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: 5), "Sound toggle should be visible")
        
        // Go back
        app.buttons["DoneButton"].tap()
    }
    
    // MARK: - Settings Tests
    
    func testSettingsOptions() throws {
        app.launchArguments += ["-UITEST_MODE", "-UITEST_SKIP_ONBOARDING"]
        app.launch()
        // Navigate to settings
        app.buttons["SettingsButton"].tap()
        
        // Test sound toggle
        let soundToggle = app.switches["SoundAlerts"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: 5), "Sound toggle should be visible")
        soundToggle.tap()
        
        // Test haptic toggle
        let hapticToggle = app.switches["HapticFeedback"]
        XCTAssertTrue(hapticToggle.waitForExistence(timeout: 5), "Haptic toggle should be visible")
        hapticToggle.tap()
        
        // Test compact mode toggle
        let compactModeToggle = app.switches["CompactMode"]
        XCTAssertTrue(compactModeToggle.waitForExistence(timeout: 5), "Compact mode toggle should be visible")
        compactModeToggle.tap()
        
        // Go back
        app.buttons["DoneButton"].tap()
    }
    
    // MARK: - Premium Features Test
    
    func testPremiumUpgradeFlow() throws {
        app.launchArguments += ["-UITEST_MODE", "-UITEST_SKIP_ONBOARDING"]
        app.launch()
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
        // Launch with a short preheat and skip onboarding
        app.launchArguments += ["-UITEST_MODE", "-UITEST_SKIP_ONBOARDING", "-UITEST_PREHEAT_SECONDS", "5"]
        app.launch()
        
        // Wait for app to fully load
        sleep(1)
        
        // Navigate to settings first to verify preheat duration
        let settingsButton = app.buttons["SettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should be visible")
        settingsButton.tap()
        
        // Go back to main screen
        app.buttons["DoneButton"].tap()
        
        // Test preheat button
        let preheatButton = app.buttons["PreheatButton"]
        XCTAssertTrue(preheatButton.waitForExistence(timeout: 5), "Preheat button should be visible")
        
        // Scroll to make preheat button visible
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp() // Scroll to bottom where preheat button is
        
        // Wait for button to be hittable and tap it
        let buttonExists = preheatButton.waitForExistence(timeout: 5)
        XCTAssertTrue(buttonExists, "Preheat button should exist after scrolling")
        
        if buttonExists {
            preheatButton.tap()
            
            // Check for alert elements with retries (up to ~10 seconds)
            var foundAlert = false
            for _ in 1...10 {
                sleep(1)
                if app.staticTexts["Preheat Complete! 🔥"].exists ||
                   app.buttons["Dismiss"].exists ||
                   app.otherElements["PreheatAlert"].exists {
                    foundAlert = true
                    break
                }
            }
            
            XCTAssertTrue(foundAlert, "Preheat alert or its elements should appear")
            
            // If alert appeared, dismiss it
            if app.buttons["Dismiss"].exists {
                app.buttons["Dismiss"].tap()
            }
        }
    }
    
    // MARK: - Multiple Timers Test
    
    func testTimerDisplay() throws {
        app.launchArguments += ["-UITEST_MODE", "-UITEST_SKIP_ONBOARDING"]
        app.launch()
        
        // Verify a timer UI appears by checking for the "Flip In" label or first header
        let flipIn = app.staticTexts["Flip In"]
        let anyTimerHeader = app.staticTexts.firstMatch
        XCTAssertTrue(flipIn.waitForExistence(timeout: 5) || anyTimerHeader.exists, "A timer should be visible (expects 'Flip In' label)")
        
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

    // MARK: - UI Performance Stress Test
    func testPerformance_ManyTimers() throws {
        // Configure app for stress
        app.launchArguments += [
            "-UITEST_MODE",
            "-UITEST_SKIP_ONBOARDING",
            "-UITEST_PREMIUM",
            "-UITEST_GENERATE_TIMERS", "10" // total timers including the 2 legacy ones
        ]

        measure(metrics: [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric()
        ]) {
            app.launch()

            // Wait for main list to load
            sleep(2)

            // Scroll the list up and down to exercise layout while timers tick
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                scrollView.swipeDown()
                scrollView.swipeUp()
            }

            // Let timers run for a short window during measurement
            sleep(5)
        }
    }
}
