import SwiftUI

struct CompanionBubble: View {
    let line: String
    let mood: Mood

    enum Mood { case neutral, cheer, celebrate }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())

            Text(line)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var symbolName: String {
        switch mood {
        case .neutral:   return "figure.walk"
        case .cheer:     return "figure.walk.motion"
        case .celebrate: return "party.popper"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CompanionBubble(line: "おはよう。あと 3,200 歩で目標。", mood: .neutral)
        CompanionBubble(line: "目標達成！えらい！", mood: .celebrate)
    }
    .padding()
}
