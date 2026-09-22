import SwiftUI
import ForceShared

/// Fills the screen with the spectator's number so the performer can read it from
/// across a room. Updates live as the spectator types. Tap anywhere to close.
struct PeekStageView: View {
    @ObservedObject var reader: ForcePeekReader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        // The cover may have stopped the reader when it hid the main screen; make
        // sure polling is running so the number keeps updating here.
        .onAppear { reader.start() }
        .statusBarHidden()
    }

    @ViewBuilder
    private var content: some View {
        switch reader.state {
        case .value(let peek):
            Text(peek.value)
                .font(.system(size: 500, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.05)
                .lineLimit(1)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
        case .waiting, .idle:
            Text("Waiting…")
                .font(.title)
                .foregroundColor(.secondary)
        case .missingToken:
            Text("Add your write token in Sync")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}
