# AI Proofreading - Epic & Story Breakdown

**Project:** speech-to-clip
**Feature:** AI-Powered Proofreading
**Author:** John (PM Agent)
**Date:** 2025-01-07
**Version:** 1.0

---

## Overview

This document defines the AI Proofreading feature that enhances transcribed text by correcting spelling, punctuation, and capitalization using GPT-4o-mini.

**Product Magic:** After speech-to-text transcription, AI automatically proofreads and corrects the text before pasting, reducing manual editing and improving output quality.

**Total Stories:** 6
**Sequence:** Stories are ordered with dependencies respected

---

## Epic 11.5: AI Proofreading

**Epic Goal:** Enable optional AI-powered proofreading that corrects spelling, punctuation, and capitalization in transcribed text using GPT-4o-mini.

**Value:** Users get cleaner, more professional text output without manual editing. Especially valuable for Finnish and other non-English languages where Whisper may introduce errors.

**Architecture Components:**
- AppSettings.swift (new settings)
- ProofreadingService.swift (new service)
- GeneralTab.swift (UI updates)
- RecordingState.swift (new state)
- AppState.swift (flow integration)
- MatrixRainView.swift (orange color state)

---

### Story 11.5-1: Add Proofreading Settings to AppSettings

**As a** developer,
**I want** to extend AppSettings with proofreading configuration,
**So that** users can enable/disable proofreading and select which profile's API key to use.

**Acceptance Criteria:**

**Given** the existing AppSettings struct
**When** I add proofreading fields
**Then** AppSettings includes:
- `enableProofreading: Bool` (default: false)
- `proofreadingProfileId: UUID?` (optional, for API key source)

**And** the fields are properly `Codable` for persistence
**And** existing settings migrate without data loss (backward compatible)
**And** settings are saved/loaded via SettingsService

**Prerequisites:** None (foundation story)

**Technical Notes:**
- Location: `Models/AppSettings.swift`
- Add to existing settings struct
- Default `enableProofreading = false` for non-breaking migration
- Reference: Translation setting pattern (enableTranslation)

---

### Story 11.5-2: Create ProofreadingService with GPT-4o-mini

**As a** developer,
**I want** a ProofreadingService that calls GPT-4o-mini to proofread text,
**So that** transcribed text can be corrected before output.

**Acceptance Criteria:**

**Given** I create a new ProofreadingService
**When** I call `proofread(text:language:apiKey:)`
**Then** it sends a request to OpenAI Chat Completions API with:
- Model: `gpt-4o-mini`
- System prompt: "You are a proofreader. Fix spelling, punctuation, and capitalization errors. Do not change sentence structure or meaning. Output only the corrected text with no explanations."
- User message: The transcribed text
- Language context in prompt: "The text is in {language}."

**And** it returns the corrected text string
**And** it handles API errors gracefully (timeout, invalid key, rate limit)
**And** it uses async/await pattern
**And** it logs requests for debugging

**Prerequisites:** Story 11.5-1

**Technical Notes:**
- Location: Create `Core/Proofreading/ProofreadingService.swift`
- Use URLSession for HTTP requests
- OpenAI Chat Completions endpoint: `https://api.openai.com/v1/chat/completions`
- Keep prompt simple and focused on proofreading only
- Reference: TranscriptionService pattern

---

### Story 11.5-3: Add Proofreading UI to Settings

**As a** user,
**I want** to enable proofreading in Settings with an option to select the API key source,
**So that** I can control when proofreading is applied and which API key is used.

**Acceptance Criteria:**

**Given** I update the GeneralTab in Settings
**When** I add the Proofreading section
**Then** the UI includes:
- Toggle: "Enable AI Proofreading"
- Description: "Fixes spelling, punctuation, and capitalization using AI."
- Picker: "OpenAI Profile" dropdown listing all OpenAI profiles
- Note: "Requires OpenAI API key" (shown when no OpenAI profiles exist)

**And** the toggle is bound to `appState.settings.enableProofreading`
**And** the profile picker shows only profiles with `transcriptionEngine == .openai`
**And** if current profile is OpenAI, it's pre-selected in picker
**And** if no OpenAI profiles exist, toggle is disabled with explanation
**And** changes auto-save via existing settings persistence

**Prerequisites:** Story 11.5-1

**Technical Notes:**
- Location: `Features/Settings/GeneralTab.swift`
- Add new Section below Translation section
- Filter profiles: `profiles.filter { $0.transcriptionEngine == .openai }`
- Reference: Translation toggle pattern in same file

---

### Story 11.5-4: Add Proofreading State to Visualizer

**As a** user,
**I want** to see an orange visualizer color during proofreading,
**So that** I know the app is processing my text with AI.

**Acceptance Criteria:**

**Given** the existing RecordingState enum and MatrixRainView
**When** I add a proofreading state
**Then** RecordingState includes a new case: `.proofreading`

