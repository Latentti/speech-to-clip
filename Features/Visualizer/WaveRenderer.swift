//
//  WaveRenderer.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 3.7: Replace Matrix Code Rain with Wave Visualizer
//

import SwiftUI
import Combine

/// ObservableObject that manages sine wave audio visualization
///
/// WaveRenderer creates a smooth, responsive audio visualizer with sine waves
/// that react to audio amplitude and app recording state. Significantly simpler
/// than MatrixRenderer - no complex stream management, just smooth wave calculations.
///
/// Key Responsibilities:
/// - Subscribe to AppState amplitude and recording state
/// - Smooth interpolation for amplitude and opacity (lerp factor: 0.1)
/// - Provide drawing methods for recording and processing states
/// - State-based color and animation selection
///
/// Usage:
/// ```swift
/// let renderer = WaveRenderer(appState: appState)
/// // In Canvas: renderer.drawWave(context: context, size: size)
/// ```
@MainActor
class WaveRenderer: ObservableObject {
    // MARK: - Published Properties

    /// Current audio amplitude (smooth interpolated)
    /// Range: 0.0 (silence) to 1.0 (maximum)
    @Published var amplitude: Double = 0.0

    /// Current recording state for state-based rendering
    @Published var currentRecordingState: RecordingState = .idle

    /// Current opacity (smooth interpolated)
    /// Controls visual visibility during state transitions
    @Published var opacity: Double = 0.0

    // MARK: - Properties

    /// Reference to app state for amplitude and recording state subscriptions
    /// Weak reference to prevent retain cycles
    private weak var appState: AppState?

    /// Combine cancellables for subscriptions
    private var amplitudeCancellable: AnyCancellable?
    private var recordingStateCancellable: AnyCancellable?

    // MARK: - Smooth Interpolation Properties

    /// Target amplitude from AppState (before smoothing)
    private var targetAmplitude: Double = 0.0

    /// Current amplitude (smoothed with lerp)
    private var currentAmplitude: Double = 0.0

    /// Target opacity based on recording state
    private var targetOpacity: Double = 0.0

    /// Current opacity (smoothed with lerp)
    private var currentOpacity: Double = 0.0

    /// Lerp factor for smooth interpolation (0.1 = web prototype)
    private let lerpFactor: Double = 0.1

    // MARK: - Wave Animation Properties

    /// Wave offset for recording state animation
    /// Increments each frame to create flowing wave motion
    private var waveOffset: CGFloat = 0.0

    /// Wave offset increment per frame (0.1 = web prototype)
    private let waveOffsetIncrement: CGFloat = 0.1

    /// Processing phase for processing state animation
    /// Slower increment for rhythmic pulse effect
    private var processingPhase: CGFloat = 0.0

    /// Processing phase increment per frame (0.05 = web prototype)
    private let processingPhaseIncrement: CGFloat = 0.05

    // MARK: - State-Based Constants

    /// Opacity for recording state (0.9 = mostly visible)
    private let recordingOpacity: Double = 0.9

    /// Opacity for processing state (0.8 = slightly dimmed)
    private let processingOpacity: Double = 0.8

    /// Opacity for idle state (0.0 = hidden)
    private let idleOpacity: Double = 0.0

    /// Opacity for proofreading state (0.85 = between recording and processing)
    /// Story 11.5-4: Added for AI proofreading visualization
    private let proofreadingOpacity: Double = 0.85

    /// Green color for recording state (#00FF41)
    private let recordingColor = Color(red: 0, green: 1, blue: 0.255)

    /// Yellow color for processing state (#FFFF00)
    private let processingColor = Color(red: 1, green: 1, blue: 0)

    /// Orange color for proofreading state (#FFA500)
    /// Story 11.5-4: Added for AI proofreading visualization
    private let proofreadingColor = Color(red: 1, green: 0.647, blue: 0)

    /// Minimum pixel amplitude (4px = web prototype)
    private let minPixelAmplitude: CGFloat = 4.0

    /// Maximum pixel amplitude (10px = web prototype)
    private let maxPixelAmplitude: CGFloat = 10.0

    /// Glow threshold amplitude (0.7 = high volume)
    private let glowThreshold: Double = 0.7

    // MARK: - Initialization

