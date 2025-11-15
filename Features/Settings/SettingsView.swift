//
//  SettingsView.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.1: Create Settings Window Structure
//

import SwiftUI

/// Main settings window view with tabbed layout
///
/// This view provides the top-level structure for the settings window,
/// using SwiftUI's TabView for native macOS tab appearance. The window
/// is presented modally from the menu bar and managed by AppState.
///
/// **Window Specifications:**
/// - Size: ~600px wide, variable height
/// - Layout: TabView with placeholder tabs (General, Advanced)
/// - Keyboard shortcut: Cmd+, (standard macOS convention)
/// - Single instance: Only one settings window at a time
///
/// **Future Stories:**
/// - Story 6.2: Implement GeneralTab content
/// - Story 6.3: Implement hotkey capture control
/// - Story 6.4: Implement settings persistence
///
/// - Note: Story 6.1 - Settings window structure and lifecycle
struct SettingsView: View {
    // MARK: - Properties

    /// Reference to app state for window dismissal
    @EnvironmentObject var appState: AppState

    // MARK: - Body

    var body: some View {
        TabView {
            // General Tab - Story 6.2
            GeneralTab()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)

            // Profiles Tab - Story 7.3
            ProfilesTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Profiles", systemImage: "person.crop.circle")
                }
                .tag(1)

            // Advanced Tab (placeholder)
            AdvancedTabPlaceholder()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(2)
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}

// MARK: - Placeholder Tab Views

/// Placeholder view for General tab
///
/// This will be replaced with actual GeneralTab.swift in Story 6.2
private struct GeneralTabPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Language selection, hotkey customization, and launch preferences will be added in Story 6.2")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding()
    }
}

/// Placeholder view for Advanced tab
///
/// This provides space for future advanced settings
private struct AdvancedTabPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Advanced Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Advanced configuration options will be added in future stories")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
