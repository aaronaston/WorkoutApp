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

final class HistorySessionDiscoveryTests: XCTestCase {
    private func makeWorkout(
        id: WorkoutID,
        title: String,
        summary: String? = nil
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

    func testSortChronologicalOrdersByMostRecentSessionDate() {
        let older = makeSession(
            workoutID: "w1",
            title: "Workout A",
            endedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = makeSession(
            workoutID: "w2",
            title: "Workout B",
            endedAt: Date(timeIntervalSince1970: 2_000)
        )

        let sorted = HistorySessionDiscovery.sortSessions(
            [older, newer],
            allSessions: [older, newer],
            option: .chronological
        )

        XCTAssertEqual(sorted.map(\.workout.id), ["w2", "w1"])
    }

    func testSortMostFrequentPromotesMostRepeatedWorkout() {
        let a1 = makeSession(workoutID: "a", title: "Workout A", endedAt: Date(timeIntervalSince1970: 3_000))
        let a2 = makeSession(workoutID: "a", title: "Workout A", endedAt: Date(timeIntervalSince1970: 2_000))
        let b1 = makeSession(workoutID: "b", title: "Workout B", endedAt: Date(timeIntervalSince1970: 4_000))

        let sorted = HistorySessionDiscovery.sortSessions(
            [a1, b1, a2],
            allSessions: [a1, a2, b1],
            option: .mostFrequent
        )

        XCTAssertEqual(sorted.prefix(2).map(\.workout.id), ["a", "a"])
    }

    func testFilterSessionsMatchesKeywordsFromResolvedWorkoutSummary() {
        let session = makeSession(
            workoutID: "w1",
            title: "Morning Session",
            endedAt: Date(timeIntervalSince1970: 2_000)
        )
        let workout = makeWorkout(
            id: "w1",
            title: "Morning Session",
            summary: "Shoulders and upper body"
        )

        let filtered = HistorySessionDiscovery.filterSessions(
            [session],
            query: "shoulders",
            resolvedWorkouts: ["w1": workout]
        )

        XCTAssertEqual(filtered.map(\.id), [session.id])
    }

    func testFilterSessionsIncludesSemanticMatchesWithoutKeywordHit() {
        let session = makeSession(
            workoutID: "w1",
            title: "Morning Session",
            endedAt: Date(timeIntervalSince1970: 2_000)
        )

        let filtered = HistorySessionDiscovery.filterSessions(
            [session],
            query: "pull day",
            resolvedWorkouts: [:],
            semanticMatches: ["w1"]
        )

        XCTAssertEqual(filtered.map(\.id), [session.id])
    }
}

final class HistorySessionResolutionTests: XCTestCase {
    private func makeWorkout(
        id: WorkoutID,
        source: WorkoutSource,
        title: String,
        sections: [WorkoutSection]?,
        sourceMarkdown: String = ""
    ) -> WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            source: source,
            sourceID: id,
            sourceURL: nil,
            title: title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: []
            ),
            content: WorkoutContent(sourceMarkdown: sourceMarkdown, parsedSections: sections, notes: nil),
            timerConfiguration: nil,
            versionHash: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeSession(workout: WorkoutDefinition) -> WorkoutSession {
        WorkoutSession(
            id: UUID(),
            workout: WorkoutReference(
                id: workout.id,
                source: workout.source,
                title: workout.title,
                versionHash: workout.versionHash
            ),
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_600),
            durationSeconds: 600,
            timerMode: .stopwatch,
            logEntries: [],
            notes: nil,
            perceivedExertion: nil,
            workoutArtifactID: "artifact-\(workout.id)",
            workoutSnapshot: workout
        )
    }

    func testGeneratedSessionUsesSnapshotWhenLookupMisses() {
        let snapshot = makeWorkout(
            id: "generated-1",
            source: .generated,
            title: "Generated Workout",
            sections: [WorkoutSection(title: "Main", items: [WorkoutItem(name: "Burpees")])]
        )
        let session = makeSession(workout: snapshot)

        let resolved = resolvedHistoryWorkout(for: session, workoutLookup: [:])

        XCTAssertEqual(resolved.id, snapshot.id)
        XCTAssertEqual(resolved.content.parsedSections?.first?.title, "Main")
        XCTAssertEqual(resolved.content.parsedSections?.first?.items.first?.name, "Burpees")
    }

