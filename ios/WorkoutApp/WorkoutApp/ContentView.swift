import Network
import Markdown
import SwiftUI

enum AppTab: Hashable {
    case discover
    case session
    case history
    case settings
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DiscoveryView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles")
            }
            .tag(AppTab.discover)

            NavigationStack {
                SessionView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Session", systemImage: "timer")
            }
            .tag(AppTab.session)

            NavigationStack {
                HistoryView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("History", systemImage: "chart.bar")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsMockView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum DurationFilter: String, CaseIterable, Identifiable {
    case short = "<= 20 min"
    case medium = "25-40 min"
    case long = "45+ min"

    var id: String { rawValue }
}

struct DiscoveryView: View {
    @EnvironmentObject private var preferencesStore: UserPreferencesStore
    @EnvironmentObject private var sessionStore: WorkoutSessionStore
    @EnvironmentObject private var templateStore: WorkoutTemplateStore
    @EnvironmentObject private var variantStore: WorkoutVariantStore
    @EnvironmentObject private var generatedCandidateStore: GeneratedCandidateStore
    @EnvironmentObject private var debugLogStore: DebugLogStore
    @Binding var selectedTab: AppTab
    @StateObject private var networkMonitor = NetworkStatusMonitor()
    @State private var workouts: [WorkoutDefinition] = []
    @State private var loadError: String?
    @State private var hasLoaded = false
    @State private var searchQuery = ""
    @State private var searchResults: [WorkoutSearchResult] = []
    @State private var searchIndex: WorkoutSearchIndex?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchIndexBuildTask: Task<Void, Never>?
    @State private var generationDebounceTask: Task<Void, Never>?
    @State private var isLoadingWorkouts = false
    @State private var selectedEquipment: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var selectedDurations: Set<DurationFilter> = []
    @State private var generatedCandidates: [GeneratedCandidate] = []
    @State private var generatedBatchCount = 0
    @State private var isGenerating = false
    @State private var showTemplateManager = false
    @State private var searchRevision = 0
    @State private var generationStatusNote: String?
    @State private var showDebugLogs = false

    private let equipmentFilterOptions = ["Bodyweight", "Dumbbell", "Barbell", "Band", "Kettlebell"]
    private let locationFilterOptions = ["Home", "Gym", "Away"]
    private let recommendationEngine = WorkoutRecommendationEngine()
    private let generationPolicy = DiscoveryGenerationPolicy()
    private let functionCallingService = OpenAIFunctionCallingService()

    private var recommendationsByWorkoutID: [WorkoutID: RankedWorkout] {
        Dictionary(uniqueKeysWithValues: rankedWorkouts.map { ($0.workout.id, $0) })
    }

    private var allWorkouts: [WorkoutDefinition] {
        let templates = templateStore.asWorkouts()
        let variants = variantStore.resolveWorkouts(baseWorkouts: workouts + templates)
        return workouts + templates + variants
    }

    private var rankedWorkouts: [RankedWorkout] {
        recommendationEngine.rank(
            workouts: allWorkouts,
            history: sessionStore.sessions,
            preferences: preferencesStore.preferences.discovery
        )
    }

    private var filteredRecommendations: [RankedWorkout] {
        rankedWorkouts.filter { workoutMatchesFilters($0.workout) }
    }

    private var highlightedWorkout: WorkoutDefinition? {
        filteredRecommendations.first?.workout
    }

    private var hasActiveFilters: Bool {
        !selectedEquipment.isEmpty || !selectedLocations.isEmpty || !selectedDurations.isEmpty
    }

    private var filteredSearchResults: [WorkoutSearchResult] {
        searchResults.filter { workoutMatchesFilters($0.workout) }
    }

    private var generatedWorkouts: [WorkoutDefinition] {
        generatedCandidates.map { $0.asWorkoutDefinition() }.filter { workoutMatchesFilters($0) }
    }

    private var llmAvailable: Bool {
        preferencesStore.llmRuntimeState(isNetworkAvailable: networkMonitor.isNetworkAvailable) == .ready
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan your workout")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("Find existing workouts first, then generate new options when needed.")
                        .foregroundStyle(.secondary)
                }

                SearchField(text: $searchQuery, placeholder: "Plan your workout")

                HStack {
                    Button("Manage Templates & Variants") {
                        showTemplateManager = true
                    }
                    .buttonStyle(.bordered)
                    Button("Logs") {
                        showDebugLogs = true
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if isLoadingWorkouts, !workouts.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more workouts...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let loadError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unable to load workouts")
                            .font(.headline)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if workouts.isEmpty {
                    ProgressView("Loading workouts...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Matched Workouts")
                            .font(.headline)

                        if filteredSearchResults.isEmpty {
                            Text(hasActiveFilters ? "No workouts match that search and filters." : "No workouts match that search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredSearchResults) { result in
                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: result.workout,
                                        recommendation: recommendationsByWorkoutID[result.workout.id],
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    WorkoutRow(workout: result.workout, recommendation: recommendationsByWorkoutID[result.workout.id])
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !generatedWorkouts.isEmpty {
                            Text("Generated")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(generatedWorkouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: workout,
                                        recommendation: nil,
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    WorkoutRow(workout: workout, recommendation: nil, isNew: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if llmAvailable {
                            Button {
                                loadMoreGenerated()
                            } label: {
                                Text(isGenerating ? "Generating..." : "Generate More Ideas")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor.opacity(0.15))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(isGenerating)
                            if let generationStatusNote, !generationStatusNote.isEmpty {
                                Text(generationStatusNote)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("LLM unavailable. Discovery is retrieval-only right now.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    if filteredRecommendations.isEmpty {
                        Text(hasActiveFilters ? "No workouts match those filters." : "No workouts available.")
                            .foregroundStyle(.secondary)
                    } else {
                        if let highlightedWorkout {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today")
                                    .font(.headline)

                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: highlightedWorkout,
                                        recommendation: recommendationsByWorkoutID[highlightedWorkout.id],
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    HighlightCard(
                                        title: highlightedWorkout.title,
                                        subtitle: sectionSummary(for: highlightedWorkout),
                                        detail: recommendationsByWorkoutID[highlightedWorkout.id]?.primaryReason ?? "Loaded from the knowledge base"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended")
                                .font(.headline)

                            ForEach(filteredRecommendations) { rankedWorkout in
                                NavigationLink {
                                    WorkoutDetailView(
                                        workout: rankedWorkout.workout,
                                        recommendation: rankedWorkout,
                                        selectedTab: $selectedTab
                                    )
                                } label: {
                                    WorkoutRow(workout: rankedWorkout.workout, recommendation: rankedWorkout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Filters")
                            .font(.headline)

                        if hasActiveFilters {
                            Button("Clear") {
                                selectedEquipment.removeAll()
                                selectedLocations.removeAll()
                                selectedDurations.removeAll()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Equipment")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(equipmentFilterOptions, id: \.self) { option in
                                    FilterChip(
                                        title: option,
                                        isSelected: selectedEquipment.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedEquipment)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DurationFilter.allCases) { option in
                                    FilterChip(
                                        title: option.rawValue,
                                        isSelected: selectedDurations.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedDurations)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(locationFilterOptions, id: \.self) { option in
                                    FilterChip(
                                        title: option,
                                        isSelected: selectedLocations.contains(option)
                                    ) {
                                        toggleSelection(option, set: $selectedLocations)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Plan")
        .task {
            loadWorkoutsIfNeeded()
        }
        .onChange(of: searchQuery) { _, _ in
            searchRevision += 1
            scheduleSearch()
        }
        .onChange(of: templateStore.templates) { _, _ in
            rebuildSearchIndex()
        }
        .onChange(of: variantStore.variants) { _, _ in
            rebuildSearchIndex()
        }
        .sheet(isPresented: $showTemplateManager) {
            TemplateVariantManagerView()
        }
        .sheet(isPresented: $showDebugLogs) {
            DebugLogsView()
        }
    }

    private func sectionSummary(for workout: WorkoutDefinition) -> String {
        let titles = workout.content.parsedSections?.prefix(3).map { $0.title } ?? []
        if titles.isEmpty {
            return "Knowledge base workout"
        }
        return titles.joined(separator: " / ")
    }

    private func loadWorkoutsIfNeeded() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        loadError = nil
        isLoadingWorkouts = true
        workouts = []
        rebuildSearchIndex()
        Task.detached(priority: .userInitiated) {
            do {
                try await KnowledgeBaseLoader().loadWorkoutsIncrementally(batchSize: 8) { batch in
                    guard !batch.isEmpty else {
                        return
                    }
                    workouts.append(contentsOf: batch)
                }
                await MainActor.run {
                    isLoadingWorkouts = false
                    rebuildSearchIndex()
                }
            } catch {
                await MainActor.run {
                    isLoadingWorkouts = false
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        let index = searchIndex
        let revision = searchRevision
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let index else {
                await MainActor.run {
                    searchResults = []
                    generatedCandidates = []
                    generatedBatchCount = 0
                    generationDebounceTask?.cancel()
                }
                return
            }
            let results = await Task.detached(priority: .userInitiated) {
                index.search(query: trimmed, limit: 25)
            }.value
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard revision == searchRevision else {
                    return
                }
                searchResults = results
                scheduleGenerationEvaluation(for: trimmed, with: results, revision: revision)
            }
        }
    }

    private func scheduleGenerationEvaluation(
        for query: String,
        with results: [WorkoutSearchResult],
        revision: Int
    ) {
        generationDebounceTask?.cancel()
        generationDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else {
                return
            }
            let currentQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard revision == searchRevision, currentQuery == query else {
                return
            }
            evaluateGenerationPolicy(for: query, with: results)
        }
    }

    private func rebuildSearchIndex() {
        searchIndexBuildTask?.cancel()
        let workoutsForIndex = allWorkouts
        searchIndexBuildTask = Task {
            let index = await Task.detached(priority: .userInitiated) {
                WorkoutSearchIndex(workouts: workoutsForIndex)
            }.value
            guard !Task.isCancelled else {
                return
            }
            searchIndex = index
            scheduleSearch()
        }
    }

    private func evaluateGenerationPolicy(for query: String, with results: [WorkoutSearchResult]) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            generatedCandidates = []
            generatedBatchCount = 0
            return
        }

        let intent = generationPolicy.classifyIntent(query: normalized)
        let confidence = generationPolicy.retrievalConfidence(for: results)
        let decision = generationPolicy.initialDecision(
            intent: intent,
            retrievalConfidence: confidence,
            llmAvailable: llmAvailable
        )

        if generatedCandidates.first?.originQuery != normalized {
            generatedCandidates = []
            generatedBatchCount = 0
        }

        if decision.shouldGenerate, generatedCandidates.isEmpty {
            generateCandidates(query: normalized, trigger: decision.trigger ?? .initialQuery)
            return
        }

        generatedCandidateStore.saveCandidates(generatedCandidates, forQuery: normalized)
    }

    private func loadMoreGenerated() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        let decision = generationPolicy.loadMoreDecision(llmAvailable: llmAvailable)
        guard decision.shouldGenerate else {
            return
        }
        generateCandidates(query: trimmed, trigger: .bottomDetent)
    }

    private func generateCandidates(query: String, trigger: GenerationTrigger) {
        guard llmAvailable else {
            return
        }
        guard !isGenerating else {
            return
        }
        isGenerating = true

        let contextWorkouts = Array(filteredSearchResults.prefix(3).map(\.workout))
        let baseBatch = generatedBatchCount
        debugLogStore.log(
            .info,
            category: "generation",
            message: "Starting batch \(baseBatch + 1) for query '\(query)' with trigger '\(trigger.rawValue)'."
        )
        Task(priority: .userInitiated) {
            let result = await generatePipelineCandidates(
                query: query,
                batchIndex: baseBatch,
                trigger: trigger,
                contextWorkouts: contextWorkouts
            )
            let newValues = result.candidates.filter { candidate in
                !generatedCandidates.contains(where: { $0.id == candidate.id })
            }
            generatedCandidates.append(contentsOf: newValues)
            generatedBatchCount += 1
            isGenerating = false
            generatedCandidateStore.saveCandidates(generatedCandidates, forQuery: query)
            generationStatusNote = result.note
            debugLogStore.log(
                result.usedFallback ? .warning : .info,
                category: "generation",
                message: result.note
            )
        }
    }

    private struct GenerationBatchResult {
        var candidates: [GeneratedCandidate]
        var note: String
        var usedFallback: Bool
    }

    private func generatePipelineCandidates(
        query: String,
        batchIndex: Int,
        trigger: GenerationTrigger,
        contextWorkouts: [WorkoutDefinition]
    ) async -> GenerationBatchResult {
        let desiredCount = 5
        if let apiKey = preferencesStore.llmAPIKey(),
           preferencesStore.preferences.llm.enabled {
            do {
                let liveCandidates = try await functionCallingService.generateCandidates(
                    query: query,
                    contextWorkouts: contextWorkouts,
                    trigger: trigger,
                    count: desiredCount,
                    modelID: preferencesStore.preferences.llm.modelID,
                    apiKey: apiKey
                )
                if !liveCandidates.isEmpty {
                    if liveCandidates.count >= desiredCount {
                        return GenerationBatchResult(
                            candidates: Array(liveCandidates.prefix(desiredCount)),
                            note: "Generated with live function-calling pipeline.",
                            usedFallback: false
                        )
                    }

                    let fallback = deterministicPipelineCandidates(
                        query: query,
                        batchIndex: batchIndex,
                        trigger: trigger,
                        contextWorkouts: contextWorkouts
                    )
                    let needed = max(0, desiredCount - liveCandidates.count)
                    return GenerationBatchResult(
                        candidates: liveCandidates + Array(fallback.prefix(needed)),
                        note: "Mixed live function-calling + fallback generation (\(liveCandidates.count)/\(desiredCount) live).",
                        usedFallback: true
                    )
                }
            } catch {
                let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                debugLogStore.log(
                    .error,
                    category: "generation",
                    message: "Live function-calling failed for query '\(query)': \(reason)"
                )
                return GenerationBatchResult(
                    candidates: deterministicPipelineCandidates(
                        query: query,
                        batchIndex: batchIndex,
                        trigger: trigger,
                        contextWorkouts: contextWorkouts
                    ),
                    note: "Used deterministic fallback generation. Live generation failed: \(reason)",
                    usedFallback: true
                )
            }
        }

        return GenerationBatchResult(
            candidates: deterministicPipelineCandidates(
                query: query,
                batchIndex: batchIndex,
                trigger: trigger,
                contextWorkouts: contextWorkouts
            ),
            note: "Used deterministic fallback generation.",
            usedFallback: true
        )
    }

    private func deterministicPipelineCandidates(
        query: String,
        batchIndex: Int,
        trigger: GenerationTrigger,
        contextWorkouts: [WorkoutDefinition]
    ) -> [GeneratedCandidate] {
        let maxRounds = 2
        let maxRepairAttempts = 1
        let now = Date()

        var drafts: [GeneratedCandidate] = []
        for offset in 0..<5 {
            let id = "gen-\(batchIndex)-\(offset)-\(UUID().uuidString.prefix(6))"
            let title = generatedTitleSeed(query: query, index: batchIndex * 5 + offset)
            let explanation = "Generated from your request with \(contextWorkouts.count) retrieved context workouts. Trigger: \(trigger.rawValue)."
            let sections = generatedSections(query: query, seed: batchIndex * 5 + offset)
            let markdown = generatedMarkdown(title: title, sections: sections)
            let candidate = GeneratedCandidate(
                id: id,
                title: title,
                summary: "New option tailored to \(query).",
                content: WorkoutContent(sourceMarkdown: markdown, parsedSections: sections, notes: nil),
                explanation: explanation,
                originQuery: query,
                isSaved: false,
                createdAt: now,
                provenance: GeneratedCandidateProvenance(
                    originQuery: query,
                    baseWorkoutID: contextWorkouts.first?.id,
                    revisionPrompt: nil,
                    revisionIndex: 0,
                    contextWorkoutIDs: contextWorkouts.map(\.id),
                    generationRound: 1,
                    repairAttempts: 0,
                    createdAt: now
                )
            )
            drafts.append(candidate)
        }

        // Bounded refine/validate loop; rounds stay deterministic for predictable rendering/tests.
        for round in 1..<maxRounds {
            drafts = drafts.map { candidate in
                var updated = candidate
                updated.summary = "\(candidate.summary) Refined pass \(round + 1)."
                updated.provenance.generationRound = round + 1
                return updated
            }
        }

        return drafts.compactMap { candidate in
            var repairAttempts = 0
            var value = candidate
            while repairAttempts <= maxRepairAttempts {
                if validateGeneratedCandidate(value) {
                    value.provenance.repairAttempts = repairAttempts
                    return value
                }
                repairAttempts += 1
                value.title = "Workout Plan \(Int.random(in: 10...999))"
            }
            return nil
        }
    }

    private func validateGeneratedCandidate(_ candidate: GeneratedCandidate) -> Bool {
        let trimmedTitle = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return false
        }
        return !(candidate.content.parsedSections ?? []).isEmpty
    }

    private func generatedTitleSeed(query: String, index: Int) -> String {
        let prefixes = ["Adaptive", "Focused", "Progressive", "Balanced", "Compact", "Hybrid"]
        let suffixes = ["Builder", "Session", "Circuit", "Flow", "Block", "Plan"]
        let prefix = prefixes[index % prefixes.count]
        let suffix = suffixes[(index / 2) % suffixes.count]
        return "\(prefix) \(query.capitalized) \(suffix)"
    }

    private func generatedSections(query: String, seed: Int) -> [WorkoutSection] {
        let profile = queryProfile(for: query)
        let effort = max(6, min(18, (profile.durationMinutes ?? 30) / 4))
        let equipmentLabel = profile.equipment ?? "bodyweight"
        let mainPair = primaryExercisePair(focus: profile.focus, equipment: equipmentLabel, seed: seed)
        let accessory = accessoryExercise(focus: profile.focus, equipment: equipmentLabel, seed: seed)
        return [
            WorkoutSection(
                title: "Warmup",
                detail: "Prime movement patterns for \(profile.focus) work.",
                items: [
                    WorkoutItem(name: "Easy cardio", prescription: "\(effort) minutes"),
                    WorkoutItem(name: "Dynamic mobility flow", prescription: "2 rounds"),
                    WorkoutItem(name: "\(equipmentLabel.capitalized) prep drill", prescription: "2 x 8")
                ]
            ),
            WorkoutSection(
                title: "Main Set",
                detail: "Primary work tuned to \(query) using \(equipmentLabel).",
                items: [
                    WorkoutItem(name: mainPair.0, prescription: "4 x 6-8"),
                    WorkoutItem(name: mainPair.1, prescription: "4 x 8-10"),
                    WorkoutItem(name: accessory, prescription: "3 rounds")
                ]
            ),
            WorkoutSection(
                title: "Cooldown",
                detail: "Downshift and recover from \(profile.focus) loading.",
                items: [
                    WorkoutItem(name: "Breathing + stretch", prescription: "5 minutes")
                ]
            )
        ]
    }

    private struct QueryProfile {
        var focus: String
        var equipment: String?
        var durationMinutes: Int?
    }

    private func queryProfile(for query: String) -> QueryProfile {
        let value = query.lowercased()
        let focus: String
        if value.contains("upper") || value.contains("chest") || value.contains("back") || value.contains("shoulder") {
            focus = "upper body"
        } else if value.contains("lower") || value.contains("leg") || value.contains("glute") {
            focus = "lower body"
        } else if value.contains("core") || value.contains("abs") {
            focus = "core"
        } else if value.contains("mobility") || value.contains("recovery") {
            focus = "mobility"
        } else {
            focus = "full body"
        }

        let equipment: String?
        if value.contains("dumbbell") {
            equipment = "dumbbell"
        } else if value.contains("barbell") {
            equipment = "barbell"
        } else if value.contains("kettlebell") {
            equipment = "kettlebell"
        } else if value.contains("band") {
            equipment = "band"
        } else {
            equipment = nil
        }

        let duration = Self.extractDurationMinutes(from: value)
        return QueryProfile(focus: focus, equipment: equipment, durationMinutes: duration)
    }

    private func primaryExercisePair(focus: String, equipment: String, seed: Int) -> (String, String) {
        let pairs: [(String, String)]
        switch (focus, equipment) {
        case ("upper body", "dumbbell"):
            pairs = [("Dumbbell bench press", "One-arm dumbbell row"), ("Dumbbell incline press", "Dumbbell supported row")]
        case ("lower body", "dumbbell"):
            pairs = [("Dumbbell goblet squat", "Dumbbell Romanian deadlift"), ("Dumbbell split squat", "Dumbbell hip hinge")]
        case ("core", _):
            pairs = [("Weighted dead bug", "Plank drag-through"), ("Hollow body hold", "Side plank reach-through")]
        case ("mobility", _):
            pairs = [("World's greatest stretch", "90/90 hip switch"), ("Thoracic rotation flow", "Ankle dorsiflexion rocks")]
        default:
            pairs = [("Squat pattern", "Push pattern"), ("Hinge pattern", "Pull pattern")]
        }
        return pairs[seed % pairs.count]
    }

    private func accessoryExercise(focus: String, equipment: String, seed: Int) -> String {
        let options: [String]
        switch (focus, equipment) {
        case ("upper body", "dumbbell"):
            options = ["Dumbbell lateral raise + curl superset", "Dumbbell triceps extension + rear delt fly"]
        case ("lower body", "dumbbell"):
            options = ["Dumbbell reverse lunge + calf raise", "Dumbbell step-up + hamstring bridge"]
        case ("core", _):
            options = ["Pallof press + bear crawl", "Hanging knee raise + suitcase carry"]
        case ("mobility", _):
            options = ["Controlled articular rotations circuit", "Low-load tempo flow circuit"]
        default:
            options = ["Accessory superset", "Tempo conditioning finisher"]
        }
        return options[seed % options.count]
    }

    private func generatedMarkdown(title: String, sections: [WorkoutSection]) -> String {
        var lines: [String] = ["# \(title)"]
        for section in sections {
            lines.append("## \(section.title)")
            if let detail = section.detail, !detail.isEmpty {
                lines.append(detail)
            }
            for item in section.items {
                if let prescription = item.prescription, !prescription.isEmpty {
                    lines.append("- \(item.name) — \(prescription)")
                } else {
                    lines.append("- \(item.name)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private func workoutMatchesFilters(_ workout: WorkoutDefinition) -> Bool {
        if !selectedEquipment.isEmpty {
            let equipment = workoutEquipmentTags(for: workout)
            if equipment.intersection(selectedEquipment).isEmpty {
                return false
            }
        }

        if !selectedLocations.isEmpty {
            guard let location = workoutLocationTag(for: workout) else {
                return false
            }
            if !selectedLocations.contains(location) {
                return false
            }
        }

        if !selectedDurations.isEmpty {
            guard let duration = estimatedDurationMinutes(for: workout) else {
                return false
            }
            let bucket = durationBucket(for: duration)
            if !selectedDurations.contains(bucket) {
                return false
            }
        }

        return true
    }

    private func workoutLocationTag(for workout: WorkoutDefinition) -> String? {
        if let tag = workout.metadata.locationTag, !tag.isEmpty {
            return tag
        }
        let title = workout.title.lowercased()
        if title.contains("home") {
            return "Home"
        }
        if title.contains("away") {
            return "Away"
        }
        if title.contains("gym") {
            return "Gym"
        }
        return nil
    }

    private func workoutEquipmentTags(for workout: WorkoutDefinition) -> Set<String> {
        if !workout.metadata.equipmentTags.isEmpty {
            return Set(workout.metadata.equipmentTags)
        }

        let haystack = (workout.title + " " + workout.content.sourceMarkdown).lowercased()
        var tags: [String] = []
        if haystack.contains("bodyweight") {
            tags.append("Bodyweight")
        }
        if haystack.contains("dumbbell") {
            tags.append("Dumbbell")
        }
        if haystack.contains("barbell") {
            tags.append("Barbell")
        }
        if haystack.contains("band") {
            tags.append("Band")
        }
        if haystack.contains("kettlebell") {
            tags.append("Kettlebell")
        }
        return Set(tags)
    }

    private func estimatedDurationMinutes(for workout: WorkoutDefinition) -> Int? {
        if let duration = workout.metadata.durationMinutes {
            return duration
        }

        let markdown = workout.content.sourceMarkdown.lowercased()
        if let minutes = Self.extractDurationMinutes(from: markdown) {
            return minutes
        }

        let itemCount = workout.content.parsedSections?.reduce(0) { $0 + $1.items.count } ?? 0
        guard itemCount > 0 else {
            return nil
        }
        return max(12, min(60, itemCount * 2))
    }

    private func durationBucket(for minutes: Int) -> DurationFilter {
        if minutes <= 20 {
            return .short
        }
        if minutes <= 40 {
            return .medium
        }
        return .long
    }

    private static func extractDurationMinutes(from text: String) -> Int? {
        let pattern = "\\b(\\d{1,3})\\s*(?:min|mins|minutes)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let minutesRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(String(text[minutesRange]))
    }

    private func toggleSelection<T: Hashable>(_ value: T, set: Binding<Set<T>>) {
        var updated = set.wrappedValue
        if updated.contains(value) {
            updated.remove(value)
        } else {
            updated.insert(value)
        }
        set.wrappedValue = updated
    }
}

struct TemplateVariantManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var templateStore: WorkoutTemplateStore
    @EnvironmentObject private var variantStore: WorkoutVariantStore
    @State private var newTemplateTitle = ""
    @State private var renameTemplateID: WorkoutID?
    @State private var renameVariantID: WorkoutID?
    @State private var renameValue = ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Create") {
                    TextField("New template title", text: $newTemplateTitle)
                    Button("Create Template From Scratch") {
                        let trimmed = newTemplateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            return
                        }
                        do {
                            _ = try templateStore.createTemplateFromScratch(title: trimmed)
                            newTemplateTitle = ""
                            statusMessage = "Template created."
                        } catch {
                            statusMessage = "Unable to create template."
                        }
                    }
                }

                Section("Templates") {
                    if templateStore.templates.isEmpty {
                        Text("No templates yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templateStore.templates) { template in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.title)
                                    .fontWeight(.semibold)
                                if let summary = template.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Rename") {
                                    renameTemplateID = template.id
                                    renameValue = template.title
                                }
                                .tint(.blue)
                                Button("Duplicate") {
                                    do {
                                        _ = try templateStore.duplicateTemplate(template)
                                        statusMessage = "Template duplicated."
                                    } catch {
                                        statusMessage = "Unable to duplicate template."
                                    }
                                }
                                .tint(.indigo)
                                Button("Variant") {
                                    do {
                                        let workout = WorkoutDefinition(
                                            id: template.id,
                                            source: .template,
                                            sourceID: template.baseWorkoutID ?? template.id,
                                            sourceURL: nil,
                                            title: template.title,
                                            summary: template.summary,
                                            metadata: template.metadata,
                                            content: template.content,
                                            timerConfiguration: template.timerConfiguration,
                                            versionHash: template.baseVersionHash,
                                            createdAt: template.createdAt,
                                            updatedAt: template.updatedAt
                                        )
                                        _ = try variantStore.createVariant(from: workout)
                                        statusMessage = "Variant created from template."
                                    } catch {
                                        statusMessage = "Unable to create variant."
                                    }
                                }
                                .tint(.orange)
                                Button("Delete", role: .destructive) {
                                    do {
                                        try templateStore.deleteTemplate(id: template.id)
                                        statusMessage = "Template deleted."
                                    } catch {
                                        statusMessage = "Unable to delete template."
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Variants") {
                    if variantStore.variants.isEmpty {
                        Text("No variants yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(variantStore.variants) { variant in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(variant.overrides.title ?? "Variant")
                                    .fontWeight(.semibold)
                                Text("Base: \(variant.baseWorkoutID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Rename") {
                                    renameVariantID = variant.id
                                    renameValue = variant.overrides.title ?? ""
                                }
                                .tint(.blue)
                                Button("Duplicate") {
                                    do {
                                        _ = try variantStore.duplicateVariant(variant)
                                        statusMessage = "Variant duplicated."
                                    } catch {
                                        statusMessage = "Unable to duplicate variant."
                                    }
                                }
                                .tint(.indigo)
                                Button("Delete", role: .destructive) {
                                    do {
                                        try variantStore.deleteVariant(id: variant.id)
                                        statusMessage = "Variant deleted."
                                    } catch {
                                        statusMessage = "Unable to delete variant."
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Templates & Variants")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Rename Template", isPresented: Binding(
                get: { renameTemplateID != nil },
                set: { if !$0 { renameTemplateID = nil } }
            )) {
                TextField("Title", text: $renameValue)
                Button("Save") {
                    guard let id = renameTemplateID else { return }
                    do {
                        try templateStore.renameTemplate(id: id, title: renameValue)
                        statusMessage = "Template updated."
                    } catch {
                        statusMessage = "Unable to update template."
                    }
                    renameTemplateID = nil
                }
                Button("Cancel", role: .cancel) {
                    renameTemplateID = nil
                }
            }
            .alert("Rename Variant", isPresented: Binding(
                get: { renameVariantID != nil },
                set: { if !$0 { renameVariantID = nil } }
            )) {
                TextField("Title", text: $renameValue)
                Button("Save") {
                    guard let id = renameVariantID else { return }
                    do {
                        try variantStore.renameVariant(id: id, title: renameValue)
                        statusMessage = "Variant updated."
                    } catch {
                        statusMessage = "Unable to update variant."
                    }
                    renameVariantID = nil
                }
                Button("Cancel", role: .cancel) {
                    renameVariantID = nil
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground).opacity(0.95))
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject private var sessionState: SessionStateStore
    @EnvironmentObject private var templateStore: WorkoutTemplateStore
    @EnvironmentObject private var variantStore: WorkoutVariantStore
    let workout: WorkoutDefinition
    let recommendation: RankedWorkout?
    @Binding var selectedTab: AppTab
    @State private var managementMessage: String?

    private var sectionCount: Int {
        workout.content.parsedSections?.count ?? 0
    }

    private var sectionTitles: [String] {
        workout.content.parsedSections?.prefix(3).map { $0.title } ?? []
    }

    private var overviewMarkdown: String {
        WorkoutMarkdownParser().strippedMarkdown(from: workout.content.sourceMarkdown)
    }

    private enum OverviewBlock: Identifiable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)

        var id: String {
            switch self {
            case .heading(let level, let text):
                return "h\(level):\(text)"
            case .paragraph(let text):
                return "p:\(text)"
            case .bullet(let text):
                return "b:\(text)"
            }
        }
    }

    private var overviewBlocks: [OverviewBlock] {
        let document = Document(parsing: overviewMarkdown)
        var blocks: [OverviewBlock] = []

        func listItemText(_ listItem: ListItem) -> String? {
            for child in listItem.children {
                if let paragraph = child as? Paragraph {
                    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : text
                }
            }
            return nil
        }

        for child in document.children {
            if let heading = child as? Heading {
                let text = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.heading(level: heading.level, text: text))
                }
                continue
            }

            if let paragraph = child as? Paragraph {
                let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.paragraph(text))
                }
                continue
            }

            if let list = child as? ListItemContainer {
                for listItem in list.listItems {
                    guard let text = listItemText(listItem) else {
                        continue
                    }
                    blocks.append(.bullet(text))
                }
            }
        }

        return blocks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(sectionTitles.isEmpty ? "Knowledge base workout" : sectionTitles.joined(separator: " / "))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    MockChip(title: "\(sectionCount) sections")
                    MockChip(title: sourceLabel(for: workout.source))
                }

                HighlightCard(
                    title: "Why this workout?",
                    subtitle: recommendation?.primaryReason ?? "Structured from the knowledge base",
                    detail: recommendation?.reasons.prefix(2).map(\.text).joined(separator: " • ") ?? "Sections parsed from the original Markdown"
                )

                if workout.source == .generated, let summary = workout.summary, !summary.isEmpty {
                    HighlightCard(
                        title: "Generation Rationale",
                        subtitle: summary,
                        detail: "Includes retrieval-informed context and validation before display."
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Overview")
                        .font(.headline)

                    Group {
                        if overviewBlocks.isEmpty {
                            Text(overviewMarkdown)
                                .font(.system(.body, design: .default))
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(overviewBlocks) { block in
                                    switch block {
                                    case .heading(let level, let text):
                                        Text(text)
                                            .font(level == 1 ? .title3.weight(.semibold) : .headline)
                                    case .paragraph(let text):
                                        Text(text)
                                            .font(.system(.body, design: .default))
                                    case .bullet(let text):
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("•")
                                            Text(text)
                                        }
                                        .font(.system(.body, design: .default))
                                    }
                                }
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                Button {
                    sessionState.startSession(workout: workout)
                    selectedTab = .session
                } label: {
                    Text("Start Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button("Save as Template") {
                        do {
                            _ = try templateStore.createTemplateFromWorkout(workout)
                            managementMessage = "Template saved."
                        } catch {
                            managementMessage = "Unable to save template."
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Create Variant") {
                        do {
                            _ = try variantStore.createVariant(from: workout)
                            managementMessage = "Variant created."
                        } catch {
                            managementMessage = "Unable to create variant."
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if let managementMessage {
                    Text(managementMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Workout")
    }

    private func sourceLabel(for source: WorkoutSource) -> String {
        switch source {
        case .knowledgeBase:
            return "Knowledge base"
        case .template:
            return "Template"
        case .variant:
            return "Variant"
        case .external:
            return "External"
        case .generated:
            return "Generated"
        }
    }
}

struct SessionView: View {
    @EnvironmentObject private var sessionState: SessionStateStore
    @Binding var selectedTab: AppTab
    @State private var showDiscardShortSessionPrompt = false

    private let shortSessionDiscardThresholdSeconds = 5 * 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let session = sessionState.activeSession {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Session")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(session.workout.title)
                            .foregroundStyle(.secondary)
                    }

                    TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                        let elapsed = session.elapsedSeconds(at: context.date)
                        HighlightCard(
                            title: "Session Timer",
                            subtitle: formattedDuration(elapsed),
                            detail: session.isPaused ? "Paused" : "Overall workout duration"
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sections")
                            .font(.headline)

                        if let sections = session.workout.content.parsedSections, !sections.isEmpty {
                            ForEach(sections) { section in
                                WorkoutSectionCard(section: section)
                            }
                        } else {
                            Text("No structured sections parsed yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            if session.isPaused {
                                sessionState.resumeSession()
                            } else {
                                sessionState.pauseSession()
                            }
                        } label: {
                            Text(session.isPaused ? "Resume Session" : "Pause Session")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            if session.elapsedSeconds() < shortSessionDiscardThresholdSeconds {
                                showDiscardShortSessionPrompt = true
                            } else {
                                sessionState.endSession()
                                selectedTab = .history
                            }
                        } label: {
                            Text("End Session")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(role: .destructive) {
                        sessionState.cancelSession()
                    } label: {
                        Text("Cancel Session")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Active Session")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(sessionState.phase == .finished
                             ? "Session complete. Start a new workout to see it here."
                             : "Start a workout to begin a session.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session")
        .sheet(isPresented: $showDiscardShortSessionPrompt) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Discard short session?")
                    .font(.headline)

                Text("This session is under 5 minutes. Save it anyway or discard it?")
                    .foregroundStyle(.secondary)

                Button {
                    sessionState.endSession()
                    selectedTab = .history
                    showDiscardShortSessionPrompt = false
                } label: {
                    Text("Save to History")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    sessionState.cancelSession()
                    showDiscardShortSessionPrompt = false
                } label: {
                    Text("Discard Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    showDiscardShortSessionPrompt = false
                } label: {
                    Text("Keep Working Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

}

struct HistoryView: View {
    @EnvironmentObject private var sessionState: SessionStateStore
    @EnvironmentObject private var sessionStore: WorkoutSessionStore
    @Binding var selectedTab: AppTab
    @State private var workoutLookup: [WorkoutID: WorkoutDefinition] = [:]
    @State private var searchQuery = ""
    @State private var sortOption: HistorySessionSortOption = .chronological
    @State private var semanticMatchedWorkoutIDs: Set<WorkoutID> = []
    @State private var searchIndex: WorkoutSearchIndex?
    @State private var searchTask: Task<Void, Never>?
    @State private var adjustingWorkout: WorkoutDefinition?

    init(selectedTab: Binding<AppTab>) {
        _selectedTab = selectedTab
    }

    private var allSessions: [WorkoutSession] {
        sessionStore.sessions
    }

    private var sessions: [WorkoutSession] {
        let filtered = HistorySessionDiscovery.filterSessions(
            allSessions,
            query: searchQuery,
            resolvedWorkouts: workoutLookup,
            semanticMatches: semanticMatchedWorkoutIDs
        )
        return HistorySessionDiscovery.sortSessions(
            filtered,
            allSessions: allSessions,
            option: sortOption
        )
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private var thisWeek: [WorkoutSession] {
        sessions.filter { sessionDate(for: $0) >= weekStart }
    }

    private var earlier: [WorkoutSession] {
        sessions.filter { sessionDate(for: $0) < weekStart }
    }

    private var totalMinutesThisWeek: Int {
        thisWeek.reduce(0) { total, session in
            total + max(0, sessionDurationMinutes(session))
        }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Section {
                    Text("No sessions logged yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("This Week")) {
                    HStack(spacing: 16) {
                        HistoryStat(title: "\(thisWeek.count)", subtitle: "sessions")
                        HistoryStat(title: "\(totalMinutesThisWeek)", subtitle: "minutes")
                        HistoryStat(title: "—", subtitle: "new PRs")
                    }
                    .padding(.vertical, 8)
                }

                if !thisWeek.isEmpty {
                    Section(header: Text("This Week Sessions")) {
                        ForEach(thisWeek) { session in
                            NavigationLink {
                                SessionDetailView(session: session) {
                                    startAgain(session)
                                } onAdjustStart: {
                                    adjustAndStart(session)
                                } onResume: {
                                    resumeSession(session)
                                }
                            } label: {
                                SessionRow(session: session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Resume") {
                                    resumeSession(session)
                                }
                                .tint(.green)
                                Button("Again") {
                                    startAgain(session)
                                }
                                .tint(.accentColor)
                                Button("Adjust") {
                                    adjustAndStart(session)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }

                if !earlier.isEmpty {
                    Section(header: Text("Earlier Sessions")) {
                        ForEach(earlier) { session in
                            NavigationLink {
                                SessionDetailView(session: session) {
                                    startAgain(session)
                                } onAdjustStart: {
                                    adjustAndStart(session)
                                } onResume: {
                                    resumeSession(session)
                                }
                            } label: {
                                SessionRow(session: session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Resume") {
                                    resumeSession(session)
                                }
                                .tint(.green)
                                Button("Again") {
                                    startAgain(session)
                                }
                                .tint(.accentColor)
                                Button("Adjust") {
                                    adjustAndStart(session)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .searchable(text: $searchQuery, prompt: "Search prior workouts or notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Sort") {
                    ForEach(HistorySessionSortOption.allCases) { option in
                        Button(option.title) {
                            sortOption = option
                        }
                    }
                }
            }
        }
        .task {
            await loadWorkoutLookupIfNeeded()
            rebuildSearchIndex()
            scheduleSearch()
        }
        .onChange(of: searchQuery) { _, _ in
            scheduleSearch()
        }
        .onChange(of: sessionStore.sessions) { _, _ in
            rebuildSearchIndex()
            scheduleSearch()
        }
        .navigationDestination(item: $adjustingWorkout) { workout in
            WorkoutDetailView(
                workout: workout,
                recommendation: nil,
                selectedTab: $selectedTab
            )
        }
    }

    private func sessionDate(for session: WorkoutSession) -> Date {
        session.endedAt ?? session.startedAt
    }

    private func sessionDurationMinutes(_ session: WorkoutSession) -> Int {
        if let durationSeconds = session.durationSeconds {
            return Int(round(Double(durationSeconds) / 60.0))
        }
        guard let endedAt = session.endedAt else { return 0 }
        return Int(round(endedAt.timeIntervalSince(session.startedAt) / 60.0))
    }

    private func startAgain(_ session: WorkoutSession) {
        let workout = resolveWorkout(for: session)
        sessionState.startSession(workout: workout)
        selectedTab = .session
    }

    private func resumeSession(_ session: WorkoutSession) {
        let workout = resolveWorkout(for: session)
        sessionState.startSession(
            workout: workout,
            initialElapsedSeconds: sessionElapsedSeconds(session),
            sessionID: session.id
        )
        selectedTab = .session
    }

    private func adjustAndStart(_ session: WorkoutSession) {
        adjustingWorkout = resolveWorkout(for: session)
    }

    private func sessionElapsedSeconds(_ session: WorkoutSession) -> Int {
        if let durationSeconds = session.durationSeconds {
            return max(0, durationSeconds)
        }
        if let endedAt = session.endedAt {
            return max(0, Int(endedAt.timeIntervalSince(session.startedAt)))
        }
        return 0
    }

    private func resolveWorkout(for session: WorkoutSession) -> WorkoutDefinition {
        if let knownWorkout = workoutLookup[session.workout.id] {
            return knownWorkout
        }
        return WorkoutDefinition(
            id: session.workout.id,
            source: session.workout.source,
            sourceID: session.workout.id,
            sourceURL: nil,
            title: session.workout.title,
            summary: nil,
            metadata: WorkoutMetadata(
                durationMinutes: nil,
                focusTags: [],
                equipmentTags: [],
                locationTag: nil,
                otherTags: []
            ),
            content: WorkoutContent(
                sourceMarkdown: "",
                parsedSections: nil,
                notes: nil
            ),
            timerConfiguration: nil,
            versionHash: session.workout.versionHash,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func loadWorkoutLookupIfNeeded() async {
        guard workoutLookup.isEmpty else { return }
        do {
            let workouts = try KnowledgeBaseLoader().loadWorkouts()
            workoutLookup = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        } catch {
            workoutLookup = [:]
        }
    }

    private func rebuildSearchIndex() {
        var uniqueWorkouts: [WorkoutID: WorkoutDefinition] = [:]
        for session in allSessions {
            uniqueWorkouts[session.workout.id] = resolveWorkout(for: session)
        }
        searchIndex = WorkoutSearchIndex(workouts: Array(uniqueWorkouts.values))
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let searchIndex else {
            semanticMatchedWorkoutIDs = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }

            let semanticMatches = await Task.detached(priority: .userInitiated) {
                Set(searchIndex.search(query: query, limit: 50).map { $0.workout.id })
            }.value

            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                semanticMatchedWorkoutIDs = semanticMatches
            }
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.workout.title)
                .fontWeight(.semibold)

            Text(SessionDateFormatter.shared.string(from: session.endedAt ?? session.startedAt))
                .foregroundStyle(.secondary)

            if let duration = sessionDurationText() {
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func sessionDurationText() -> String? {
        let seconds: Int
        if let durationSeconds = session.durationSeconds {
            seconds = durationSeconds
        } else if let endedAt = session.endedAt {
            seconds = Int(endedAt.timeIntervalSince(session.startedAt))
        } else {
            return nil
        }
        return "Duration \(formattedDuration(max(0, seconds)))"
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    var onStartAgain: (() -> Void)? = nil
    var onAdjustStart: (() -> Void)? = nil
    var onResume: (() -> Void)? = nil

    private var completedDate: Date {
        session.endedAt ?? session.startedAt
    }

    private var durationText: String {
        let seconds: Int
        if let durationSeconds = session.durationSeconds {
            seconds = durationSeconds
        } else if let endedAt = session.endedAt {
            seconds = Int(endedAt.timeIntervalSince(session.startedAt))
        } else {
            seconds = 0
        }
        return formattedDuration(max(0, seconds))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.workout.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(SessionDateFormatter.shared.string(from: completedDate))
                        .foregroundStyle(.secondary)
                }

                HighlightCard(
                    title: "Session Duration",
                    subtitle: durationText,
                    detail: "Total time captured"
                )

                if let onStartAgain {
                    Button {
                        onStartAgain()
                    } label: {
                        Text("Do Again")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                if let onResume {
                    Button {
                        onResume()
                    } label: {
                        Text("Resume")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                if let onAdjustStart {
                    Button {
                        onAdjustStart()
                    } label: {
                        Text("Adjust + Start")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercise Progress")
                        .font(.headline)

                    if session.logEntries.isEmpty {
                        Text("No exercise notes or sets recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.logEntries) { entry in
                            ExerciseProgressCard(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Detail")
    }
}

struct ExerciseProgressCard: View {
    let entry: ExerciseLog

    private var summaryText: String {
        let sets = entry.sets.count
        let totalReps = entry.sets.compactMap { $0.reps }.reduce(0, +)
        let volume = volumeSummary(entry.sets)
        var components: [String] = []
        components.append("\(sets) sets")
        if totalReps > 0 {
            components.append("\(totalReps) reps")
        }
        if let volume {
            components.append(volume)
        }
        return components.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .fontWeight(.semibold)
            Text(summaryText)
                .foregroundStyle(.secondary)
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func volumeSummary(_ sets: [ExerciseSet]) -> String? {
        let grouped = Dictionary(grouping: sets.compactMap { set -> (WeightUnit, Double)? in
            guard let weight = set.weight, let unit = set.weightUnit, let reps = set.reps else {
                return nil
            }
            return (unit, weight * Double(reps))
        }) { $0.0 }

        let parts = grouped.map { unit, values -> String in
            let total = values.map { $0.1 }.reduce(0, +)
            let formatted = String(format: "%.0f", total)
            let label = unit == .pounds ? "lb" : "kg"
            return "\(formatted) \(label)"
        }

        return parts.sorted().joined(separator: " · ").isEmpty ? nil : parts.sorted().joined(separator: " · ")
    }
}

struct SettingsMockView: View {
    @EnvironmentObject private var preferencesStore: UserPreferencesStore
    @StateObject private var networkMonitor = NetworkStatusMonitor()
    @State private var apiKeyInput = ""
    @State private var keySaveMessage: String?

    private var llmRuntimeState: LLMRuntimeState {
        preferencesStore.llmRuntimeState(isNetworkAvailable: networkMonitor.isNetworkAvailable)
    }

    private var llmStatusText: String {
        switch llmRuntimeState {
        case .disabled:
            return "Disabled"
        case .missingAPIKey:
            return "Missing API key"
        case .offline:
            return "Offline"
        case .ready:
            return "Ready"
        }
    }

    private var llmStatusColor: Color {
        switch llmRuntimeState {
        case .ready:
            return .green
        case .disabled:
            return .secondary
        case .missingAPIKey, .offline:
            return .orange
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Calendar Sync", isOn: $preferencesStore.preferences.calendarSyncEnabled)
                Toggle("HealthKit Sync", isOn: $preferencesStore.preferences.healthKitSyncEnabled)
            }

            Section(header: Text("LLM")) {
                Toggle("Enable LLM Assistance", isOn: $preferencesStore.preferences.llm.enabled)

                HStack {
                    Text("Provider")
                    Spacer()
                    Picker("Provider", selection: $preferencesStore.preferences.llm.provider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                }

                TextField("Model ID", text: $preferencesStore.preferences.llm.modelID)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Picker("Prompt Mode", selection: $preferencesStore.preferences.llm.promptDetailLevel) {
                    ForEach(LLMPromptDetailLevel.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                SecureField("API Key", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save API Key") {
                        if preferencesStore.saveLLMAPIKey(apiKeyInput) {
                            apiKeyInput = ""
                            keySaveMessage = "API key saved in Keychain."
                        } else {
                            keySaveMessage = "Unable to save API key."
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if preferencesStore.hasLLMAPIKey {
                        Button("Remove Key", role: .destructive) {
                            preferencesStore.clearLLMAPIKey()
                            keySaveMessage = "API key removed."
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let keySaveMessage {
                    Text(keySaveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(llmStatusText, systemImage: "bolt.horizontal.circle")
                    .foregroundStyle(llmStatusColor)

                if llmRuntimeState == .offline {
                    Text("Free-form generation is unavailable while offline. Rules/search discovery remains available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if llmRuntimeState == .missingAPIKey {
                    Text("Add an API key to enable free-form generation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("LLM Sharing")) {
                Toggle("Calendar Context", isOn: $preferencesStore.preferences.llm.shareCalendarContext)
                Toggle("History Summaries", isOn: $preferencesStore.preferences.llm.shareHistorySummaries)
                Toggle("Exercise Logs", isOn: $preferencesStore.preferences.llm.shareExerciseLogs)
                Toggle("User Notes", isOn: $preferencesStore.preferences.llm.shareUserNotes)
                Toggle("Templates & Variants", isOn: $preferencesStore.preferences.llm.shareTemplatesAndVariants)
                Text("Templates & Variants only controls local context sent to the LLM. It does not share workouts with other users.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Discovery")) {
                NavigationLink("Equipment Availability") {}
                NavigationLink("Workout Duration") {}
                NavigationLink("Focus Areas") {}

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.repeatPenalty,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Repeat Penalty: \(preferencesStore.preferences.discovery.recommendationWeights.repeatPenalty, specifier: "%.1f")")
                }

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.noveltyBoost,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Balance Boost: \(preferencesStore.preferences.discovery.recommendationWeights.noveltyBoost, specifier: "%.1f")")
                }

                Stepper(
                    value: $preferencesStore.preferences.discovery.recommendationWeights.focusPreferenceBoost,
                    in: 0...3,
                    step: 0.1
                ) {
                    Text("Focus Match Boost: \(preferencesStore.preferences.discovery.recommendationWeights.focusPreferenceBoost, specifier: "%.1f")")
                }
            }

            Section(header: Text("Account")) {
                NavigationLink("Export Data") {}
                NavigationLink("Privacy Settings") {}
            }
        }
        .navigationTitle("Settings")
    }
}

enum DebugLogLevel: String, Codable, Hashable {
    case info
    case warning
    case error
}

struct DebugLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: DebugLogLevel
    let category: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: DebugLogLevel,
        category: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

@MainActor
final class DebugLogStore: ObservableObject {
    @Published private(set) var entries: [DebugLogEntry] = []
    private let maxEntries = 500

    func log(_ level: DebugLogLevel, category: String, message: String) {
        let entry = DebugLogEntry(level: level, category: category, message: message)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    func clear() {
        entries.removeAll()
    }
}

struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var debugLogStore: DebugLogStore

    var body: some View {
        NavigationStack {
            List {
                if debugLogStore.entries.isEmpty {
                    Text("No debug logs yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(debugLogStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(entry.level.rawValue.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(levelColor(entry.level).opacity(0.15))
                                    .foregroundStyle(levelColor(entry.level))
                                    .cornerRadius(6)
                                Text(entry.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Self.timestampFormatter.string(from: entry.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        debugLogStore.clear()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func levelColor(_ level: DebugLogLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

@MainActor
final class NetworkStatusMonitor: ObservableObject {
    @Published private(set) var isNetworkAvailable: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.workoutapp.network-monitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

enum OpenAIFunctionCallingError: Error {
    case invalidResponse(String)
    case missingToolArguments(String)
    case invalidToolPayload(String)
    case validationFailed(String)
    case httpError(String)
}

extension OpenAIFunctionCallingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse(let detail):
            return "Invalid response from provider. \(detail)"
        case .missingToolArguments(let detail):
            return "Provider returned no function arguments. \(detail)"
        case .invalidToolPayload(let detail):
            return "Provider returned malformed tool payload. \(detail)"
        case .validationFailed(let detail):
            return "All generated candidates failed validation. \(detail)"
        case .httpError(let message):
            return message
        }
    }
}

actor OpenAIFunctionCallingService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")
    private let requestTimeoutSeconds: TimeInterval = 90
    private let retryOnTimeoutCount = 1

    func generateCandidates(
        query: String,
        contextWorkouts: [WorkoutDefinition],
        trigger: GenerationTrigger,
        count: Int,
        modelID: String,
        apiKey: String
    ) async throws -> [GeneratedCandidate] {
        let maxRounds = 2
        let maxRepairAttempts = 1
        let target = max(1, min(5, count))
        var candidates: [GeneratedCandidate] = []
        var usedTitles: Set<String> = []

        for index in 0..<target {
            let variationHint = "Variation \(index + 1) of \(target)"
            let generated = try await callTool(
                name: "generate_workout",
                description: "Generate a structured workout plan candidate.",
                schema: generateSchema(),
                payload: [
                    "query": query,
                    "trigger": trigger.rawValue,
                    "variationHint": variationHint,
                    "usedTitles": Array(usedTitles)
                ],
                modelID: modelID,
                apiKey: apiKey
            )

            let retrievedContext = retrieveContext(
                query: query,
                contextWorkouts: contextWorkouts,
                candidate: generated
            )

            var candidatePayload = generated
            var generationRound = 1
            for round in 1..<maxRounds {
                if let refined = try? await callTool(
                    name: "refine_workout",
                    description: "Refine a generated workout with retrieved context.",
                    schema: refineSchema(),
                    payload: [
                        "query": query,
                        "candidate": candidatePayload,
                        "context": retrievedContext,
                        "round": round + 1
                    ],
                    modelID: modelID,
                    apiKey: apiKey
                ) {
                    candidatePayload = refined
                    generationRound = round + 1
                }
            }

            var repairedPayload = candidatePayload
            var repairAttempts = 0
            while repairAttempts <= maxRepairAttempts {
                let validation = try await callTool(
                    name: "validate_workout",
                    description: "Validate a workout candidate against hard constraints.",
                    schema: validateSchema(),
                    payload: [
                        "candidate": repairedPayload
                    ],
                    modelID: modelID,
                    apiKey: apiKey
                )

                let isValid = (validation["isValid"] as? Bool) ?? false
                if isValid {
                    let built = try buildCandidate(
                        payload: repairedPayload,
                        query: query,
                        contextWorkouts: contextWorkouts,
                        generationRound: generationRound,
                        repairAttempts: repairAttempts
                    )
                    usedTitles.insert(built.title.lowercased())
                    candidates.append(built)
                    break
                }

                let issues = validation["issues"] as? [String] ?? []
                guard repairAttempts < maxRepairAttempts else {
                    break
                }
                if let repaired = try? await callTool(
                    name: "refine_workout",
                    description: "Repair a candidate to satisfy validation constraints.",
                    schema: refineSchema(),
                    payload: [
                        "query": query,
                        "candidate": repairedPayload,
                        "context": retrievedContext,
                        "repairIssues": issues
                    ],
                    modelID: modelID,
                    apiKey: apiKey
                ) {
                    repairedPayload = repaired
                }
                repairAttempts += 1
            }
        }

        if candidates.isEmpty {
            throw OpenAIFunctionCallingError.validationFailed("No valid candidates produced after generate/refine/validate loops.")
        }
        return candidates
    }

    private func buildCandidate(
        payload: [String: Any],
        query: String,
        contextWorkouts: [WorkoutDefinition],
        generationRound: Int,
        repairAttempts: Int
    ) throws -> GeneratedCandidate {
        let now = Date()
        let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            throw OpenAIFunctionCallingError.invalidToolPayload("Missing or empty title field in candidate payload.")
        }

        let summary = (payload["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Generated with LLM function-calling."
        let sections = parseSections(from: payload["sections"])
        guard !sections.isEmpty else {
            let keys = payload.keys.sorted().joined(separator: ",")
            throw OpenAIFunctionCallingError.invalidToolPayload("Missing/invalid sections field. Payload keys: [\(keys)]")
        }

        let markdown = renderMarkdown(title: title, sections: sections)
        let explanation = (payload["explanation"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Generated with function-calling and retrieval-aware refinement."

        return GeneratedCandidate(
            id: "gen-live-\(UUID().uuidString.prefix(8))",
            title: title,
            summary: summary,
            content: WorkoutContent(sourceMarkdown: markdown, parsedSections: sections, notes: nil),
            explanation: explanation,
            originQuery: query,
            isSaved: false,
            createdAt: now,
            provenance: GeneratedCandidateProvenance(
                originQuery: query,
                baseWorkoutID: contextWorkouts.first?.id,
                revisionPrompt: nil,
                revisionIndex: 0,
                contextWorkoutIDs: contextWorkouts.map(\.id),
                generationRound: generationRound,
                repairAttempts: repairAttempts,
                createdAt: now
            )
        )
    }

    private func callTool(
        name: String,
        description: String,
        schema: [String: Any],
        payload: [String: Any],
        modelID: String,
        apiKey: String
    ) async throws -> [String: Any] {
        guard let endpoint else {
            throw OpenAIFunctionCallingError.invalidResponse("Endpoint URL was not initialized.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payloadText = jsonString(payload) ?? "{}"
        let body: [String: Any] = [
            "model": modelID,
            "messages": [
                [
                    "role": "system",
                    "content": "Return tool call arguments only. Keep outputs concise and structured."
                ],
                [
                    "role": "user",
                    "content": payloadText
                ]
            ],
            "tools": [
                [
                    "type": "function",
                    "function": [
                        "name": name,
                        "description": description,
                        "parameters": schema
                    ]
                ]
            ],
            "tool_choice": [
                "type": "function",
                "function": [
                    "name": name
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await performRequestWithRetry(request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIFunctionCallingError.invalidResponse("Non-HTTP response for tool '\(name)'.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = parseAPIErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw OpenAIFunctionCallingError.httpError("Tool '\(name)' failed with \(message)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIFunctionCallingError.invalidResponse("Tool '\(name)' returned non-JSON body.")
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let toolCalls = message["tool_calls"] as? [[String: Any]],
            let firstTool = toolCalls.first,
            let function = firstTool["function"] as? [String: Any],
            let arguments = function["arguments"] as? String
        else {
            let snippet = truncatedJSONSnippet(from: json, limit: 350)
            throw OpenAIFunctionCallingError.missingToolArguments("Tool '\(name)' response lacked tool_calls/function.arguments. Snippet: \(snippet)")
        }

        if let argsJSON = parseJSONObject(from: arguments) {
            return argsJSON
        }

        if let recovered = extractJSONObjectString(from: arguments),
           let argsJSON = parseJSONObject(from: recovered) {
            return argsJSON
        }

        let argumentSnippet = truncate(arguments, limit: 350)
        throw OpenAIFunctionCallingError.invalidToolPayload("Tool '\(name)' arguments were not valid JSON object. Raw arguments: \(argumentSnippet)")
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            do {
                return try await URLSession.shared.data(for: request)
            } catch {
                if let urlError = error as? URLError,
                   urlError.code == .timedOut,
                   attempt < retryOnTimeoutCount {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }
                throw error
            }
        }
    }

    private func parseJSONObject(from text: String) -> [String: Any]? {
        guard
            let argsData = text.data(using: .utf8),
            let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
        else {
            return nil
        }
        return argsJSON
    }

    private func extractJSONObjectString(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        guard start <= end else {
            return nil
        }
        return String(text[start...end])
    }

    private func truncatedJSONSnippet(from json: [String: Any], limit: Int) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []),
              let text = String(data: data, encoding: .utf8) else {
            return "<unserializable>"
        }
        return truncate(text, limit: limit)
    }

    private func truncate(_ value: String, limit: Int) -> String {
        let singleLine = value.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > limit else {
            return singleLine
        }
        return String(singleLine.prefix(limit)) + "..."
    }

    private func retrieveContext(
        query: String,
        contextWorkouts: [WorkoutDefinition],
        candidate: [String: Any]
    ) -> [[String: Any]] {
        let queryTerms = Set(query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
        let candidateTitle = (candidate["title"] as? String)?.lowercased() ?? ""

        return contextWorkouts
            .map { workout -> (WorkoutDefinition, Int) in
                let haystack = "\(workout.title.lowercased()) \(workout.summary?.lowercased() ?? "")"
                let sharedTerms = queryTerms.filter { haystack.contains($0) }.count
                let candidateBoost = candidateTitle.isEmpty ? 0 : (haystack.contains(candidateTitle) ? 1 : 0)
                return (workout, sharedTerms + candidateBoost)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { pair in
                [
                    "id": pair.0.id,
                    "title": pair.0.title,
                    "summary": pair.0.summary ?? "",
                    "focusTags": pair.0.metadata.focusTags
                ]
            }
    }

    private func parseSections(from value: Any?) -> [WorkoutSection] {
        guard let rows = value as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { section in
            guard let title = section["title"] as? String else {
                return nil
            }
            let detail = section["detail"] as? String
            let items = (section["items"] as? [[String: Any]] ?? []).compactMap { item -> WorkoutItem? in
                guard let name = item["name"] as? String else {
                    return nil
                }
                return WorkoutItem(
                    name: name,
                    prescription: item["prescription"] as? String,
                    notes: item["notes"] as? String
                )
            }
            return WorkoutSection(title: title, detail: detail, items: items)
        }
    }

    private func renderMarkdown(title: String, sections: [WorkoutSection]) -> String {
        var lines = ["# \(title)"]
        for section in sections {
            lines.append("## \(section.title)")
            if let detail = section.detail, !detail.isEmpty {
                lines.append(detail)
            }
            for item in section.items {
                if let prescription = item.prescription, !prescription.isEmpty {
                    lines.append("- \(item.name) — \(prescription)")
                } else {
                    lines.append("- \(item.name)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func parseAPIErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }

    private func generateSchema() -> [String: Any] {
        [
            "type": "object",
            "required": ["title", "summary", "sections", "explanation"],
            "properties": [
                "title": ["type": "string"],
                "summary": ["type": "string"],
                "explanation": ["type": "string"],
                "sections": [
                    "type": "array",
                    "items": sectionSchema()
                ]
            ]
        ]
    }

    private func refineSchema() -> [String: Any] {
        generateSchema()
    }

    private func validateSchema() -> [String: Any] {
        [
            "type": "object",
            "required": ["isValid", "issues"],
            "properties": [
                "isValid": ["type": "boolean"],
                "issues": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ]
        ]
    }

    private func sectionSchema() -> [String: Any] {
        [
            "type": "object",
            "required": ["title", "items"],
            "properties": [
                "title": ["type": "string"],
                "detail": ["type": "string"],
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "required": ["name"],
                        "properties": [
                            "name": ["type": "string"],
                            "prescription": ["type": "string"],
                            "notes": ["type": "string"]
                        ]
                    ]
                ]
            ]
        ]
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutDefinition
    let recommendation: RankedWorkout?
    var isNew: Bool = false

    private var sectionTitles: [String] {
        workout.content.parsedSections?.prefix(2).map { $0.title } ?? []
    }

    private var sectionSummary: String {
        if sectionTitles.isEmpty {
            return "Knowledge base workout"
        }
        return sectionTitles.joined(separator: " / ")
    }

    private var sectionCount: Int {
        workout.content.parsedSections?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(sectionSummary)
                .foregroundStyle(.secondary)

            if let recommendation {
                Text(recommendation.primaryReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                MockChip(title: "\(sectionCount) sections")
                MockChip(title: sourceLabel(for: workout.source))
                if isNew || workout.source == .generated {
                    MockChip(title: "New")
                }
                if let recommendation {
                    MockChip(title: "Score \(String(format: "%.2f", recommendation.score))")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func sourceLabel(for source: WorkoutSource) -> String {
        switch source {
        case .knowledgeBase:
            return "Knowledge base"
        case .template:
            return "Template"
        case .variant:
            return "Variant"
        case .external:
            return "External"
        case .generated:
            return "Generated"
        }
    }
}

struct WorkoutSectionCard: View {
    let section: WorkoutSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .fontWeight(.semibold)

            if let detail = section.detail, !detail.isEmpty {
                Text(detail)
                    .foregroundStyle(.secondary)
            }

            ForEach(section.items) { item in
                WorkoutSectionItemRow(item: item)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutSectionItemRow: View {
    let item: WorkoutItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("-")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.semibold)

                if let prescription = item.prescription, !prescription.isEmpty {
                    Text(prescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct WorkoutBlockMock: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct HighlightCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct MockChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(999)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }
}

struct HistoryStat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LogRowMock: View {
    let exercise: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Edit")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

final class SessionDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private func formattedDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview {
    ContentView()
        .environmentObject(UserPreferencesStore())
}
