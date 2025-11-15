//
//  MenuBarController.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 1.3: Configure Menu Bar Application
//  Story 2.1: Implement Global Hotkey Registration
//  Story 7.4: Implement Profile Switching
//

import AppKit
import SwiftUI
import Combine

/// App delegate that manages the menu bar status item and menu for speech-to-clip
///
/// The MenuBarController creates and maintains the NSStatusItem that appears
/// in the macOS menu bar. It provides basic menu functionality including
/// a Quit option, and will be extended in future stories to show recording
/// status and provide settings access.
class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var hotkeyManager: HotkeyManager?

    // Story 6.2: Settings window management
    private var settingsWindow: NSWindow?
    private var settingsWindowCancellable: AnyCancellable?

    // Story 8.2: Onboarding window management
    private var onboardingWindow: NSWindow?
    private var onboardingWindowCancellable: AnyCancellable?

    // Story 8.4: Tutorial prompt window management
    private var tutorialWindow: NSWindow?
    private var tutorialWindowCancellable: AnyCancellable?

    // Story 7.4: Profile management
    private let profileManager = ProfileManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()
        setupSettingsWindowObserver()
        setupOnboardingWindowObserver()
        setupTutorialWindowObserver()
        setupProfileObservers()
    }

    /// Set up NotificationCenter observers for profile changes
    ///
    /// Listens for profile creation/update/deletion and rebuilds the menu
    /// to ensure the profile list and active profile indicator stay current.
    private func setupProfileObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfilesChanged),
            name: .profilesDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleActiveProfileChanged),
            name: .activeProfileDidChange,
            object: nil
        )
    }

    @objc private func handleProfilesChanged() {
        // Rebuild entire menu when profiles are created/updated/deleted
        setupMenuBar()
    }

    @objc private func handleActiveProfileChanged() {
        // Rebuild entire menu when active profile changes
        setupMenuBar()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupHotkey() {
        // Story 6.2: Use shared singleton AppState to ensure Settings window works
        // MenuBarController and SwiftUI App now share the same AppState instance
        print("🔧 Initializing HotkeyManager...")
        appState = AppState.shared
        hotkeyManager = HotkeyManager(appState: appState!)
    }

    // Story 6.2: Observe settingsWindowOpen changes and manage NSWindow
    private func setupSettingsWindowObserver() {
        guard let appState = appState else { return }

        settingsWindowCancellable = appState.$settingsWindowOpen
            .sink { [weak self] isOpen in
                if isOpen {
                    self?.showSettingsWindow()
                } else {
                    self?.closeSettingsWindow()
                }
            }
    }

    private func showSettingsWindow() {
        guard let appState = appState else { return }

        // If window already exists and is visible, bring to front
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        // Set SwiftUI content
        let settingsView = SettingsView()
            .environmentObject(appState)
            .frame(width: 600, height: 400)

        window.contentView = NSHostingView(rootView: settingsView)

        // Handle window close button
        window.delegate = self

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }

    // Story 8.2: Observe showOnboarding changes and manage NSWindow
    private func setupOnboardingWindowObserver() {
        guard let appState = appState else {
            print("⚠️ AppState not initialized yet for onboarding observer")
            return
        }

        print("✅ Setting up onboarding observer - current state: \(appState.showOnboarding)")

        onboardingWindowCancellable = appState.$showOnboarding
            .sink { [weak self] shouldShow in
                print("📢 Onboarding state changed: \(shouldShow)")
                if shouldShow {
                    self?.showOnboardingWindow()
                } else {
                    self?.closeOnboardingWindow()
                }
            }
    }

    private func showOnboardingWindow() {
        print("🎯 showOnboardingWindow() called")
        guard let appState = appState else {
            print("⚠️ AppState nil in showOnboardingWindow")
            return
        }

        // If window already exists and is visible, bring to front
        if let window = onboardingWindow, window.isVisible {
            print("ℹ️ Onboarding window already visible, bringing to front")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        print("✅ Creating new onboarding window")
        // Create coordinator for onboarding flow
        let coordinator = OnboardingCoordinator()

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Speech-to-Clip"
        window.center()
        window.isReleasedWhenClosed = false

        // Set SwiftUI content
        let onboardingView = OnboardingView(coordinator: coordinator)
            .environmentObject(appState)
            .frame(width: 500, height: 480)

        window.contentView = NSHostingView(rootView: onboardingView)

        // Handle window close button
        window.delegate = self

        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    // MARK: - Tutorial Prompt Window Management (Story 8.4)

    /// Set up observer for tutorial prompt window
    ///
    /// Story 8.4 AC 1: Shows tutorial prompt after onboarding when tutorialCompleted is false
    private func setupTutorialWindowObserver() {
        guard let appState = appState else {
            print("⚠️ AppState not initialized yet for tutorial observer")
            return
        }

        print("✅ Setting up tutorial observer - current state: \(appState.showTutorialPrompt)")

        tutorialWindowCancellable = appState.$showTutorialPrompt
            .sink { [weak self] shouldShow in
                print("📢 Tutorial prompt state changed: \(shouldShow)")
                if shouldShow {
                    self?.showTutorialWindow()
                } else {
                    self?.closeTutorialWindow()
                }
            }
    }

    private func showTutorialWindow() {
        print("🎯 showTutorialWindow() called")
        guard let appState = appState else {
            print("⚠️ AppState nil in showTutorialWindow")
            return
        }

        // If window already exists and is visible, bring to front
        if let window = tutorialWindow, window.isVisible {
            print("ℹ️ Tutorial window already visible, bringing to front")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        print("✅ Creating new tutorial window")

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Try it now!"
        window.center()
        window.isReleasedWhenClosed = false

        // Set SwiftUI content
        let tutorialView = TutorialPromptView(
            hotkey: appState.settings.hotkey,
            onDismiss: { [weak self] in
                // When user clicks "Let's try it!", close the tutorial window
                appState.showTutorialPrompt = false
                print("✅ Tutorial prompt dismissed by user")
            }
        )
        .frame(width: 500, height: 560)

        window.contentView = NSHostingView(rootView: tutorialView)

        // Handle window close button
        window.delegate = self

        self.tutorialWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeTutorialWindow() {
        tutorialWindow?.close()
        tutorialWindow = nil
    }

    private func setupMenuBar() {
        // Create status item with variable length (auto-sizing)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else {
            print("Failed to create status item")
            return
        }

        // Configure the status item button
        if let button = statusItem.button {
            // Use SF Symbol for microphone (placeholder icon)
            // In future stories, this will change based on recording state
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "speech-to-clip")
            button.image?.isTemplate = true // Allows menu bar to adjust color for dark/light mode
        }

        // Create and configure the menu
        let menu = NSMenu()

        // Add Settings menu item
        // Story 6.1: Settings window structure
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Add separator
        menu.addItem(NSMenuItem.separator())

        // Story 7.4: Add profile section
        buildProfileSection(menu: menu)

        // Add separator before Quit
        menu.addItem(NSMenuItem.separator())

        // Add Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit speech-to-clip",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Attach menu to status item
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        // Story 6.2: Open settings window via AppState
        appState?.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Profile Management (Story 7.4)

    /// Build and add the profile section to the menu
    ///
    /// Creates profile menu items showing:
    /// - Current active profile name (if exists)
    /// - "Switch Profile" submenu with all profiles
    /// - Checkmark next to active profile
    /// - "No Profiles - Open Settings" if no profiles configured
    private func buildProfileSection(menu: NSMenu) {
        do {
            // Get all profiles and active profile
            let profiles = try profileManager.getAllProfiles()
            let activeProfile = try profileManager.getActiveProfile()

            // Display current active profile name at top of menu (AC 1)
            if let active = activeProfile {
                let currentProfileItem = NSMenuItem(
                    title: "Profile: \(active.name)",
                    action: nil,
                    keyEquivalent: ""
                )
                currentProfileItem.isEnabled = false // Display only, not clickable
                menu.addItem(currentProfileItem)
            }

            // Create "Switch Profile" submenu (AC 2)
            let profileSubmenuItem = NSMenuItem(
                title: "Switch Profile",
                action: nil,
                keyEquivalent: ""
            )
            let profileSubmenu = NSMenu()

            if profiles.isEmpty {
                // No profiles - show helpful message (Edge case)
                let noProfilesItem = NSMenuItem(
                    title: "No Profiles - Open Settings",
                    action: #selector(openSettings),
                    keyEquivalent: ""
                )
                noProfilesItem.target = self
                profileSubmenu.addItem(noProfilesItem)
            } else {
                // Populate submenu with all profiles (AC 2)
                for profile in profiles {
                    let profileItem = NSMenuItem(
                        title: profile.name,
                        action: #selector(switchProfile(_:)),
                        keyEquivalent: ""
                    )
                    profileItem.target = self
                    profileItem.representedObject = profile.id

                    // Show checkmark next to currently active profile (AC 2)
                    if activeProfile?.id == profile.id {
                        profileItem.state = .on
                    }

                    profileSubmenu.addItem(profileItem)
                }
            }

            profileSubmenuItem.submenu = profileSubmenu
            menu.addItem(profileSubmenuItem)

        } catch {
            // Error loading profiles - show error message in menu
            print("⚠️ Failed to load profiles for menu: \(error.localizedDescription)")
            let errorItem = NSMenuItem(
                title: "Profiles unavailable",
                action: nil,
                keyEquivalent: ""
            )
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }
    }

    /// Handle profile switching from menu (AC 3)
    ///
    /// Switches the active profile when user selects from submenu.
    /// Updates AppState.currentProfile and rebuilds menu to update checkmark.
    /// Does NOT interrupt active recording - profile change takes effect for next recording.
    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let profileID = sender.representedObject as? UUID else {
            print("⚠️ Profile switch failed: missing profile ID")
            return
        }

        // Edge case: Check if recording is in progress
        // Profile switching is allowed, but won't interrupt the current recording
        if case .recording = appState?.recordingState {
            print("ℹ️ Recording in progress - profile switch will take effect after recording completes")
        }

        do {
            // Set active profile via ProfileManager
            try profileManager.setActiveProfile(id: profileID)

            // Update AppState.currentProfile (AC 3)
            if let updatedProfile = try profileManager.getActiveProfile() {
                appState?.currentProfile = updatedProfile
                print("✅ Switched to profile: \(updatedProfile.name)")
            }

            // Rebuild menu to update checkmark indicator
            setupMenuBar()

        } catch {
            // Show error notification
            print("❌ Profile switch failed: \(error.localizedDescription)")

            // TODO: Show user-facing error notification (Future enhancement)
            if let profileError = error as? ProfileError {
                print("   Error: \(profileError.errorDescription ?? "Unknown error")")
                print("   Suggestion: \(profileError.recoverySuggestion ?? "No suggestion")")
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension MenuBarController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check which window is being closed
        if sender == settingsWindow {
            appState?.closeSettings()
        } else if sender == onboardingWindow {
            // Story 8.2: Close onboarding window by setting showOnboarding to false
            appState?.showOnboarding = false
        }
        return true
    }
}