    func testKnowledgeBaseSessionPrefersLookupWhenAvailable() {
        let snapshot = makeWorkout(
            id: "kb-1",
            source: .knowledgeBase,
            title: "Snapshot Title",
            sections: nil
        )
        let session = makeSession(workout: snapshot)
        let lookupWorkout = makeWorkout(
            id: "kb-1",
            source: .knowledgeBase,
            title: "Lookup Title",
            sections: [WorkoutSection(title: "Warmup", items: [WorkoutItem(name: "Air Squats")])]
        )

        let resolved = resolvedHistoryWorkout(for: session, workoutLookup: ["kb-1": lookupWorkout])

        XCTAssertEqual(resolved.title, "Lookup Title")
        XCTAssertEqual(resolved.content.parsedSections?.first?.title, "Warmup")
    }

    func testGeneratedSessionFallsBackToArtifactWhenSnapshotSectionsMissing() {
        let snapshot = makeWorkout(
            id: "generated-2",
            source: .generated,
            title: "Generated Snapshot",
            sections: nil
        )
        var session = makeSession(workout: snapshot)
        session.workoutArtifactID = "artifact-generated-2"

        let artifactWorkout = makeWorkout(
            id: "generated-2",
            source: .generated,
            title: "Generated From Artifact",
            sections: [WorkoutSection(title: "Main", items: [WorkoutItem(name: "Thrusters")])]
        )

        let resolved = resolvedHistoryWorkout(
            for: session,
            workoutLookup: [:],
            artifactLookup: ["artifact-generated-2": artifactWorkout]
        )

        XCTAssertEqual(resolved.title, "Generated From Artifact")
        XCTAssertEqual(resolved.content.parsedSections?.first?.title, "Main")
        XCTAssertEqual(resolved.content.parsedSections?.first?.items.first?.name, "Thrusters")
    }

    func testSnapshotFallsBackToMarkdownParsingWhenSectionsMissing() {
        let markdown = """
        # Generated Plan

        ## Main
        - Burpees — 3 x 10
        """
        let snapshot = makeWorkout(
            id: "generated-3",
            source: .generated,
            title: "Generated Plan",
            sections: nil,
            sourceMarkdown: markdown
        )
        let session = makeSession(workout: snapshot)

        let resolved = resolvedHistoryWorkout(for: session, workoutLookup: [:])

        XCTAssertEqual(resolved.content.parsedSections?.first?.title, "Main")
        XCTAssertEqual(resolved.content.parsedSections?.first?.items.first?.name, "Burpees")
        XCTAssertEqual(resolved.content.parsedSections?.first?.items.first?.prescription, "3 x 10")
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

    func testSceneManifestIsNotOverridden() {
        let sceneManifest = Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest")

        XCTAssertNil(sceneManifest)
    }

    func testLaunchScreenIsConfigured() {
        let launchScreen = Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any]

        XCTAssertNotNil(launchScreen)
    }
}

