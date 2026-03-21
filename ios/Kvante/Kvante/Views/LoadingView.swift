import SwiftUI
import Combine

struct LoadingView: View {
    let message: String
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            // Friendly animated icon
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)

            Text(message + String(repeating: ".", count: dotCount))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .onReceive(timer) { _ in
                    dotCount = (dotCount + 1) % 4
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    LoadingView(message: "Kvante kigger på din side")
}
