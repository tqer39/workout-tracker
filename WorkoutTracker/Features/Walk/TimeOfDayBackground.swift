import SwiftUI

struct TimeOfDayBackground: View {
    let timeOfDay: TimeOfDay

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .top)
    }

    private var colors: [Color] {
        switch timeOfDay {
        case .morning: return [Color(red: 1.00, green: 0.85, blue: 0.65),
                               Color(red: 1.00, green: 0.95, blue: 0.85)]
        case .day:     return [Color(red: 0.65, green: 0.85, blue: 1.00),
                               Color(red: 0.90, green: 0.97, blue: 1.00)]
        case .evening: return [Color(red: 1.00, green: 0.55, blue: 0.40),
                               Color(red: 0.95, green: 0.75, blue: 0.55)]
        case .night:   return [Color(red: 0.10, green: 0.15, blue: 0.40),
                               Color(red: 0.20, green: 0.25, blue: 0.55)]
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(TimeOfDay.allCases, id: \.self) { tod in
            TimeOfDayBackground(timeOfDay: tod)
                .frame(height: 100)
                .overlay(Text(tod.rawValue).foregroundStyle(.white))
        }
    }
}
