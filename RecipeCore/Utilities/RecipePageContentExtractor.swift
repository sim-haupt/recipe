import Foundation

struct RecipePageContent {
    let pageTitle: String?
    let metaDescription: String?
    let openGraphTitle: String?
    let openGraphDescription: String?
    let twitterTitle: String?
    let twitterDescription: String?
    let canonicalURL: URL?
    let imageURL: URL?
    let bodyText: String?
}

enum RecipePageContentExtractor {
    static func extract(from html: String, baseURL: URL) -> RecipePageContent {
        let pageTitle = capture(in: html, pattern: "<title[^>]*>(.*?)</title>")
        let metaDescription = metaContent(in: html, key: "description")
        let openGraphTitle = metaContent(in: html, property: "og:title")
        let openGraphDescription = metaContent(in: html, property: "og:description")
        let twitterTitle = metaContent(in: html, key: "twitter:title")
        let twitterDescription = metaContent(in: html, key: "twitter:description")

        let canonicalValue = capture(in: html, pattern: "<link[^>]*rel=[\"']canonical[\"'][^>]*href=[\"'](.*?)[\"'][^>]*>")
        let canonicalURL = canonicalValue.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

        let imageValue = firstNonEmpty([
            jsonLDRecipe(in: html)?.imageURLString,
            metaContent(in: html, property: "og:image"),
            metaContent(in: html, key: "twitter:image")
        ])
        let imageURL = imageValue.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

        let recipeJSONLD = jsonLDRecipe(in: html)
        let bodyText = preferredBodyText(from: html, recipeJSONLD: recipeJSONLD)

        return RecipePageContent(
            pageTitle: pageTitle,
            metaDescription: firstNonEmpty([recipeJSONLD?.description, metaDescription]),
            openGraphTitle: firstNonEmpty([recipeJSONLD?.name, openGraphTitle]),
            openGraphDescription: firstNonEmpty([recipeJSONLD?.description, openGraphDescription]),
            twitterTitle: firstNonEmpty([recipeJSONLD?.name, twitterTitle]),
            twitterDescription: firstNonEmpty([recipeJSONLD?.description, twitterDescription]),
            canonicalURL: canonicalURL,
            imageURL: imageURL,
            bodyText: bodyText
        )
    }

    private static func preferredBodyText(from html: String, recipeJSONLD: JSONLDRecipe?) -> String {
        if let recipeJSONLD, recipeJSONLD.hasMeaningfulContent {
            return recipeJSONLD.composedText
        }

        let cleanedHTML = removeNonContentBlocks(from: html)
        let strippedText = stripHTML(cleanedHTML)
        let normalizedLines = strippedText
            .components(separatedBy: .newlines)
            .map { ImportedTextSanitizer.cleanInline($0) }
            .filter { isUsefulContentLine($0) }

        let focusedLines = focusedRecipeLines(from: normalizedLines)
        let selectedLines = focusedLines.isEmpty ? Array(normalizedLines.prefix(80)) : focusedLines
        return ImportedTextSanitizer.cleanMultiline(selectedLines.joined(separator: "\n"))
    }

    private static func focusedRecipeLines(from lines: [String]) -> [String] {
        let ingredientSection = sectionLines(
            from: lines,
            matchingHeaders: ["ingredients", "ingredient list", "what you need"],
            untilHeaders: ["instructions", "directions", "method", "preparation", "steps", "how to make", "notes", "tips"],
            preferQuantified: true
        )

        let preparationSection = sectionLines(
            from: lines,
            matchingHeaders: ["instructions", "directions", "method", "preparation", "steps", "how to make"],
            untilHeaders: ["notes", "tips", "nutrition", "related recipes"]
        )

        let notesSection = sectionLines(
            from: lines,
            matchingHeaders: ["notes", "tips"],
            untilHeaders: ["nutrition", "related recipes"]
        )

        var result: [String] = []
        let introLines = lines
            .filter { !$0.lowercased().contains("ingredients") && !$0.lowercased().contains("instructions") }
            .prefix(4)

        if !introLines.isEmpty {
            result.append(contentsOf: introLines)
        }
        if !ingredientSection.isEmpty {
            result.append("Ingredients:")
            result.append(contentsOf: ingredientSection)
        }
        if !preparationSection.isEmpty {
            result.append("Preparation:")
            result.append(contentsOf: preparationSection)
        }
        if !notesSection.isEmpty {
            result.append("Notes:")
            result.append(contentsOf: notesSection)
        }

        return deduplicated(result).prefix(90).map { $0 }
    }

