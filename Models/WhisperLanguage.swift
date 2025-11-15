//
//  WhisperLanguage.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.2: Implement General Settings Tab
//

import Foundation

/// Enum representing all languages supported by OpenAI Whisper API
///
/// This enum provides language codes (ISO 639-1) and display names for all
/// languages supported by the Whisper API. Cases are sorted alphabetically
/// by display name for use in picker controls.
///
/// - Note: Language codes match OpenAI Whisper API expectations
/// - Note: Display names are in English for consistency
enum WhisperLanguage: String, CaseIterable, Identifiable, Codable {
    // MARK: - Cases (alphabetically sorted by display name)

    case afrikaans = "af"
    case arabic = "ar"
    case armenian = "hy"
    case azerbaijani = "az"
    case belarusian = "be"
    case bosnian = "bs"
    case bulgarian = "bg"
    case catalan = "ca"
    case chinese = "zh"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case estonian = "et"
    case finnish = "fi"
    case french = "fr"
    case galician = "gl"
    case german = "de"
    case greek = "el"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case icelandic = "is"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case kannada = "kn"
    case kazakh = "kk"
    case korean = "ko"
    case latvian = "lv"
    case lithuanian = "lt"
    case macedonian = "mk"
    case malay = "ms"
    case marathi = "mr"
    case maori = "mi"
    case nepali = "ne"
    case norwegian = "no"
    case persian = "fa"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case serbian = "sr"
    case slovak = "sk"
    case slovenian = "sl"
    case spanish = "es"
    case swahili = "sw"
    case swedish = "sv"
    case tagalog = "tl"
    case tamil = "ta"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case urdu = "ur"
    case vietnamese = "vi"
    case welsh = "cy"

    // MARK: - Identifiable

    /// Identifier for SwiftUI ForEach and Picker
    var id: String { rawValue }

    // MARK: - Display Names

    /// User-facing display name for the language
    ///
    /// Returns the English name of the language, suitable for display in UI controls.
    /// These names are sorted alphabetically to provide a consistent picker experience.
    var displayName: String {
        switch self {
        case .afrikaans: return "Afrikaans"
        case .arabic: return "Arabic"
        case .armenian: return "Armenian"
        case .azerbaijani: return "Azerbaijani"
        case .belarusian: return "Belarusian"
        case .bosnian: return "Bosnian"
        case .bulgarian: return "Bulgarian"
        case .catalan: return "Catalan"
        case .chinese: return "Chinese"
        case .croatian: return "Croatian"
        case .czech: return "Czech"
        case .danish: return "Danish"
        case .dutch: return "Dutch"
        case .english: return "English"
        case .estonian: return "Estonian"
        case .finnish: return "Finnish"
        case .french: return "French"
        case .galician: return "Galician"
        case .german: return "German"
        case .greek: return "Greek"
        case .hebrew: return "Hebrew"
        case .hindi: return "Hindi"
        case .hungarian: return "Hungarian"
        case .icelandic: return "Icelandic"
        case .indonesian: return "Indonesian"
        case .italian: return "Italian"
        case .japanese: return "Japanese"
        case .kannada: return "Kannada"
        case .kazakh: return "Kazakh"
        case .korean: return "Korean"
        case .latvian: return "Latvian"
        case .lithuanian: return "Lithuanian"
        case .macedonian: return "Macedonian"
        case .malay: return "Malay"
        case .marathi: return "Marathi"
        case .maori: return "Maori"
        case .nepali: return "Nepali"
        case .norwegian: return "Norwegian"
        case .persian: return "Persian"
        case .polish: return "Polish"
        case .portuguese: return "Portuguese"
        case .romanian: return "Romanian"
        case .russian: return "Russian"
        case .serbian: return "Serbian"
        case .slovak: return "Slovak"
        case .slovenian: return "Slovenian"
        case .spanish: return "Spanish"
        case .swahili: return "Swahili"
        case .swedish: return "Swedish"
        case .tagalog: return "Tagalog"
        case .tamil: return "Tamil"
        case .thai: return "Thai"
        case .turkish: return "Turkish"
        case .ukrainian: return "Ukrainian"
        case .urdu: return "Urdu"
        case .vietnamese: return "Vietnamese"
        case .welsh: return "Welsh"
        }
    }

    // MARK: - Sorted Collection

    /// Returns all languages sorted alphabetically by display name
    ///
    /// This provides a sorted array suitable for use in pickers and other UI controls
    /// where alphabetical ordering improves user experience.
    static var sortedByDisplayName: [WhisperLanguage] {
        return allCases.sorted { $0.displayName < $1.displayName }
    }
}
