import SwiftUI
import ForceShared

/// Fills the screen with the spectator's number so the performer can read it from
/// across a room. Updates live as the spectator types. Tap anywhere to close.
///
/// The number is rotated a quarter turn so it runs along the phone's long edge:
/// the app is locked to portrait, so laying the digits out sideways and asking the
/// performer to turn the phone gives far larger characters than an upright layout
/// ever could.
struct PeekStageView: View {
    @ObservedObject var reader: ForcePeekReader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                content
                    // Lay out in the swapped bounds, then rotate to fit the screen,
                    // so the text fills the long edge rather than the short one.
                    .frame(width: geometry.size.height, height: geometry.size.width)
                    .rotationEffect(.degrees(90))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
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
            // Only the number on the spectator's screen right now. The steps that led to
            // it are on the settings screen; this view exists to be read across a room,
            // and anything more than one number defeats that.
            Text(peek.latest?.value ?? "")
                .font(.system(size: 800, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.02)
                .lineLimit(1)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
        case .waiting, .idle:
            Text("Waiting…")
                .font(.title)
                .foregroundColor(.secondary)
        case .notAuthorized:
            Text("This phone cannot read peeks for that code")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}
