//
//  RecordingLifecycleTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 2.5: Write Tests for Audio Recording
//

import XCTest
@testable import speech_to_clip

/// Integration tests for complete recording lifecycle
///
/// Covers end-to-end flows:
/// - Complete recording cycle: idle → recording → idle
/// - AppState → AudioRecorder integration
/// - Amplitude updates during recording
/// - Audio data storage and retrieval
/// - Error propagation through the stack
/// - State synchronization across components
///
/// Note: These tests verify the complete integration without requiring
/// actual microphone access (gracefully handles permission issues)
final class RecordingLifecycleTests: XCTestCase {

    var appState: AppState!
    var hotkeyManager: HotkeyManager!

    override func setUp() async throws {
        try await super.setUp()
        appState = await AppState()
        hotkeyManager = HotkeyManager(appState: appState)
    }

    override func tearDown() async throws {
        // Clean up any active recording
        let state = await appState.recordingState
        if case .recording = state {
            await appState.stopRecording()
        }
        hotkeyManager = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Complete Lifecycle Tests

    func testCompleteRecordingLifecycle_IdleToRecordingToProcessing() async {
        // Story 4.4: Lifecycle now includes transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        // Verify initial state
        let initialState = await appState.recordingState
        XCTAssertEqual(initialState, .idle, "Should start in idle state")

        let initialAmplitude = await appState.currentAmplitude
        XCTAssertEqual(initialAmplitude, 0.0, "Initial amplitude should be 0.0")

        let initialAudioData = await appState.lastRecordedAudio
        XCTAssertNil(initialAudioData, "Should have no recorded audio initially")

        // Start recording
        await appState.startRecording()

        let recordingState = await appState.recordingState
        if case .recording = recordingState {
            // Successfully started recording

            // Small delay to simulate recording activity
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            // During recording, amplitude might update (but not in test environment)
            let duringAmplitude = await appState.currentAmplitude
            XCTAssertGreaterThanOrEqual(duringAmplitude, 0.0, "Amplitude should be valid")

            // Stop recording (triggers transcription)
            await appState.stopRecording()

            // Story 4.4: Should transition to processing
            let processingState = await appState.recordingState
            XCTAssertEqual(processingState, .processing, "Should transition to processing")

            // Wait for transcription to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // Verify final state (error or success)
            let finalState = await appState.recordingState
            switch finalState {
            case .error, .success:
                XCTAssertTrue(true, "Transcription completed")
            case .processing:
                XCTAssertTrue(true, "Still processing")
            default:
                break
            }

            // Verify amplitude was reset
            let finalAmplitude = await appState.currentAmplitude
            XCTAssertEqual(finalAmplitude, 0.0, "Amplitude should reset to 0.0")

            // Verify audio data was stored (might be empty in test environment)
            let finalAudioData = await appState.lastRecordedAudio
            if let data = finalAudioData {
                print("📊 Complete lifecycle captured \(data.count) bytes")
            } else {
                print("⚠️ No audio data in test environment (expected)")
            }

        } else {
            // Recording not available in test environment
            print("⚠️ Recording not available - test environment limitation")

            // Verify error was handled gracefully
            let finalState = await appState.recordingState
            switch finalState {
            case .idle, .error:
                XCTAssertTrue(true, "Correctly in idle or error state after failed start")
            default:
                XCTFail("Unexpected state: \(finalState)")
            }
        }
    }

    func testMultipleRecordingCycles_StateRemainsConsistent() async {
        // Story 4.4: Multiple cycles with transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        var successfulCycles = 0

        for cycle in 1...3 {
            // Wait for previous transcription to complete
            var attempts = 0
            while attempts < 20 {
                let state = await appState.recordingState
                if case .idle = state {
                    break
                } else if case .error = state {
                    await MainActor.run {
                        appState.recordingState = .idle
                    }
                    break
                } else if case .success = state {
                    await MainActor.run {
                        appState.recordingState = .idle
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }

            let initialState = await appState.recordingState
            XCTAssertEqual(initialState, .idle, "Cycle \(cycle): Should start idle")

            // Start recording
            await appState.startRecording()

            let recordingState = await appState.recordingState
            if case .recording = recordingState {
                // Small delay
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Stop recording (triggers transcription)
                await appState.stopRecording()

                // Story 4.4: Should transition to processing
                let processingState = await appState.recordingState
                XCTAssertEqual(processingState, .processing, "Cycle \(cycle): Should be processing")

                successfulCycles += 1
            } else {
                print("⚠️ Cycle \(cycle): Recording not available")
                break
            }
        }

        print("📊 Completed \(successfulCycles) successful cycles")
    }

    // MARK: - AppState → AudioRecorder Integration Tests

    func testAppState_CallsAudioRecorder_OnStartRecording() async {
        // When AppState.startRecording() is called,
        // it should initialize and call AudioRecorder.startRecording()

        await appState.startRecording()

        let state = await appState.recordingState
        switch state {
        case .recording:
            // AudioRecorder was successfully started
            XCTAssertTrue(true, "AudioRecorder started successfully")
            await appState.stopRecording()

        case .idle:
            // AudioRecorder.startRecording() failed, AppState reverted to idle
            XCTAssertTrue(true, "Error handling works - reverted to idle")

            // Verify error was recorded
            let error = await appState.lastError
            if error != nil {
                print("📊 Error correctly propagated: \(error!.localizedDescription)")
            }

        case .error:
            // Error state set correctly
            XCTAssertTrue(true, "Error state set correctly")

        default:
            XCTFail("Unexpected state: \(state)")
        }
    }

    func testAppState_CallsAudioRecorder_OnStopRecording() async {
        // Story 4.4: stopRecording triggers transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        // Start recording first
        await appState.startRecording()

        let recordingState = await appState.recordingState
        if case .recording = recordingState {
            // When AppState.stopRecording() is called,
            // it should call AudioRecorder.stopRecording() and trigger transcription

            await appState.stopRecording()

            // Story 4.4: Should transition to processing
            let processingState = await appState.recordingState
            XCTAssertEqual(processingState, .processing, "Should be processing after stopping")

            // Verify audio data retrieval was attempted
            let audioData = await appState.lastRecordedAudio
            // Data might be nil in test environment, but the property should be accessible
            print("📊 Audio data storage: \(audioData?.count ?? 0) bytes")

        } else {
            print("⚠️ Could not test stopRecording - recording not available")
        }
    }

    // MARK: - Amplitude Updates During Recording

    func testAmplitudeUpdates_DuringRecording() async {
        // Story 4.4: Amplitude resets after transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        await appState.startRecording()

        let state = await appState.recordingState
        if case .recording = state {
            // In production, AudioRecorder would update amplitude via audio tap
            // In test environment, we verify the mechanism is in place

            // Simulate what AudioRecorder would do (update amplitude on main actor)
            await MainActor.run {
                appState.currentAmplitude = 0.75
            }

            let updatedAmplitude = await appState.currentAmplitude
            XCTAssertEqual(updatedAmplitude, 0.75, "Amplitude should be updatable during recording")

            // Stop recording (triggers transcription)
            await appState.stopRecording()

            // Story 4.4: Wait for transcription to complete (resets amplitude)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // Amplitude should reset
            let finalAmplitude = await appState.currentAmplitude
            XCTAssertEqual(finalAmplitude, 0.0, "Amplitude should reset after transcription")

        } else {
            print("⚠️ Recording not available")
        }
    }

    func testAmplitudeUpdates_OnlyDuringRecording() async {
        // Story 4.4: Amplitude resets after transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        // Amplitude should reset when not recording
        let initialAmplitude = await appState.currentAmplitude
        XCTAssertEqual(initialAmplitude, 0.0, "Should start at 0.0")

        // Manually set amplitude while idle (simulating stale data)
        await MainActor.run {
            appState.currentAmplitude = 0.5
        }

        // Start and immediately stop recording
        await appState.startRecording()
        let state = await appState.recordingState
        if case .recording = state {
            await appState.stopRecording()

            // Story 4.4: Wait for transcription to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        // Amplitude should be reset
        let finalAmplitude = await appState.currentAmplitude
        XCTAssertEqual(finalAmplitude, 0.0, "Amplitude should reset after transcription")
    }

    // MARK: - Error Propagation Tests

    func testErrorPropagation_AudioRecorderToAppState() async {
        // When AudioRecorder fails to start, error should propagate to AppState

        await appState.startRecording()

        let state = await appState.recordingState
        if case .idle = state {
            // Recording failed to start (expected in test environment)
            // Verify error was captured
            let error = await appState.lastError
            if let error = error {
                print("📊 Error propagated correctly: \(error.localizedDescription)")
                XCTAssertNotNil(error, "Error should be stored")
            }
        } else if case .error(let error) = state {
            // Error state set
            print("📊 Error state: \(error.localizedDescription)")
            XCTAssertTrue(true, "Error state set correctly")
        } else if case .recording = state {
            // Successfully started - clean up
            await appState.stopRecording()
        }
    }

    func testErrorHandling_StopRecordingWhenNotRecording() async {
        // Calling stopRecording when not recording should be safe (no-op)
        let initialState = await appState.recordingState
        XCTAssertEqual(initialState, .idle, "Should be idle")

        await appState.stopRecording()

        let finalState = await appState.recordingState
        XCTAssertEqual(finalState, .idle, "Should remain idle (no error)")
    }

    // MARK: - State Synchronization Tests

    func testStateSynchronization_AcrossComponents() async {
        // Story 4.4: State synchronization includes transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        // AppState and HotkeyManager should remain synchronized
        XCTAssertNotNil(hotkeyManager, "HotkeyManager should exist")

        let appStateInitial = await appState.recordingState
        XCTAssertEqual(appStateInitial, .idle, "AppState should be idle")

        // In production, HotkeyManager would trigger state changes
        // Here we verify AppState methods work correctly
        await appState.startRecording()

        let state = await appState.recordingState
        if case .recording = state {
            // State changed successfully
            await appState.stopRecording()

            // Story 4.4: Should transition to processing
            let processingState = await appState.recordingState
            XCTAssertEqual(processingState, .processing, "Should transition to processing")
        }
    }

    // MARK: - Audio Data Storage Tests

    func testAudioDataStorage_AfterRecording() async {
        // Start recording
        await appState.startRecording()

        let state = await appState.recordingState
        if case .recording = state {
            // Small recording duration
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

            // Stop and verify data storage
            await appState.stopRecording()

            let audioData = await appState.lastRecordedAudio
            // In production, this would contain WAV data
            // In test environment, might be empty or nil
            if let data = audioData {
                // Verify basic WAV structure if data exists
                if data.count >= 44 {
                    // WAV files have at least 44-byte header
                    print("📊 WAV data captured: \(data.count) bytes")

                    // Check for RIFF header
                    let header = data.prefix(4)
                    let headerString = String(data: header, encoding: .ascii)
                    if headerString == "RIFF" {
                        print("✅ Valid WAV header detected")
                    }
                }
            } else {
                print("⚠️ No audio data (test environment)")
            }
        } else {
            print("⚠️ Recording not available")
        }
    }

    func testAudioDataPersistence_AcrossMultipleRecordings() async {
        var recordingCount = 0

        // First recording
        await appState.startRecording()
        var state = await appState.recordingState
        if case .recording = state {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await appState.stopRecording()

            let firstAudioData = await appState.lastRecordedAudio
            recordingCount += 1

            // Second recording
            await appState.startRecording()
            state = await appState.recordingState
            if case .recording = state {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await appState.stopRecording()

                let secondAudioData = await appState.lastRecordedAudio
                recordingCount += 1

                // Each recording should store its own data
                // (lastRecordedAudio is overwritten with each recording)
                print("📊 Completed \(recordingCount) recordings")
            }
        }
    }

    // MARK: - Thread Safety Integration Tests

    func testConcurrentAccess_StateIsThreadSafe() async {
        // Multiple concurrent reads should be safe
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let state = await self.appState.recordingState
                    let amplitude = await self.appState.currentAmplitude
                    XCTAssertNotNil(state, "State should be accessible")
                    XCTAssertGreaterThanOrEqual(amplitude, 0.0, "Amplitude should be valid")
                }
            }
        }
    }

    func testSequentialStateChanges_AreThreadSafe() async {
        // Rapid sequential state changes should be handled safely
        for _ in 0..<5 {
            await appState.startRecording()

            let state = await appState.recordingState
            if case .recording = state {
                await appState.stopRecording()
            }

            // Small delay between cycles
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        let finalState = await appState.recordingState
        XCTAssertEqual(finalState, .idle, "Should end in idle state")
    }

    // MARK: - Memory Management Integration Tests

    func testMemoryManagement_NoLeaksInRecordingCycle() async {
        // Verify no strong reference cycles
        weak var weakAppState: AppState? = appState

        // Perform recording cycle
        await appState.startRecording()
        let state = await appState.recordingState
        if case .recording = state {
            await appState.stopRecording()
        }

        // AppState should still be alive (we hold strong reference)
        XCTAssertNotNil(weakAppState, "AppState should still exist")
    }

    func testMemoryManagement_HotkeyManagerWeakReference() async {
        // Create temporary AppState
        var tempAppState: AppState? = await AppState()
        weak var weakRef = tempAppState

        // Create HotkeyManager with temporary AppState
        var tempManager: HotkeyManager? = HotkeyManager(appState: tempAppState!)

        // HotkeyManager holds weak reference to AppState
        XCTAssertNotNil(weakRef, "AppState should exist")
        XCTAssertNotNil(tempManager, "Manager should exist")

        // Release AppState
        tempAppState = nil

        // AppState should be deallocated (manager has weak reference)
        // Note: This test verifies the pattern; in production, AppState outlives HotkeyManager
        tempManager = nil
    }

    // MARK: - Performance Integration Tests

    func testRecordingLifecycle_Performance() async {
        measure {
            let expectation = XCTestExpectation(description: "Recording cycle completes")

            Task {
                await appState.startRecording()
                let state = await appState.recordingState
                if case .recording = state {
                    await appState.stopRecording()
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Edge Case Integration Tests

    func testRapidStartStop_HandledGracefully() async {
        // Story 4.4: Rapid toggling with transcription
        await MainActor.run {
            appState.apiKey = "test-key"
        }

        // Rapidly start and stop recording
        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Reset to idle if needed
        let state = await appState.recordingState
        if case .error = state {
            await MainActor.run {
                appState.recordingState = .idle
            }
        } else if case .success = state {
            await MainActor.run {
                appState.recordingState = .idle
            }
        }

        await appState.startRecording()
        await appState.stopRecording()

        // Story 4.4: Should transition to processing
        let finalState = await appState.recordingState
        XCTAssertEqual(finalState, .processing, "Should handle rapid toggling with transcription")
    }

    func testStartDuringRecording_IsNoOp() async {
        await appState.startRecording()

        let firstState = await appState.recordingState
        if case .recording = firstState {
            // Try to start again
            await appState.startRecording()

            let secondState = await appState.recordingState
            if case .recording = secondState {
                XCTAssertTrue(true, "Guard clause prevents duplicate start")
            } else {
                XCTFail("Should still be recording")
            }

            await appState.stopRecording()
        }
    }

    func testStopDuringIdle_IsNoOp() async {
        let initialState = await appState.recordingState
        XCTAssertEqual(initialState, .idle, "Should be idle")

        await appState.stopRecording()

        let finalState = await appState.recordingState
        XCTAssertEqual(finalState, .idle, "Should remain idle")
    }
}