**And** MatrixRainView displays orange color (#FFA500) for `.proofreading` state
**And** the visualizer smoothly transitions to orange after yellow (processing)
**And** the state follows the sequence: recording (green) → processing (yellow) → proofreading (orange) → success/error

**Prerequisites:** None (can be parallel)

**Technical Notes:**
- Location: `Models/RecordingState.swift` and `Features/Visualizer/MatrixRainView.swift`
- Add `.proofreading` case to RecordingState enum
- Add orange color constant and state handling in MatrixRainView
- Reference: Existing state color mappings

---

### Story 11.5-5: Wire Proofreading into Transcription Flow

**As a** developer,
**I want** to integrate proofreading into the transcription flow in AppState,
**So that** text is automatically proofread when the setting is enabled.

**Acceptance Criteria:**

**Given** proofreading is enabled in settings
**When** transcription completes successfully
**Then** AppState:
1. Sets state to `.proofreading`
2. Retrieves API key from selected proofreading profile
3. Calls ProofreadingService with text, language, and API key
4. On success: uses proofread text for clipboard/paste
5. On failure: falls back to original transcribed text with warning log

**And** if proofreading is disabled, the flow skips directly to clipboard/paste
**And** the proofread text is stored in `lastTranscribedText` (not original)
**And** language is taken from active profile's language setting

**Prerequisites:** Story 11.5-1, 11.5-2, 11.5-4

**Technical Notes:**
- Location: `App/AppState.swift` in `transcribeAudio()` method
- Insert proofreading step after transcription, before clipboard
- Graceful fallback: if proofreading fails, use original text
- Log both original and proofread text for debugging
- Reference: Translation flow pattern

---

### Story 11.5-6: Validate API Key Availability for Proofreading

**As a** user,
**I want** clear feedback when proofreading can't be used due to missing API key,
**So that** I understand why proofreading isn't working.

**Acceptance Criteria:**

**Given** proofreading is enabled but no valid OpenAI profile is selected
**When** the user tries to use proofreading
**Then** the app shows a user-friendly error:
- "Proofreading requires an OpenAI API key. Please select an OpenAI profile in Settings → Proofreading."

**And** if the selected profile's API key is invalid/empty, show appropriate error
**And** validation occurs at transcription time (not just in Settings)
**And** error is logged with details for debugging
**And** the flow falls back to non-proofread text (doesn't block transcription)

**Prerequisites:** Story 11.5-5

**Technical Notes:**
- Location: `App/AppState.swift` and error handling in ProofreadingService
- Check profile exists and has valid API key before calling service
- Use existing AlertHelper pattern for error display
- Reference: API key validation in transcription flow

---

## Epic Summary

### Story Count

| Story | Description | Complexity |
|-------|-------------|------------|
| 11.5-1 | Add proofreading settings | Low |
| 11.5-2 | Create ProofreadingService | Medium |
| 11.5-3 | Add proofreading UI | Low-Medium |
| 11.5-4 | Add visualizer state (orange) | Low |
| 11.5-5 | Wire into transcription flow | Medium |
| 11.5-6 | Validate API key availability | Low |
| **TOTAL** | **6 stories** | **Medium** |

### Dependency Flow

```
Story 11.5-1 (Settings Model)
  ↓
Story 11.5-2 (Service) ← Story 11.5-3 (UI)
  ↓
Story 11.5-4 (Visualizer State) - parallel
  ↓
Story 11.5-5 (Flow Integration)
  ↓
Story 11.5-6 (Validation)
```

**Critical Path:** 11.5-1 → 11.5-2 → 11.5-5 → 11.5-6
**Parallel Work:** 11.5-3 and 11.5-4 can be done in parallel after 11.5-1

---

## Technical Specifications

### ProofreadingService API

```swift
actor ProofreadingService {
    func proofread(
        text: String,
        language: String,
        apiKey: String
    ) async throws -> String
}
```

### GPT Prompt Template

```
System: You are a proofreader. Fix spelling, punctuation, and capitalization errors. Do not change sentence structure or meaning. Output only the corrected text with no explanations. The text is in {language}.

User: {transcribed_text}
```

### State Flow

```
User speaks
    ↓
Recording (green)
    ↓
Processing/Transcribing (yellow)
    ↓
[If proofreading enabled]
Proofreading (orange)
    ↓
Success → Clipboard/Paste
```

### Settings Structure

```swift
// In AppSettings.swift
var enableProofreading: Bool = false
var proofreadingProfileId: UUID? = nil
```

---

## Requirements Coverage

| Requirement | Stories |
|-------------|---------|
| Enable/disable proofreading toggle | 11.5-1, 11.5-3 |
| GPT-4o-mini integration | 11.5-2 |
| Profile-based API key selection | 11.5-1, 11.5-3, 11.5-5 |
| Visual feedback (orange state) | 11.5-4 |
| Language-aware proofreading | 11.5-2, 11.5-5 |
| Graceful error handling | 11.5-5, 11.5-6 |
| Local Whisper + OpenAI proofreading | 11.5-5, 11.5-6 |

**Coverage:** ✅ All specified requirements covered