    private static func sectionLines(from lines: [String], matchingHeaders headers: [String], untilHeaders endHeaders: [String], preferQuantified: Bool = false) -> [String] {
        let startIndexes = lines.indices.filter { index in
            let normalized = lines[index].lowercased()
            return headers.contains(where: { normalized == $0 || normalized.hasPrefix($0 + ":") })
        }

        guard !startIndexes.isEmpty else { return [] }

        let candidates = startIndexes.map { startIndex in
            sectionCandidate(from: lines, startIndex: startIndex, untilHeaders: endHeaders)
        }

        if preferQuantified {
            return candidates.max(by: { score(sectionCandidate: $0) < score(sectionCandidate: $1) }) ?? []
        }

        return candidates.first ?? []
    }

    private static func sectionCandidate(from lines: [String], startIndex: Int, untilHeaders endHeaders: [String]) -> [String] {
        let remaining = Array(lines.dropFirst(startIndex + 1))
        let endIndex = remaining.firstIndex(where: { line in
            let normalized = line.lowercased()
            return endHeaders.contains(where: { normalized == $0 || normalized.hasPrefix($0 + ":") })
        }) ?? remaining.endIndex

        return remaining[..<endIndex]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isUsefulContentLine($0) }
            .prefix(30)
            .map { $0 }
    }

    private static func score(sectionCandidate lines: [String]) -> Int {
        let amountCount = lines.filter(lineHasExplicitAmount).count
        let shortLineCount = lines.filter { $0.count <= 90 }.count
        let prosePenalty = lines.filter(looksLikeProseExplanation).count
        return (amountCount * 5) + shortLineCount - (prosePenalty * 3)
    }

    private static func lineHasExplicitAmount(_ line: String) -> Bool {
        let patterns = [
            #"^[-•]?\s*(\d+\/\d+|\d+(?:[.,]\d+)?|¼|½|¾|⅓|⅔|⅛|⅜|⅝|⅞)\b"#,
            #"\b(\d+\/\d+|\d+(?:[.,]\d+)?|¼|½|¾|⅓|⅔|⅛|⅜|⅝|⅞)\s*(g|kg|ml|l|tbsp|tsp|tablespoons?|teaspoons?|cups?|oz|lb|lbs|cans?|cloves?|pinch)\b"#,
            #"\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+(pound|cup|cups|tablespoons?|teaspoons?|cloves?|cans?)\b"#
        ]

        return patterns.contains { pattern in
            line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func looksLikeProseExplanation(_ line: String) -> Bool {
        line.contains(" – ")
            || line.contains(" - ")
            || line.contains(". ")
            || line.range(of: #"\b(they|it|this|these|that|feel free|for serving|for garnish)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isUsefulContentLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 260 else { return false }

        let lowercased = trimmed.lowercased()
        let excludedPhrases = [
            "cookie", "privacy", "terms", "sign up", "sign in", "log in", "newsletter",
            "advertisement", "sponsored", "related recipes", "jump to comments",
            "follow us", "follow me", "leave a comment", "all rights reserved",
            "skip to content", "rate this recipe", "pin this", "share this", "facebook", "instagram", "tiktok"
        ]

        if lowercased.contains("http") { return false }
        if excludedPhrases.contains(where: { lowercased.contains($0) }) { return false }
        return true
    }

    private static func removeNonContentBlocks(from html: String) -> String {
        html
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<noscript[\\s\\S]*?</noscript>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<svg[\\s\\S]*?</svg>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<(nav|footer|header|aside|form)[\\s\\S]*?</\\1>", with: " ", options: [.regularExpression, .caseInsensitive])
    }

    private static func stripHTML(_ html: String) -> String {
        let withLineBreaks = html
            .replacingOccurrences(of: "(?i)</(p|div|section|article|li|ul|ol|h1|h2|h3|h4|h5|h6|br|tr)>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        return ImportedTextSanitizer.decodeHTMLEntities(in: withLineBreaks)
    }

    private static func metaContent(in html: String, key: String? = nil, property: String? = nil) -> String? {
        if let property {
            return capture(in: html, pattern: "<meta[^>]*property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>")
        }

        if let key {
            return capture(in: html, pattern: "<meta[^>]*name=[\"']\(NSRegularExpression.escapedPattern(for: key))[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>")
        }

        return nil
    }

    private static func capture(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return ImportedTextSanitizer.cleanInline(String(html[captureRange]))
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }

    private static func jsonLDRecipe(in html: String) -> JSONLDRecipe? {
        let scripts = jsonLDScriptContents(in: html)
        for script in scripts {
            guard let data = cleanedJSONLDData(from: script),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }

            if let recipe = firstRecipe(in: object) {
                return recipe
            }
        }
        return nil
    }

    private static func jsonLDScriptContents(in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard let scriptRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[scriptRange])
        }
    }

    private static func cleanedJSONLDData(from script: String) -> Data? {
        let cleaned = script
            .replacingOccurrences(of: "<!--", with: "")
            .replacingOccurrences(of: "-->", with: "")
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.data(using: .utf8)
    }

    private static func firstRecipe(in object: Any) -> JSONLDRecipe? {
        if let array = object as? [Any] {
            for item in array {
                if let recipe = firstRecipe(in: item) {
                    return recipe
                }
            }
            return nil
        }

        guard let dictionary = object as? [String: Any] else {
            return nil
        }

        if isRecipe(dictionary) {
            return JSONLDRecipe(dictionary: dictionary)
        }

        if let graph = dictionary["@graph"] {
            return firstRecipe(in: graph)
        }

        for value in dictionary.values {
            if let recipe = firstRecipe(in: value) {
                return recipe
            }
        }

        return nil
    }

    private static func isRecipe(_ dictionary: [String: Any]) -> Bool {
        if let type = dictionary["@type"] as? String {
            return type.localizedCaseInsensitiveContains("Recipe")
        }
        if let types = dictionary["@type"] as? [String] {
            return types.contains(where: { $0.localizedCaseInsensitiveContains("Recipe") })
        }
        return false
    }
}