final class SessionStateStoreTests: XCTestCase {
    private func makeWorkout(id: WorkoutID = "test-workout", title: String = "Test Workout") -> WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            source: .knowledgeBase,
            sourceID: id,
            sourceURL: nil,
            title: title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: []
            ),
            content: WorkoutContent(sourceMarkdown: "", parsedSections: nil, notes: nil),
            timerConfiguration: nil,
            versionHash: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    @MainActor
    private func makeStores() -> (WorkoutSessionStore, WorkoutArtifactStore, SessionDraftStore, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutAppTests-\(UUID().uuidString)", isDirectory: true)
        let sessionsURL = baseURL.appendingPathComponent("sessions.json")
        let artifactsURL = baseURL.appendingPathComponent("artifacts.json")
        let draftURL = baseURL.appendingPathComponent("draft.json")
        let sessionStore = WorkoutSessionStore(fileURL: sessionsURL)
        let artifactStore = WorkoutArtifactStore(fileURL: artifactsURL)
        let draftStore = SessionDraftStore(fileURL: draftURL)
        return (sessionStore, artifactStore, draftStore, baseURL)
    }

    @MainActor
    func testCancelSessionDoesNotWriteHistory() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        state.startSession(workout: makeWorkout(), at: Date(timeIntervalSince1970: 100))
        state.cancelSession()

        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.activeSession)
        XCTAssertTrue(sessionStore.sessions.isEmpty)
    }

    @MainActor
    func testPauseResumeExcludesPausedTimeFromCompletedDuration() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let start = Date(timeIntervalSince1970: 0)
        state.startSession(workout: makeWorkout(), at: start)
        state.pauseSession(at: start.addingTimeInterval(120))
        state.resumeSession(at: start.addingTimeInterval(300))
        state.endSession(at: start.addingTimeInterval(600))

        XCTAssertEqual(sessionStore.sessions.first?.durationSeconds, 420)
    }

    @MainActor
    func testEndingWhilePausedCountsOnlyActiveTime() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let start = Date(timeIntervalSince1970: 0)
        state.startSession(workout: makeWorkout(), at: start)
        state.pauseSession(at: start.addingTimeInterval(60))
        state.endSession(at: start.addingTimeInterval(120))

        XCTAssertEqual(sessionStore.sessions.first?.durationSeconds, 60)
    }

    @MainActor
    func testElapsedTimeRemainsFixedWhilePaused() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let start = Date(timeIntervalSince1970: 0)
        state.startSession(workout: makeWorkout(), at: start)
        state.pauseSession(at: start.addingTimeInterval(100))

        let elapsed = state.currentElapsedSeconds(at: start.addingTimeInterval(200))
        XCTAssertEqual(elapsed, 100)
    }

    @MainActor
    func testStartSessionWithInitialElapsedSeconds() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let now = Date(timeIntervalSince1970: 1_000)
        state.startSession(workout: makeWorkout(), at: now, initialElapsedSeconds: 180)

        let elapsed = state.currentElapsedSeconds(at: now)
        XCTAssertEqual(elapsed, 180)
    }

    @MainActor
    func testResumeSessionUpdatesExistingHistoryEntry() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let start = Date(timeIntervalSince1970: 0)
        let firstEnd = Date(timeIntervalSince1970: 29)

        state.startSession(workout: makeWorkout(), at: start)
        state.endSession(at: firstEnd)

        let original = try XCTUnwrap(sessionStore.sessions.first)
        XCTAssertEqual(original.durationSeconds, 29)

        let resumeStart = Date(timeIntervalSince1970: 36)
        let finalEnd = Date(timeIntervalSince1970: 43)
        state.startSession(
            workout: makeWorkout(),
            at: resumeStart,
            initialElapsedSeconds: 29,
            sessionID: original.id
        )
        state.endSession(at: finalEnd)

        XCTAssertEqual(sessionStore.sessions.count, 1)
        XCTAssertEqual(sessionStore.sessions.first?.id, original.id)
        XCTAssertEqual(sessionStore.sessions.first?.durationSeconds, 36)
    }

    @MainActor
    func testCompletedSessionStoresArtifactReferenceAndSnapshot() throws {
        let (sessionStore, artifactStore, draftStore, baseURL) = makeStores()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let workout = makeWorkout(id: "snapshot-test", title: "Snapshot Test")
        let state = SessionStateStore(sessionStore: sessionStore, artifactStore: artifactStore, draftStore: draftStore)
        let start = Date(timeIntervalSince1970: 10)

        state.startSession(workout: workout, at: start)
        state.endSession(at: start.addingTimeInterval(90))

        let completed = try XCTUnwrap(sessionStore.sessions.first)
        XCTAssertFalse(completed.workoutArtifactID.isEmpty)
        XCTAssertEqual(completed.workoutSnapshot.id, workout.id)
        XCTAssertEqual(completed.workoutSnapshot.title, workout.title)
        XCTAssertNotNil(artifactStore.artifact(id: completed.workoutArtifactID))
    }
}

final class WorkoutArtifactStoreTests: XCTestCase {
    @MainActor
    func testProvenanceChainReturnsParentLineage() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutArtifactStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = WorkoutArtifactStore(fileURL: baseURL.appendingPathComponent("artifacts.json"))
        let now = Date(timeIntervalSince1970: 1_000)
        let root = makeArtifact(id: "root", parent: nil, createdAt: now)
        let child = makeArtifact(id: "child", parent: "root", createdAt: now.addingTimeInterval(60))
        let grandchild = makeArtifact(id: "grandchild", parent: "child", createdAt: now.addingTimeInterval(120))

        try store.appendArtifact(root)
        try store.appendArtifact(child)
        try store.appendArtifact(grandchild)

