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
