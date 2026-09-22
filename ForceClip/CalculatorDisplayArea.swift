import SwiftUI
import ForceShared

/// Clip readout. There is no menu; a long-press on equals peeks the force number.
struct CalculatorDisplayArea: View {
    let display: String
    let geometry: GeometryProxy
    let showForceNumber: Bool
    let forceNumber: Int

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if showForceNumber {
                    Text("\(forceNumber)")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray.opacity(0.7))
                        .padding(.trailing, 24)
                        .padding(.top, 20)
                }
            }
            Spacer()
            HStack {
                Spacer()
                Text(display)
                    .font(.system(size: min(geometry.size.width * 0.2, 80), weight: .thin))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.bottom, 30)
        }
        .frame(height: geometry.size.height * 0.35)
    }
}
