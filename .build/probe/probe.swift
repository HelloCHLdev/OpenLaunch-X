import SwiftUI

struct Probe: View {
    var body: some View {
        VStack {
            Text("x").background(.ultraThinMaterial)
            Text("y").containerBackground(.clear, for: .window)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
