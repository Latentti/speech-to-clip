//
//  AboutTab.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-17.
//  Story 9.1: Create About Tab in Settings
//

import SwiftUI
import AppKit

/// About tab displaying application information, license, and credits
///
/// This view provides:
/// - Application name and version
/// - MIT License information
/// - Author credits (Latentti Oy)
/// - GitHub repository link
///
/// Layout uses ScrollView for content that may exceed window height,
/// with centered VStack following the design system spacing (24px sections).
///
/// - Note: Story 9.1 - Transform Advanced tab to About tab
struct AboutTab: View {
    // MARK: - Properties

    /// Reference to app state (for consistency with other tabs)
    @EnvironmentObject var appState: AppState

    // MARK: - Computed Properties

    /// App version from Bundle, with fallback to "Development"
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development"
    }

    /// MIT License full text
    private let mitLicenseText = """
MIT License

Copyright (c) 2025 Latentti Oy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Name and Version
                VStack(spacing: 8) {
                    Text("speech-to-clip")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                Divider()

                // License Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("License")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("MIT License")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text(mitLicenseText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxWidth: 500)

                Divider()

                // Author Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Created by")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Latentti Oy")
                        .font(.body)
                }

                Divider()

                // GitHub Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open Source")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Link("View on GitHub", destination: URL(string: "https://github.com/Latentti/speech-to-clip")!)
                        .font(.body)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}

// MARK: - Preview

struct AboutTab_Previews: PreviewProvider {
    static var previews: some View {
        AboutTab()
            .environmentObject(AppState())
            .frame(width: 600, height: 400)
    }
}