    /// Initialize the Wave renderer
    ///
    /// - Parameters:
    ///   - appState: The central app state to observe for amplitude and state changes
    ///
    /// Sets up Combine subscriptions to AppState.currentAmplitude and recordingState.
    init(appState: AppState) {
        self.appState = appState

        // Subscribe to amplitude and recording state changes
        setupAmplitudeObservation()
        setupRecordingStateObservation()

        print("✅ WaveRenderer initialized")
    }

    // MARK: - State Observation

    /// Set up Combine subscription to observe AppState.currentAmplitude
    private func setupAmplitudeObservation() {
        guard let appState = appState else {
            print("⚠️ WaveRenderer: No appState available for amplitude observation")
            return
        }

        amplitudeCancellable = appState.$currentAmplitude
            .sink { [weak self] newAmplitude in
                Task { @MainActor in
                    self?.targetAmplitude = newAmplitude
                }
            }
    }

    /// Set up Combine subscription to observe AppState.recordingState
    private func setupRecordingStateObservation() {
        guard let appState = appState else {
            print("⚠️ WaveRenderer: No appState available for recording state observation")
            return
        }

        recordingStateCancellable = appState.$recordingState
            .sink { [weak self] newState in
                Task { @MainActor in
                    self?.handleRecordingStateChange(newState)
                }
            }
    }

    /// Handle recording state changes with appropriate visual transitions
    ///
    /// - Parameter newState: The new recording state
    private func handleRecordingStateChange(_ newState: RecordingState) {
        // Skip if state hasn't changed (avoids duplicate logs on initialization)
        if case .idle = currentRecordingState, case .idle = newState {
            return  // Skip idle → idle transition
        }

        currentRecordingState = newState

        // Set target opacity based on state
        switch newState {
        case .recording:
            targetOpacity = recordingOpacity
        case .processing:
            targetOpacity = processingOpacity
        case .proofreading:
            targetOpacity = proofreadingOpacity
        case .idle, .error, .success:
            targetOpacity = idleOpacity
        }

        print("🎨 WaveRenderer: State changed to \(newState), target opacity: \(targetOpacity)")
    }

    // MARK: - Update (called every frame)

    /// Update animation state for one frame
    ///
    /// Called every frame (60fps) by TimelineView.
    /// Updates smooth interpolation and animation offsets.
    func update() {
        // Smooth interpolation for amplitude (lerp)
        currentAmplitude += (targetAmplitude - currentAmplitude) * lerpFactor

        // Smooth interpolation for opacity (lerp)
        currentOpacity += (targetOpacity - currentOpacity) * lerpFactor

        // Update published properties
        amplitude = currentAmplitude
        opacity = currentOpacity

        // Increment wave animations based on state
        switch currentRecordingState {
        case .recording:
            waveOffset += waveOffsetIncrement
        case .processing:
            processingPhase += processingPhaseIncrement
        case .proofreading:
            // Proofreading uses same animation phase as processing (pulse effect)
            processingPhase += processingPhaseIncrement
        case .idle, .error, .success:
            // No animation updates for idle/error/success
            break
        }
    }

    // MARK: - Drawing Methods

    /// Draw the wave visualization based on current state
    ///
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - size: Canvas size (50px width × screen height)
    func drawWave(context: inout GraphicsContext, size: CGSize) {
        // Skip drawing if opacity is near zero
        guard currentOpacity > 0.01 else { return }

        switch currentRecordingState {
        case .recording:
            drawRecordingWave(context: &context, size: size)
        case .processing:
            drawProcessingWave(context: &context, size: size)
        case .proofreading:
            drawProofreadingWave(context: &context, size: size)
        case .idle, .error, .success:
            // No visualization for these states
            break
        }
    }

