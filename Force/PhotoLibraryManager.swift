import UIKit
import Photos

struct PhotoLibraryManager {
    static func saveImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        debugLog("💾 Attempting to save QR code to Photos")
        
        // Check photo library authorization status
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            performSave(image, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSave(image, completion: completion)
                    } else {
                        completion(.failure(NSError(domain: "PhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied. Please enable it in Settings."])))
                        debugLog("❌ Photo library access denied")
                    }
                }
            }
        case .denied, .restricted:
            completion(.failure(NSError(domain: "PhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied. Please enable it in Settings > Force > Photos."])))
            debugLog("❌ Photo library access denied or restricted")
        @unknown default:
            completion(.failure(NSError(domain: "PhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to access photo library"])))
            debugLog("❌ Unknown photo library status")
        }
    }
    
    private static func performSave(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success("QR code saved to Photos!"))
                    debugLog("✅ QR code saved successfully")
                } else {
                    completion(.failure(error ?? NSError(domain: "PhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save QR code: Unknown error"])))
                    debugLog("❌ Failed to save QR code: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}
