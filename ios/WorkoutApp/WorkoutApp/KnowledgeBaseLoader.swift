import CryptoKit
import Foundation
import Markdown

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
        let strippedMarkdown = stripFrontMatter(from: markdown)
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

    private func stripFrontMatter(from markdown: String) -> String {
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

            if let list = child as? List {
                for listItem in list.children.compactMap({ $0 as? ListItem }) {
                    let text = listItem.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
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