    /// Draw recording state wave: green 3-frequency sine wave
    ///
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - size: Canvas size
    private func drawRecordingWave(context: inout GraphicsContext, size: CGSize) {
        let pixelAmplitude = calculatePixelAmplitude(from: currentAmplitude)

        var path = Path()
        var isFirst = true

        // Generate wave path by iterating over y coordinates
        for y in stride(from: 0, to: size.height, by: 2) {
            // Three overlapping sine waves for organic movement
            let wave1 = sin(y * 0.02 + waveOffset) * pixelAmplitude
            let wave2 = sin(y * 0.03 - waveOffset * 0.5) * pixelAmplitude * 0.5
            let wave3 = sin(y * 0.015 + waveOffset * 0.3) * pixelAmplitude * 0.3

            let x = size.width / 2 + wave1 + wave2 + wave3

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Apply glow effect for high amplitudes
        if currentAmplitude > glowThreshold {
            context.addFilter(.shadow(color: recordingColor, radius: 20))
        }

        // Draw the wave path
        context.stroke(
            path,
            with: .color(recordingColor.opacity(currentOpacity)),
            lineWidth: 3
        )
    }

    /// Draw processing state wave: yellow pulse wave with animated dots
    ///
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - size: Canvas size
    private func drawProcessingWave(context: inout GraphicsContext, size: CGSize) {
        let pixelAmplitude = calculatePixelAmplitude(from: currentAmplitude)

        // Rhythmic pulse: amplitude modulated by sine wave
        let pulseAmplitude = pixelAmplitude + sin(processingPhase) * 5

        var path = Path()
        var isFirst = true

        // Generate wave path
        for y in stride(from: 0, to: size.height, by: 2) {
            let wave = sin(y * 0.03 + processingPhase) * pulseAmplitude
            let x = size.width / 2 + wave

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Draw the wave path
        context.stroke(
            path,
            with: .color(processingColor.opacity(currentOpacity)),
            lineWidth: 3
        )

        // Draw 3 animated dots along the wave
        for i in 0..<3 {
            let baseY = (size.height / 4) * (CGFloat(i) + 0.5)
            let dotY = baseY + sin(processingPhase + CGFloat(i)) * 20

            let dotPath = Path(ellipseIn: CGRect(
                x: size.width / 2 - 2,
                y: dotY - 2,
                width: 4,
                height: 4
            ))

            context.fill(
                dotPath,
                with: .color(processingColor.opacity(currentOpacity))
            )
        }
    }

    /// Draw proofreading state wave: orange pulse wave with animated dots
    ///
    /// Story 11.5-4: Added for AI proofreading visualization.
    /// Follows the same pattern as `drawProcessingWave()` but uses orange color (#FFA500)
    /// to distinguish the proofreading phase from the processing phase.
    ///
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - size: Canvas size
    private func drawProofreadingWave(context: inout GraphicsContext, size: CGSize) {
        let pixelAmplitude = calculatePixelAmplitude(from: currentAmplitude)

        // Rhythmic pulse: amplitude modulated by sine wave (same as processing)
        let pulseAmplitude = pixelAmplitude + sin(processingPhase) * 5

        var path = Path()
        var isFirst = true

        // Generate wave path
        for y in stride(from: 0, to: size.height, by: 2) {
            let wave = sin(y * 0.03 + processingPhase) * pulseAmplitude
            let x = size.width / 2 + wave

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Draw the wave path with orange color
        context.stroke(
            path,
            with: .color(proofreadingColor.opacity(currentOpacity)),
            lineWidth: 3
        )

        // Draw 3 animated dots along the wave (same pattern as processing)
        for i in 0..<3 {
            let baseY = (size.height / 4) * (CGFloat(i) + 0.5)
            let dotY = baseY + sin(processingPhase + CGFloat(i)) * 20

            let dotPath = Path(ellipseIn: CGRect(
                x: size.width / 2 - 2,
                y: dotY - 2,
                width: 4,
                height: 4
            ))

            context.fill(
                dotPath,
                with: .color(proofreadingColor.opacity(currentOpacity))
            )
        }
    }

    // MARK: - Helper Methods

    /// Map normalized amplitude (0.0-1.0) to pixel amplitude (4-10px)
    ///
    /// - Parameter normalizedAmplitude: Amplitude from AppState (0.0-1.0)
    /// - Returns: Pixel amplitude for wave rendering
    private func calculatePixelAmplitude(from normalizedAmplitude: Double) -> CGFloat {
        return minPixelAmplitude + (maxPixelAmplitude - minPixelAmplitude) * CGFloat(normalizedAmplitude)
    }

    // MARK: - Cleanup

    deinit {
        amplitudeCancellable?.cancel()
        recordingStateCancellable?.cancel()
        print("♻️ WaveRenderer deallocated")
    }
}
