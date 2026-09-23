import SwiftUI
import PhotosUI
import ForceShared

/// Launch choice and screenshot used when the magician performs on their own phone.
struct ForcePhonePage: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let backgroundImage: UIImage?
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Open to Calculator", isOn: $settings.openToCalculator)
                screenshotToggle
                HStack(alignment: .top, spacing: 12) {
                    Text("Take a screenshot of your phone app screen and add it below to use as a background image when in performance mode on your own phone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    photoWell
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Perform on Your Phone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var screenshotToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Start with Screenshot", isOn: $settings.startWithScreenshot)
            Text("App starts showing screenshot, tap anywhere to open calculator")
                .font(.caption)
                .foregroundColor(.secondary)
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

