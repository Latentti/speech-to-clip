//
//  VisualizerWindow.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 3.1: Create Floating Visualizer Window
//

import AppKit
import SwiftUI
import Combine

/// Floating borderless window that displays visual feedback during recording
///
/// VisualizerWindow creates a frameless, always-on-top window in the top-right
/// corner of the screen. It observes AppState.recordingState and automatically
/// shows/hides based on state transitions.
///
/// Key Features:
/// - Borderless (no title bar or controls) for clean visual appearance
/// - Always-on-top (.floating level) so it's visible over other windows
/// - Positioned in top-right corner with 20px margin
/// - Shows on all desktop spaces (.canJoinAllSpaces)
/// - Embeds SwiftUI VisualizerContentView using NSHostingController
///
/// Usage:
/// ```swift
/// let visualizer = VisualizerWindow(appState: appState)
/// // Window automatically shows/hides based on appState.recordingState
/// ```
@MainActor
class VisualizerWindow {
    // MARK: - Properties

    /// The actual NSWindow instance
    private let window: NSWindow

    /// Hosting controller for SwiftUI content
    private let hostingController: NSHostingController<VisualizerContentView>

    /// Wave renderer - initialized eagerly to ensure state synchronization
    private let waveRenderer: WaveRenderer

    /// Reference to app state for observing recording state
    /// Weak reference to avoid retain cycles
    private weak var appState: AppState?

    /// Combine cancellable for state observation
    private var cancellable: AnyCancellable?

    /// Track window visibility to avoid redundant show/hide calls
    private var isWindowVisible: Bool = false

    // MARK: - Constants

    private static let windowWidth: CGFloat = 50  // 50px width for wave visualizer
    private static let screenMargin: CGFloat = 0  // No margin - aligned to right edge

    // MARK: - Initialization

    /// Initialize the visualizer window
    ///
    /// - Parameter appState: The central app state to observe for recording state changes
    ///
    /// Creates a borderless, floating window positioned in the top-right corner.
    /// Sets up Combine subscription to show/hide window based on recording state.
    init(appState: AppState) {
        self.appState = appState

        // Initialize WaveRenderer eagerly to ensure it subscribes to state changes
        // before any state transitions occur
        self.waveRenderer = WaveRenderer(appState: appState)

        // Calculate window position - right edge, full screen height
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let x = screen.frame.maxX - Self.windowWidth - Self.screenMargin
        let y = screen.frame.minY  // Start at bottom of screen
        let windowHeight = screen.frame.height  // Full screen height
        let frame = NSRect(
            x: x,
            y: y,
            width: Self.windowWidth,
            height: windowHeight
        )

        // Create NSWindow with borderless style for frameless appearance
        self.window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure window properties for always-on-top floating window
        window.level = .floating  // Always on top of other windows
        window.collectionBehavior = .canJoinAllSpaces  // Show on all desktop spaces
        window.isOpaque = false  // Allow transparency
        window.backgroundColor = .clear  // Transparent background
        window.hasShadow = true  // Add shadow for depth

        // Create and embed SwiftUI content view with pre-initialized WaveRenderer
        self.hostingController = NSHostingController(
            rootView: VisualizerContentView(appState: appState, waveRenderer: waveRenderer)
        )
        window.contentViewController = hostingController

        // Subscribe to recording state changes
        setupStateObservation()

        print("✅ VisualizerWindow initialized - ready to show on recording")
    }

    // MARK: - State Observation

    /// Set up Combine subscription to observe AppState.recordingState
    ///
    /// Shows window when state becomes .recording
    /// Hides window when state transitions away from .recording
    private func setupStateObservation() {
        guard let appState = appState else {
            print("⚠️ VisualizerWindow: No appState available for observation")
            return
        }

        cancellable = appState.$recordingState
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleRecordingStateChange(state)
                }
            }
    }

    /// Handle recording state changes
    ///
    /// - Parameter state: The new recording state
    ///
    /// Story 3.7: Updated to show window during recording AND processing,
    /// hide only during idle (no idle visualization per AC4)
    private func handleRecordingStateChange(_ state: RecordingState) {
        switch state {
        case .recording, .processing:
            // Show window during recording and processing (skip if already visible)
            if !isWindowVisible {
                showWindow()
            }
        case .idle, .success, .error:
            // Hide window during idle, success, and error states (skip if already hidden)
            if isWindowVisible {
                hideWindow()
            }
        }
    }

    // MARK: - Window Management

    /// Show the visualizer window with fade in animation
    ///
    /// Story 3.7: Added smooth fade in animation (0.3s easeInOut)
    private func showWindow() {
        // Update position in case screen configuration changed
        updateWindowPosition()

        // Fade in animation
        window.alphaValue = 0.0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }

        isWindowVisible = true
        print("🎥 Visualizer window shown with fade in")
    }

    /// Hide the visualizer window with fade out animation
    ///
    /// Story 3.7: Added smooth fade out animation (0.3s easeInOut)
    private func hideWindow() {
        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            self.window.orderOut(nil)
            self.isWindowVisible = false
        })

        print("🚫 Visualizer window hidden with fade out")
    }

    /// Update window position to right edge, full screen height
    ///
    /// Story 3.7: Updated to use full screen height for wave visualizer
    /// Handles multi-monitor setups by using the main screen
    private func updateWindowPosition() {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let x = screen.frame.maxX - Self.windowWidth - Self.screenMargin
        let y = screen.frame.minY  // Start at bottom
        let windowHeight = screen.frame.height  // Full screen height
        let frame = NSRect(
            x: x,
            y: y,
            width: Self.windowWidth,
            height: windowHeight
        )
        window.setFrame(frame, display: false)
    }

    // MARK: - Cleanup

    deinit {
        cancellable?.cancel()
        window.close()
        print("♻️ VisualizerWindow deallocated")
    }
}
