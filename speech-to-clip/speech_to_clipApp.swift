//
//  speech_to_clipApp.swift
//  speech-to-clip
//
//  Created by Ari Hietamäki on 12.11.2025.
//  Modified by BMad Dev Agent on 2025-11-12.
//  Story 1.3: Configure Menu Bar Application
//  Story 1.4: Implement Central AppState
//  Story 2.1: Implement Global Hotkey Registration
//  Story 6.1: Create Settings Window Structure
//

import SwiftUI

@main
struct speech_to_clipApp: App {
    // Use NSApplicationDelegateAdaptor to properly integrate AppKit delegate
    // This ensures MenuBarController is initialized and retained by the app lifecycle
    @NSApplicationDelegateAdaptor(MenuBarController.self) var menuBarController

    // Central application state - single source of truth for all app state
    // Story 6.2: Use shared singleton to ensure MenuBarController and SwiftUI share same instance
    // @StateObject ensures AppState is retained for the lifetime of the app
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Story 6.2: For menu bar apps (LSUIElement), window management is handled
        // entirely in MenuBarController via NSWindow. This Settings scene just
        // satisfies the App protocol requirement but doesn't show any windows.
        Settings {
            EmptyView()
        }
    }
}
