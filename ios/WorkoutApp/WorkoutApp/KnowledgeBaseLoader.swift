import CryptoKit
import Foundation
import Markdown
import NaturalLanguage

struct KnowledgeBaseLoader {
    let bundle: Bundle
    let workoutsSubdirectory: String
    let parser: WorkoutMarkdownParser

    init(
        bundle: Bundle = .main,
        workoutsSubdirectory: String = "workouts",
        parser: WorkoutMarkdownParser = WorkoutMarkdownParser()
    ) {
        self.bundle = bundle
        self.workoutsSubdirectory = workoutsSubdirectory
        self.parser = parser
    }

    func loadWorkouts() throws -> [WorkoutDefinition] {
        guard let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: workoutsSubdirectory) else {
            return []
        }

        return try urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).map { url in
            let markdown = try String(contentsOf: url)
            let id = url.deletingPathExtension().lastPathComponent
            let versionHash = Self.hash(markdown)
            return parser.parse(markdown: markdown, id: id, sourceURL: url, versionHash: versionHash)
        }
    }

    private static func hash(_ markdown: String) -> String {
        let digest = SHA256.hash(data: Data(markdown.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct WorkoutMarkdownParser {
    func parse(markdown: String, id: WorkoutID, sourceURL: URL?, versionHash: String?) -> WorkoutDefinition {
        let strippedMarkdown = strippedMarkdown(from: markdown)
        let document = Document(parsing: strippedMarkdown)
        let title = extractTitle(from: document) ?? titleFromID(id)
        let sections = parseSections(from: document)

        return WorkoutDefinition(
            id: id,
            source: .knowledgeBase,
            sourceID: id,
            sourceURL: sourceURL,
            title: title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: []
            ),
            content: WorkoutContent(
                sourceMarkdown: markdown,
                parsedSections: sections,
                notes: nil
            ),
            timerConfiguration: nil,
            versionHash: versionHash,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func strippedMarkdown(from markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.first == "---" else {
            return markdown
        }

        guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            return markdown
        }

        let contentLines = lines[(endIndex + 1)...]
        return contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTitle(from document: Document) -> String? {
        for child in document.children {
            guard let heading = child as? Heading, heading.level == 1 else {
                continue
            }

            let title = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func parseSections(from document: Document) -> [WorkoutSection] {
        var sections: [WorkoutSection] = []
        var currentTitle: String?
        var currentDetail: String?
        var currentItems: [WorkoutItem] = []

        func listItemText(_ listItem: ListItem) -> String? {
            for child in listItem.children {
                if let paragraph = child as? Paragraph {
                    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : text
                }
            }
            return nil
        }

        func flushSection() {
            guard let title = currentTitle else {
                return
            }

            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else {
                return
            }

            let detail = currentDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let items = currentItems
            let section = WorkoutSection(title: trimmedTitle, detail: detail?.isEmpty == true ? nil : detail, items: items)
            sections.append(section)
        }

        for child in document.children {
            if let heading = child as? Heading, heading.level == 2 {
                flushSection()
                currentTitle = heading.plainText
                currentDetail = nil
                currentItems = []
                continue
            }

            guard currentTitle != nil else {
                continue
            }

            if let paragraph = child as? Paragraph, currentItems.isEmpty {
                let detail = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !detail.isEmpty {
                    currentDetail = detail
                }
                continue
            }

            if let list = child as? ListItemContainer {
                for listItem in list.listItems {
                    guard let text = listItemText(listItem) else {
                        continue
                    }

                    let item = parseItem(from: text)
                    currentItems.append(item)
                }
            }
        }

        flushSection()
        return sections
    }

    private func parseItem(from text: String) -> WorkoutItem {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let splitRange = trimmed.range(of: " — ") else {
            return WorkoutItem(name: trimmed, prescription: nil, notes: nil)
        }

        let name = String(trimmed[..<splitRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let prescription = String(trimmed[splitRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return WorkoutItem(
            name: name.isEmpty ? trimmed : name,
            prescription: prescription.isEmpty ? nil : prescription,
            notes: nil
        )
    }

    private func titleFromID(_ id: String) -> String {
        let base = id.components(separatedBy: "--").first ?? id
        return base
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WorkoutSearchResult: Identifiable {
    let id: WorkoutID
    let workout: WorkoutDefinition
    let score: Double
    let keywordScore: Double
    let semanticScore: Double
}

protocol WorkoutEmbedder {
    func embed(_ text: String) -> [Double]
}

struct WorkoutSearchIndex {
    struct Entry {
        let workout: WorkoutDefinition
        let keywords: Set<String>
        let embedding: [Double]
        let normalizedEmbedding: [Double]
    }

    private let entries: [Entry]
    private let embedder: WorkoutEmbedder
    private let tokenizer: WorkoutSearchTokenizer

    init(workouts: [WorkoutDefinition], embedder: WorkoutEmbedder = WorkoutSemanticEmbedder()) {
        let tokenizer = WorkoutSearchTokenizer()
        let parser = WorkoutMarkdownParser()
        let entries = workouts.map { workout in
            let keywordText = Self.keywordText(for: workout)
            let keywords = Set(tokenizer.tokens(from: keywordText))
            let semanticText = Self.semanticText(for: workout, parser: parser)
            let embedding = embedder.embed(semanticText)
            let normalizedEmbedding = Self.normalized(embedding)
            return Entry(
                workout: workout,
                keywords: keywords,
                embedding: embedding,
                normalizedEmbedding: normalizedEmbedding
            )
        }

        self.embedder = embedder
        self.tokenizer = tokenizer
        self.entries = entries
    }

    static func loadFromKnowledgeBase(
        loader: KnowledgeBaseLoader = KnowledgeBaseLoader(),
        embedder: WorkoutEmbedder = WorkoutSemanticEmbedder()
    ) throws -> WorkoutSearchIndex {
        let workouts = try loader.loadWorkouts()
        return WorkoutSearchIndex(workouts: workouts, embedder: embedder)
    }

    func search(query: String, limit: Int = 20) -> [WorkoutSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let queryTokens = tokenizer.tokens(from: trimmed)
        guard !queryTokens.isEmpty else {
            return []
        }
        let queryEmbedding = Self.normalized(embedder.embed(trimmed))
        let hasSemantic = !queryEmbedding.isEmpty

        let results = entries.compactMap { entry -> WorkoutSearchResult? in
            guard Self.matchesAllTokens(queryTokens, in: entry.keywords) else {
                return nil
            }
            let keywordScore = Self.keywordScore(
                queryTokens: queryTokens,
                keywords: entry.keywords,
                title: entry.workout.title
            )
            let semanticScore = hasSemantic ? Self.cosineSimilarity(queryEmbedding, entry.normalizedEmbedding) : 0
            let combinedScore = Self.combinedScore(keyword: keywordScore, semantic: semanticScore)
            guard combinedScore > 0 else {
                return nil
            }

            return WorkoutSearchResult(
                id: entry.workout.id,
                workout: entry.workout,
                score: combinedScore,
                keywordScore: keywordScore,
                semanticScore: semanticScore
            )
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    private static func keywordText(for workout: WorkoutDefinition) -> String {
        var components: [String] = [
            workout.title,
            workout.summary ?? "",
            workout.metadata.locationTag ?? ""
        ]

        components.append(contentsOf: workout.metadata.focusTags)
        components.append(contentsOf: workout.metadata.equipmentTags)
        components.append(contentsOf: workout.metadata.otherTags)

        if let sections = workout.content.parsedSections {
            for section in sections {
                components.append(section.title)
                if let detail = section.detail {
                    components.append(detail)
                }
                for item in section.items {
                    components.append(item.name)
                    if let prescription = item.prescription {
                        components.append(prescription)
                    }
                }
            }
        }

        return components
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func semanticText(for workout: WorkoutDefinition, parser: WorkoutMarkdownParser) -> String {
        let stripped = parser.strippedMarkdown(from: workout.content.sourceMarkdown)
        var components = [workout.title, workout.summary ?? "", stripped]
        if let sections = workout.content.parsedSections {
            components.append(contentsOf: sections.map { $0.title })
        }
        return components
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func keywordScore(queryTokens: [String], keywords: Set<String>, title: String) -> Double {
        guard !queryTokens.isEmpty else {
            return 0
        }

        let matchCount = queryTokens.filter { keywords.contains($0) }.count
        var score = Double(matchCount) / Double(queryTokens.count)

        let normalizedTitle = title.lowercased()
        let phrase = queryTokens.joined(separator: " ")
        if !phrase.isEmpty, normalizedTitle.contains(phrase) {
            score += 0.25
        }

        return min(score, 1.0)
    }

    private static func matchesAllTokens(_ queryTokens: [String], in keywords: Set<String>) -> Bool {
        guard !queryTokens.isEmpty else {
            return false
        }
        return queryTokens.allSatisfy { keywords.contains($0) }
    }

    private static func combinedScore(keyword: Double, semantic: Double) -> Double {
        let semanticClamped = max(semantic, 0)
        return (0.55 * keyword) + (0.45 * semanticClamped)
    }

    private static func normalized(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else {
            return []
        }
        let sum = vector.reduce(0) { $0 + ($1 * $1) }
        let magnitude = sqrt(sum)
        guard magnitude > 0 else {
            return []
        }
        return vector.map { $0 / magnitude }
    }

    private static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return 0
        }
        return zip(lhs, rhs).reduce(0) { $0 + ($1.0 * $1.1) }
    }
}

struct WorkoutSemanticEmbedder: WorkoutEmbedder {
    private let embedder: WorkoutEmbedder

    init() {
        let nl = NaturalLanguageEmbedder()
        if nl.isAvailable {
            self.embedder = nl
        } else {
            self.embedder = HashedEmbedder()
        }
    }

    func embed(_ text: String) -> [Double] {
        embedder.embed(text)
    }
}

struct NaturalLanguageEmbedder: WorkoutEmbedder {
    private let embedding: NLEmbedding?

    init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var isAvailable: Bool {
        embedding != nil
    }

    func embed(_ text: String) -> [Double] {
        guard let embedding, let vector = embedding.vector(for: text) else {
            return []
        }
        return Array(vector)
    }
}

struct HashedEmbedder: WorkoutEmbedder {
    private let dimensions: Int
    private let tokenizer: WorkoutSearchTokenizer

    init(dimensions: Int = 128) {
        self.dimensions = dimensions
        self.tokenizer = WorkoutSearchTokenizer()
    }

    func embed(_ text: String) -> [Double] {
        let tokens = tokenizer.tokens(from: text)
        guard !tokens.isEmpty else {
            return []
        }

        var vector = Array(repeating: 0.0, count: dimensions)
        for token in tokens {
            let hash = fnv1a64(token)
            let index = Int(hash % UInt64(dimensions))
            vector[index] += 1.0
        }

        let sum = vector.reduce(0) { $0 + ($1 * $1) }
        let magnitude = sqrt(sum)
        guard magnitude > 0 else {
            return []
        }
        return vector.map { $0 / magnitude }
    }

    private func fnv1a64(_ text: String) -> UInt64 {
        let bytes = Array(text.utf8)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

struct WorkoutSearchTokenizer {
    func tokens(from text: String) -> [String] {
        let normalized = text.lowercased()
        let pattern = "[a-z0-9]+(?:/[a-z0-9]+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        var tokens: [String] = []
        regex.enumerateMatches(in: normalized, options: [], range: range) { match, _, _ in
            guard let match, let matchRange = Range(match.range, in: normalized) else {
                return
            }
            let token = String(normalized[matchRange])
            if token.count > 1 {
                tokens.append(token)
            }
        }
        return tokens
    }
}
