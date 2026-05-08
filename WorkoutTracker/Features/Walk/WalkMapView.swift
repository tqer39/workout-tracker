import SwiftUI

struct WalkMapView: View {
    let route: [Checkpoint]
    let progress: JourneyProgress

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image("JapanMap")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.05))

                ForEach(route) { cp in
                    pin(for: cp)
                        .position(
                            x: cp.mapPosition.x * geo.size.width,
                            y: cp.mapPosition.y * geo.size.height
                        )
                }
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }

    @ViewBuilder
    private func pin(for cp: Checkpoint) -> some View {
        let isPassed = (progress.lastPassedCheckpoint?.cumulativeKm ?? -1) >= cp.cumulativeKm
        let isCurrent = progress.lastPassedCheckpoint?.id == cp.id && !progress.isCompleted
        ZStack {
            Circle()
                .fill(isPassed ? Color.orange : Color.secondary.opacity(0.4))
                .frame(width: isCurrent ? 18 : 12, height: isCurrent ? 18 : 12)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: isPassed ? 2 : 0)
                .scaleEffect(isCurrent ? 1.2 : 1.0)
                .animation(
                    isCurrent
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isCurrent
                )
            Text(cp.name)
                .font(.caption2)
                .padding(.horizontal, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .offset(y: 14)
        }
    }
}

#Preview {
    WalkMapView(
        route: JourneyRoute.tokyoToHakata,
        progress: JourneyEngine.computeProgress(
            totalSteps: 200_000,
            route: JourneyRoute.tokyoToHakata
        )
    )
    .padding()
}