        XCTAssertEqual(store.provenanceChain(for: "grandchild").map(\.id), ["grandchild", "child", "root"])
    }

    @MainActor
    func testUpsertPersistsArtifactsAcrossReload() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutArtifactStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let fileURL = baseURL.appendingPathComponent("artifacts.json")
        let store = WorkoutArtifactStore(fileURL: fileURL)
        let artifact = makeArtifact(id: "persisted", parent: nil, createdAt: Date(timeIntervalSince1970: 1_000))

        try store.upsertArtifact(artifact)

        let reloaded = WorkoutArtifactStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.artifact(id: "persisted")?.id, artifact.id)
    }

    private func makeArtifact(id: String, parent: WorkoutArtifactID?, createdAt: Date) -> WorkoutArtifact {
        let reference = WorkoutReference(id: "workout-\(id)", source: .generated, title: "Workout \(id)", versionHash: "v1")
        return WorkoutArtifact(
            id: id,
            workout: WorkoutDefinition.snapshotFallback(from: reference),
            provenance: WorkoutArtifactProvenance(
                baseWorkoutID: reference.id,
                sourceSessionID: nil,
                parentArtifactID: parent,
                derivationMode: .generated,
                createdAt: createdAt
            ),
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

final class WorkoutSessionMigrationTests: XCTestCase {
    func testLegacySessionDecodeBackfillsArtifactAndSnapshot() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000123",
          "workout": {
            "id": "legacy-workout",
            "source": "knowledgeBase",
            "title": "Legacy Workout",
            "versionHash": "abc123"
          },
          "startedAt": "2026-02-22T10:00:00Z",
          "endedAt": "2026-02-22T10:30:00Z",
          "durationSeconds": 1800,
          "timerMode": "stopwatch",
          "logEntries": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let session = try decoder.decode(WorkoutSession.self, from: Data(json.utf8))

        XCTAssertEqual(session.workoutArtifactID, "legacy-workout")
        XCTAssertEqual(session.workoutSnapshot.id, "legacy-workout")
        XCTAssertEqual(session.workoutSnapshot.title, "Legacy Workout")
        XCTAssertEqual(session.workoutSnapshot.versionHash, "abc123")
    }
}

final class DiscoveryGenerationPolicyTests: XCTestCase {
    func testGenerativeIntentTriggersInitialGenerationWhenAvailable() {
        let policy = DiscoveryGenerationPolicy(lowConfidenceThreshold: 0.3)
        let intent = policy.classifyIntent(query: "create a new lower body plan")
        let confidence = RetrievalConfidence(score: 0.8, threshold: 0.3)

        let decision = policy.initialDecision(intent: intent, retrievalConfidence: confidence, llmAvailable: true)

        XCTAssertTrue(decision.shouldGenerate)
        XCTAssertEqual(decision.trigger, .initialQuery)
    }

    func testSearchlikeLowConfidenceTriggersGeneration() {
        let policy = DiscoveryGenerationPolicy(lowConfidenceThreshold: 0.5)
        let intent = policy.classifyIntent(query: "quick upper body")
        let confidence = RetrievalConfidence(score: 0.2, threshold: 0.5)

        let decision = policy.initialDecision(intent: intent, retrievalConfidence: confidence, llmAvailable: true)

        XCTAssertEqual(intent, .searchlike)
        XCTAssertTrue(decision.shouldGenerate)
        XCTAssertEqual(decision.trigger, .lowRetrievalConfidence)
    }

    func testLoadMoreHonorsLLMAvailability() {
        let policy = DiscoveryGenerationPolicy()

        XCTAssertTrue(policy.loadMoreDecision(llmAvailable: true).shouldGenerate)
        XCTAssertFalse(policy.loadMoreDecision(llmAvailable: false).shouldGenerate)
    }
}

final class TemplateVariantStoreTests: XCTestCase {
    @MainActor
    func testTemplateAndVariantRoundTrip() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemplateVariantStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let templateStore = WorkoutTemplateStore(fileURL: baseURL.appendingPathComponent("templates.json"))
        let variantStore = WorkoutVariantStore(fileURL: baseURL.appendingPathComponent("variants.json"))

        let baseWorkout = makeWorkout(id: "base-1", title: "Base Workout")
        let createdTemplate = try templateStore.createTemplateFromWorkout(baseWorkout)
        _ = try templateStore.duplicateTemplate(createdTemplate)
        try templateStore.renameTemplate(id: createdTemplate.id, title: "Edited Template")

        _ = try variantStore.createVariant(from: baseWorkout, title: "Base Variant")
        let resolved = variantStore.resolveWorkouts(baseWorkouts: [baseWorkout] + templateStore.asWorkouts())

        XCTAssertTrue(templateStore.templates.contains(where: { $0.title == "Edited Template" }))
        XCTAssertTrue(templateStore.templates.count >= 2)
        XCTAssertEqual(resolved.first?.source, .variant)
        XCTAssertEqual(resolved.first?.title, "Base Variant")
    }

    @MainActor
    private func makeWorkout(id: WorkoutID, title: String) -> WorkoutDefinition {
        WorkoutDefinition(
            id: id,
            source: .knowledgeBase,
            sourceID: id,
            sourceURL: nil,
            title: title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: 30,
                focusTags: ["strength"],
                equipmentTags: ["dumbbell"],
                locationTag: "Home",
                otherTags: []
            ),
            content: WorkoutContent(
                sourceMarkdown: "# \(title)",
                parsedSections: [WorkoutSection(title: "Main", items: [WorkoutItem(name: "Squat")])],
                notes: nil
            ),
            timerConfiguration: nil,
            versionHash: "v1",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}
