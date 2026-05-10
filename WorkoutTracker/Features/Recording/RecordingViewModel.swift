import Foundation
import Observation
import SwiftData

@Observable
final class RecordingViewModel {
    var session: WorkoutSession?
    let restTimer = RestTimer()
    private var ctx: ModelContext?

    func bind(context: ModelContext) {
        self.ctx = context
    }

    func startEmptySession() {
        guard let ctx else { return }
        let s = WorkoutSession(startedAt: Date())
        ctx.insert(s)
        try? ctx.save()
        session = s
    }

    func startSession(from template: WorkoutTemplate) {
        guard let ctx else { return }
        let s = WorkoutSession(startedAt: Date(), templateRef: template)
        ctx.insert(s)
        try? ctx.save()
        session = s
    }

    func addSet(exercise: Exercise, weightKg: Double, reps: Int, rpe: Double?) {
        guard let ctx, let session else { return }
        let set = SetRecord(
            exercise: exercise,
            session: session,
            weightKg: weightKg,
            reps: reps,
            rpe: rpe,
            performedAt: Date(),
            restSeconds: exercise.defaultRestSeconds
        )
        ctx.insert(set)
        try? ctx.save()

        restTimer.start(duration: exercise.defaultRestSeconds)
        if let sid = session.id as UUID? {
            Task {
                await NotificationService.shared.scheduleRestEnd(
                    after: exercise.defaultRestSeconds,
                    identifier: "rest-\(sid.uuidString)"
                )
            }
        }
    }

    func endSession() {
        guard let ctx, let session else { return }

        restTimer.cancel()
        NotificationService.shared.cancel(identifier: "rest-\(session.id.uuidString)")

        if session.sets.isEmpty {
            ctx.delete(session)
        } else {
            session.endedAt = Date()
        }
        try? ctx.save()
        self.session = nil
    }

    func deleteSet(_ set: SetRecord) {
        guard let ctx else { return }
        ctx.delete(set)
        try? ctx.save()
    }
}
