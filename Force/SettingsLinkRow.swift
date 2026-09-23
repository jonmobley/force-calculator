import SwiftUI

/// One row in the performer home list: a coloured icon, a title, and an optional
/// current value. The enclosing `NavigationLink` supplies the trailing chevron.
struct SettingsLinkRow: View {
    let title: String
    let systemImage: String
    let color: Color
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            icon
            Text(title)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Pages reachable from the performer home list.
enum ForceSettingsPage: Hashable {
    case force
    case perfectPlus
    case livePeek
    case phone
    case share
    case appearance
    case sync
}