private struct JSONLDRecipe {
    let name: String?
    let description: String?
    let imageURLString: String?
    let ingredients: [String]
    let preparationSteps: [String]
    let notes: [String]

    init(dictionary: [String: Any]) {
        name = ImportedTextSanitizer.cleanInline((dictionary["name"] as? String) ?? "")
            .nilIfEmpty
        description = ImportedTextSanitizer.cleanInline((dictionary["description"] as? String) ?? "")
            .nilIfEmpty
        imageURLString = JSONLDRecipe.extractImageURL(from: dictionary["image"])
        ingredients = JSONLDRecipe.normalizeStringArray(dictionary["recipeIngredient"])
        preparationSteps = JSONLDRecipe.extractInstructions(from: dictionary["recipeInstructions"])
        notes = JSONLDRecipe.normalizeStringArray(dictionary["recipeTips"])
    }

    var hasMeaningfulContent: Bool {
        name != nil || description != nil || !ingredients.isEmpty || !preparationSteps.isEmpty || !notes.isEmpty
    }

    var composedText: String {
        var sections: [String] = []
        if let name, !name.isEmpty {
            sections.append(name)
        }
        if let description, !description.isEmpty {
            sections.append(description)
        }
        if !ingredients.isEmpty {
            sections.append("Ingredients:")
            sections.append(contentsOf: ingredients)
        }
        if !preparationSteps.isEmpty {
            sections.append("Preparation:")
            sections.append(contentsOf: preparationSteps)
        }
        if !notes.isEmpty {
            sections.append("Notes:")
            sections.append(contentsOf: notes)
        }
        return ImportedTextSanitizer.cleanMultiline(sections.joined(separator: "\n"))
    }

    private static func extractImageURL(from value: Any?) -> String? {
        if let string = value as? String {
            return ImportedTextSanitizer.cleanInline(string).nilIfEmpty
        }
        if let array = value as? [String] {
            return array.compactMap { ImportedTextSanitizer.cleanInline($0).nilIfEmpty }.first
        }
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries.compactMap { ($0["url"] as? String).flatMap { ImportedTextSanitizer.cleanInline($0).nilIfEmpty } }.first
        }
        if let dictionary = value as? [String: Any] {
            return (dictionary["url"] as? String).flatMap { ImportedTextSanitizer.cleanInline($0).nilIfEmpty }
        }
        return nil
    }

    private static func normalizeStringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
                .map { ImportedTextSanitizer.cleanInline($0) }
                .filter { !$0.isEmpty }
        }
        if let string = value as? String {
            let cleaned = ImportedTextSanitizer.cleanInline(string)
            return cleaned.isEmpty ? [] : [cleaned]
        }
        return []
    }

    private static func extractInstructions(from value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
                .map { ImportedTextSanitizer.cleanInline($0) }
                .filter { !$0.isEmpty }
        }

        if let string = value as? String {
            return ImportedTextSanitizer.cleanMultiline(string)
                .components(separatedBy: .newlines)
                .map { ImportedTextSanitizer.cleanInline($0) }
                .filter { !$0.isEmpty }
        }

        if let array = value as? [Any] {
            return array.flatMap { extractInstructions(from: $0) }
        }

        if let dictionary = value as? [String: Any] {
            if let text = dictionary["text"] as? String {
                let cleaned = ImportedTextSanitizer.cleanInline(text)
                return cleaned.isEmpty ? [] : [cleaned]
            }
            if let name = dictionary["name"] as? String {
                let cleaned = ImportedTextSanitizer.cleanInline(name)
                if !cleaned.isEmpty {
                    return [cleaned]
                }
            }
            if let itemListElement = dictionary["itemListElement"] {
                return extractInstructions(from: itemListElement)
            }
        }

        return []
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
