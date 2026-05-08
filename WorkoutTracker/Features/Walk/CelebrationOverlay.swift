import SwiftUI
import AVFoundation
import UIKit

struct CelebrationOverlay: View {
    let achievement: CheckpointAchievement
    let checkpoint: Checkpoint
    let onDismiss: () -> Void

    @AppStorage("walk.celebrationConfettiEnabled") private var confettiEnabled: Bool = true
    @AppStorage("walk.celebrationSoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("walk.celebrationHapticEnabled") private var hapticEnabled: Bool = true

    @State private var confettiTrigger: Int = 0
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🎉 \(checkpoint.name) に到着！")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(checkpoint.blurb)
                        .font(.body)
                    Divider()
                    HStack {
                        Label("\(achievement.totalStepsAtAchievement) 歩", systemImage: "figure.walk")
                        Spacer()
                        Text(achievement.achievedAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Label("バッジ獲得", systemImage: "rosette")
                    .font(.headline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.yellow.opacity(0.6), in: Capsule())

                Button("OK") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding()

            if confettiEnabled {
                ConfettiView(trigger: confettiTrigger).allowsHitTesting(false)
            }
        }
        .onAppear {
            if hapticEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if soundEnabled { playSound() }
            confettiTrigger += 1
        }
        .onTapGesture { onDismiss() }
    }

    private func playSound() {
        AudioServicesPlaySystemSound(1025)
    }
}

struct ConfettiView: View {
    var trigger: Int
    @State private var particles: [Particle] = []

    var body: some View {
        Canvas { ctx, size in
            for p in particles {
                let rect = CGRect(x: p.x, y: p.y, width: 8, height: 4)
                ctx.fill(Path(rect), with: .color(p.color))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: trigger) { _, _ in spawn() }
        .onAppear { spawn() }
    }

    private func spawn() {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .pink, .purple]
        particles = (0..<60).map { _ in
            Particle(x: .random(in: 0...400), y: -20,
                     color: palette.randomElement() ?? .yellow,
                     vy: .random(in: 200...600),
                     vx: .random(in: -80...80))
        }
        Task { @MainActor in
            let start = Date()
            while Date().timeIntervalSince(start) < 2.5 {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let dt: Double = 0.016
                particles = particles.map { p in
                    var n = p
                    n.x += p.vx * dt
                    n.y += p.vy * dt
                    return n
                }
            }
            particles = []
        }
    }

    struct Particle {
        var x: Double
        var y: Double
        let color: Color
        let vy: Double
        let vx: Double
    }
}

#Preview {
    CelebrationOverlay(
        achievement: CheckpointAchievement(
            checkpointId: "yokohama",
            achievedAt: Date(),
            totalStepsAtAchievement: 30_000
        ),
        checkpoint: JourneyRoute.tokyoToHakata[1],
        onDismiss: {}
    )
}
