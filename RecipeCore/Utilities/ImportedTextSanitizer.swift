import Foundation

enum ImportedTextSanitizer {
    static func cleanInline(_ value: String) -> String {
        let repaired = repairMojibake(in: value)
        let decoded = decodeHTMLEntities(in: repaired)
        return decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanMultiline(_ value: String) -> String {
        let repaired = repairMojibake(in: value)
        let decoded = decodeHTMLEntities(in: repaired)
        let normalized = decoded
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    static func normalizedRecipeExtractionText(from value: String) -> String {
        let cleaned = cleanMultiline(value)
        guard !cleaned.isEmpty else { return "" }

        let normalizedSections = cleaned
            .replacingOccurrences(of: "�", with: "\n")
            .replacingOccurrences(of: #"(?i)\b(rezept|recipe)\b"#, with: "\n$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(zutaten|ingredients|instructions|directions|method|preparation|notes|tipps|tips|to assemble|zum zusammenbauen)\b\s*:?"#, with: "\n$0\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\S)\s+-(?=\d|[A-Za-zÄÖÜäöü])"#, with: "\n-", options: .regularExpression)
            .replacingOccurrences(of: #"([.!?])\s+(?=(Add|Mix|Chop|Serve|Assemble|Cook|Bake|Fry|Heat|Stir|Whisk|Combine|Fold|Alles|Mit|Dann|Zum|Vermischen|Braten|Backen|Servieren)\b)"#, with: "$1\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=[A-Za-zÄÖÜäöü0-9])\s+(?=(Add|Mix|Chop|Serve|Assemble|Cook|Bake|Fry|Heat|Stir|Whisk|Combine|Fold|Alles|Mit|Dann|Zum|Vermischen|Braten|Backen|Servieren)\b)"#, with: "\n", options: .regularExpression)

        return cleanMultiline(normalizedSections)
    }

    static func preferredRecipeDescription(baseDescription: String, rawText: String, aiSummary: String?) -> String {
        let normalizedSummary = cleanInline(aiSummary ?? "")
        if !normalizedSummary.isEmpty {
            return oneSentenceSummary(from: normalizedSummary, fallback: "")
        }

        return oneSentenceSummary(from: baseDescription, fallback: rawText)
    }

    static func oneSentenceSummary(from primary: String, fallback: String, maxLength: Int = 180) -> String {
        let primaryText = cleanInline(primary)
        if let sentence = firstSentence(in: primaryText, maxLength: maxLength) {
            return sentence
        }

        let fallbackText = cleanInline(fallback)
        return firstSentence(in: fallbackText, maxLength: maxLength) ?? fallbackText
    }

    static func decodeHTMLEntities(in value: String) -> String {
        var result = value

        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
            "&hellip;": "…",
            "&uuml;": "ü",
            "&Uuml;": "Ü",
            "&ouml;": "ö",
            "&Ouml;": "Ö",
            "&auml;": "ä",
            "&Auml;": "Ä",
            "&szlig;": "ß"
        ]

        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        result = replaceNumericEntities(in: result, pattern: #"&#x([0-9A-Fa-f]+);"#, radix: 16)
        result = replaceNumericEntities(in: result, pattern: #"&#([0-9]+);"#, radix: 10)
        return result
    }

    private static func replaceNumericEntities(in value: String, pattern: String, radix: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }

        var result = value
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let codeRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let codeString = String(result[codeRange])
            guard let scalarValue = UInt32(codeString, radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            result.replaceSubrange(fullRange, with: String(scalar))
        }

        return result
    }

    private static func firstSentence(in value: String, maxLength: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let range = trimmed.range(of: #"[.!?](\s|$)"#, options: .regularExpression) {
            let sentence = String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }

        if trimmed.count <= maxLength {
            return trimmed
        }

        let cutoff = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        let prefix = String(trimmed[..<cutoff])
        let shortened = prefix.split(separator: " ").dropLast().joined(separator: " ")
        return shortened.isEmpty ? prefix : shortened
    }

    private static func repairMojibake(in value: String) -> String {
        let originalScore = mojibakeScore(for: value)
        let encodings: [String.Encoding] = [.windowsCP1252, .isoLatin1]

        let candidates = encodings.compactMap { encoding -> String? in
            guard let data = value.data(using: encoding, allowLossyConversion: false),
                  let decoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            return decoded
        }

        guard let bestCandidate = candidates.min(by: { mojibakeScore(for: $0) < mojibakeScore(for: $1) }),
              mojibakeScore(for: bestCandidate) < originalScore else {
            return value
        }

        return bestCandidate
    }

    private static func mojibakeScore(for value: String) -> Int {
        let markers = ["Ã", "â", "�", "&#x", "&#"]
        return markers.reduce(0) { partialResult, marker in
            partialResult + max(0, value.components(separatedBy: marker).count - 1)
        }
    }
}
