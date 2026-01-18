import XCTest
@testable import WorkoutApp

final class WorkoutMarkdownParserTests: XCTestCase {
    func testStripsFrontMatter() {
        let parser = WorkoutMarkdownParser()
        let markdown = """
        ---
        title: Sample
        ---
        # Sample Workout
        """

        let stripped = parser.strippedMarkdown(from: markdown)

        XCTAssertTrue(stripped.hasPrefix("# Sample Workout"))
    }

    func testParsesSectionsAndItems() {
        let parser = WorkoutMarkdownParser()
        let emDash = "\u{2014}"
        let markdown = """
        # Sample Workout
        ## Warmup
        Start easy.
        - Jumping jacks \(emDash) 30 seconds
        - Air squats
        """

        let workout = parser.parse(markdown: markdown, id: "sample-workout", sourceURL: nil, versionHash: "hash")

        XCTAssertEqual(workout.title, "Sample Workout")
        XCTAssertEqual(workout.content.parsedSections?.count, 1)
        XCTAssertEqual(workout.content.parsedSections?.first?.title, "Warmup")
        XCTAssertEqual(workout.content.parsedSections?.first?.items.count, 2)
        XCTAssertEqual(workout.content.parsedSections?.first?.items.first?.name, "Jumping jacks")
        XCTAssertEqual(workout.content.parsedSections?.first?.items.first?.prescription, "30 seconds")
    }
}

final class WorkoutSearchIndexTests: XCTestCase {
    private struct EmptyEmbedder: WorkoutEmbedder {
        func embed(_ text: String) -> [Double] {
            []
        }
    }

    private func makeWorkout(
        id: WorkoutID = "sample-workout",
        title: String = "Sample Workout",
        summary: String? = nil,
        sections: [WorkoutSection] = []
    ) -> WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            source: .knowledgeBase,
            sourceID: id,
            sourceURL: nil,
            title: title,
            summary: summary,
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: []
            ),
            content: WorkoutContent(
                sourceMarkdown: "",
                parsedSections: sections,
                notes: nil
            ),
            timerConfiguration: nil,
            versionHash: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func testSearchIndexExcludesSectionHeaders() {
        let section = WorkoutSection(
            title: "Warmup",
            detail: "Move through these drills.",
            items: [WorkoutItem(name: "Jumping jacks", prescription: "30 seconds")]
        )
        let workout = makeWorkout(title: "Leg Day", sections: [section])
        let index = WorkoutSearchIndex(workouts: [workout], embedder: EmptyEmbedder())

        let results = index.search(query: "Warmup")

        XCTAssertTrue(results.isEmpty)
    }

    func testSearchIndexStillMatchesSectionItems() {
        let section = WorkoutSection(
            title: "Warmup",
            detail: nil,
            items: [WorkoutItem(name: "Jumping jacks")]
        )
        let workout = makeWorkout(title: "Leg Day", sections: [section])
        let index = WorkoutSearchIndex(workouts: [workout], embedder: EmptyEmbedder())

        let results = index.search(query: "jumping")

        XCTAssertEqual(results.first?.id, workout.id)
    }

    func testSearchIndexSortsByWorkoutTitle() {
        let alpha = makeWorkout(id: "alpha", title: "Alpha", summary: "Strength focus")
        let bravo = makeWorkout(id: "bravo", title: "bravo", summary: "Strength focus")
        let charlie = makeWorkout(id: "charlie", title: "Charlie", summary: "Strength focus")
        let index = WorkoutSearchIndex(workouts: [charlie, bravo, alpha], embedder: EmptyEmbedder())

        let results = index.search(query: "strength")

        XCTAssertEqual(results.map(\.id), ["alpha", "bravo", "charlie"])
    }
}

final class WorkoutSearchTokenizerTests: XCTestCase {
    func testTokenizerKeepsFractionTokens() {
        let tokenizer = WorkoutSearchTokenizer()

        let tokens = tokenizer.tokens(from: "Run 1/2 mile")

        XCTAssertEqual(tokens, ["run", "1/2", "mile"])
    }

    func testTokenizerHandlesHyphenatedFractions() {
        let tokenizer = WorkoutSearchTokenizer()

        let tokens = tokenizer.tokens(from: "Intervals: 1/2-mile repeats")

        XCTAssertEqual(tokens, ["intervals", "1/2", "mile", "repeats"])
    }
}
