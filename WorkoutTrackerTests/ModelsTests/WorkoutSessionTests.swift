import XCTest
import SwiftData
@testable import WorkoutTracker

final class WorkoutSessionTests: XCTestCase {
    @MainActor
    func test_session_cascade_deletes_sets() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "スクワット", category: .legs)
        let session = WorkoutSession()
        let set = SetRecord(exercise: ex, session: session, weightKg: 100, reps: 5)
        ctx.insert(ex)
        ctx.insert(session)
        ctx.insert(set)
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SetRecord>()).count, 1)
        ctx.delete(session)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SetRecord>()).count, 0)
    }

    @MainActor
    func test_template_cascade_deletes_template_exercises() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "デッドリフト", category: .back)
        let tpl = WorkoutTemplate(name: "背中の日")
        let te = TemplateExercise(exercise: ex, targetSets: 3, targetReps: 5)
        te.template = tpl
        ctx.insert(ex); ctx.insert(tpl); ctx.insert(te)
        try ctx.save()

        ctx.delete(tpl)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<TemplateExercise>()).count, 0)
    }
}
