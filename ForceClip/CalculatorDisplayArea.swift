import SwiftUI

// MARK: - Display Area

struct CalculatorDisplayArea: View {
    let display: String
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            // Menu icon in top left
            HStack {
                Button(action: { /* Menu action */ }) {
                    Image("icon-menu")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "ff9f0a"))
                }
                .padding(.leading, 24)
                .padding(.top, 20)
                Spacer()
            }
            
            Spacer()
            HStack {
                Spacer()
                Text(display)
                    .font(.custom("SF Pro Display", size: min(geometry.size.width * 0.2, 80)))
                    .fontWeight(.thin)
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
