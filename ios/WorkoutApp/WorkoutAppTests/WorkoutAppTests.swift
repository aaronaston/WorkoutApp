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

    func testSearchIndexQuotedPhraseMatchesContiguousTokensOnly() {
        let match = makeWorkout(id: "match", title: "Push Up Basics")
        let split = makeWorkout(id: "split", title: "Push Day", summary: "Level up your strength")
        let index = WorkoutSearchIndex(workouts: [match, split], embedder: EmptyEmbedder())

        let results = index.search(query: "\"push up\"")

        XCTAssertEqual(results.map(\.id), ["match"])
    }

    func testSearchIndexQuotedPhraseIsCaseInsensitive() {
        let workout = makeWorkout(id: "match", title: "Push Up Basics")
        let index = WorkoutSearchIndex(workouts: [workout], embedder: EmptyEmbedder())

        let results = index.search(query: "\"PuSh Up\"")

        XCTAssertEqual(results.first?.id, workout.id)
    }

    func testSearchIndexQuotedPhraseAndTokensMustAllMatch() {
        let match = makeWorkout(id: "match", title: "Push Up Strength")
        let phraseOnly = makeWorkout(id: "phrase", title: "Push Up Basics")
        let index = WorkoutSearchIndex(workouts: [match, phraseOnly], embedder: EmptyEmbedder())

        let results = index.search(query: "\"push up\" strength")

        XCTAssertEqual(results.map(\.id), ["match"])
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

final class WorkoutRecommendationEngineTests: XCTestCase {
    private func makeWorkout(
        id: WorkoutID,
        title: String,
        durationMinutes: Int? = nil,
        focusTags: [String] = [],
        equipmentTags: [String] = [],
        locationTag: String? = nil,
        source: WorkoutSource = .knowledgeBase
    ) -> WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            source: source,
            sourceID: id,
            sourceURL: nil,
            title: title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: durationMinutes,
                focusTags: focusTags,
                equipmentTags: equipmentTags,
                locationTag: locationTag,
                otherTags: []
            ),
            content: WorkoutContent(sourceMarkdown: "", parsedSections: nil, notes: nil),
            timerConfiguration: nil,
            versionHash: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeSession(workoutID: WorkoutID, title: String, endedAt: Date) -> WorkoutSession {
        WorkoutSession(
            id: UUID(),
            workout: WorkoutReference(id: workoutID, source: .knowledgeBase, title: title, versionHash: nil),
            startedAt: endedAt.addingTimeInterval(-1_800),
            endedAt: endedAt,
            durationSeconds: 1_800,
            timerMode: .stopwatch,
            logEntries: [],
            notes: nil,
            perceivedExertion: nil
        )
    }

    func testRanksWorkoutsByFocusAndDurationPreferences() {
        let engine = WorkoutRecommendationEngine()
        let target = makeWorkout(
            id: "strength-short",
            title: "Strength Quick",
            durationMinutes: 18,
            focusTags: ["strength"]
        )
        let alternate = makeWorkout(
            id: "mobility-long",
            title: "Mobility Long",
            durationMinutes: 50,
            focusTags: ["mobility"]
        )
        let preferences = DiscoveryPreferences(
            targetDuration: .short,
            focusTags: ["strength"]
        )

        let ranked = engine.rank(
            workouts: [alternate, target],
            history: [],
            preferences: preferences,
            now: Date()
        )

        XCTAssertEqual(ranked.first?.workout.id, "strength-short")
        XCTAssertTrue(ranked.first?.reasons.contains(where: { $0.text == "Matches your focus preferences" }) ?? false)
    }

    func testRecentSessionAppliesRepeatPenalty() {
        let engine = WorkoutRecommendationEngine()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let recent = makeWorkout(id: "recent", title: "Strength A", focusTags: ["strength"])
        let fresh = makeWorkout(id: "fresh", title: "Strength B", focusTags: ["strength"])
        let session = makeSession(
            workoutID: "recent",
            title: "Strength A",
            endedAt: now.addingTimeInterval(-3_600)
        )

        let ranked = engine.rank(
            workouts: [recent, fresh],
            history: [session],
            preferences: DiscoveryPreferences(),
            now: now
        )

        XCTAssertEqual(ranked.first?.workout.id, "fresh")
    }

    func testMinimumRestDaysExcludesCategory() {
        let engine = WorkoutRecommendationEngine()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let strength = makeWorkout(id: "strength", title: "Strength A", focusTags: ["strength"])
        let mobility = makeWorkout(id: "mobility", title: "Mobility A", focusTags: ["mobility"])
        let session = makeSession(
            workoutID: "strength",
            title: "Strength A",
            endedAt: now.addingTimeInterval(-86_400)
        )
        let preferences = DiscoveryPreferences(
            minimumRestDaysByCategory: ["strength": 2]
        )

        let ranked = engine.rank(
            workouts: [strength, mobility],
            history: [session],
            preferences: preferences,
            now: now
        )

        XCTAssertEqual(ranked.map(\.workout.id), ["mobility"])
    }
}

final class WorkoutAppInfoPlistTests: XCTestCase {
    func testDeviceFamilyIncludesIphoneAndIpad() throws {
        let families = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [NSNumber]
        )
        let values = families.map { $0.intValue }

        XCTAssertTrue(values.contains(1))
        XCTAssertTrue(values.contains(2))
    }
}
