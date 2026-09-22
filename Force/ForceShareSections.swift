import SwiftUI
import PhotosUI

/// Screenshot used when the magician performs on their own phone.
struct ForcePhonePerformanceSection: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let backgroundImage: UIImage?
    let onDelete: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Text("Take a screenshot of your phone app screen and add it below to use as a background image when in performance mode on your own phone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                photoWell
            }
            .padding(.vertical, 8)
        } header: {
            Text("Perform on Your Phone")
        }
    }

    @ViewBuilder
    private var photoWell: some View {
        if let backgroundImage {
            Image(uiImage: backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 195)
                .clipped()
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: 8, y: -8)
                }
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 195)
                    .overlay(Image(systemName: "plus").font(.title).foregroundColor(.gray))
            }
        }
    }
}

struct ForceQRCodeButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "qrcode")
                    .foregroundColor(tint)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text("QR Code & NFC")
                        .font(.headline)
                    Text("Generate QR code or write to NFC sticker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
