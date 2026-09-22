import SwiftUI
import UIKit

class ImageStorageManager {
    static let shared = ImageStorageManager()
    private let fileName = "backgroundImage.jpg"
    private let userDefaultsKey = "backgroundImage" // Legacy key
    
    private init() {}
    
    // MARK: - File System Paths
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var fileURL: URL {
        documentsDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Public API
    
    func saveImage(_ image: UIImage) {
        // Compress image to reasonable size
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            debugLog("❌ ImageStorageManager: Failed to convert image to JPEG data")
            return
        }
        
        do {
            try data.write(to: fileURL)
            debugLog("✅ ImageStorageManager: Image saved to \(fileURL.path)")
        } catch {
            debugLog("❌ ImageStorageManager: Failed to save image: \(error.localizedDescription)")
        }
    }
    
    /// True when a stored image exists, without paying for decoding it.
    func hasImage() -> Bool {
        migrateIfNeeded()
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func loadImage() -> UIImage? {
        // Check migration first
        migrateIfNeeded()
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                return UIImage(data: data)
            } catch {
                debugLog("❌ ImageStorageManager: Failed to load image data: \(error.localizedDescription)")
                return nil
            }
        }
        return nil
    }
    
    func deleteImage() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                debugLog("✅ ImageStorageManager: Image deleted")
            } catch {
                debugLog("❌ ImageStorageManager: Failed to delete image: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Migration
    
    private func migrateIfNeeded() {
        // Check if we have an image in UserDefaults but NOT in file system
        if UserDefaults.standard.object(forKey: userDefaultsKey) != nil {
            debugLog("🔄 ImageStorageManager: Legacy image found in UserDefaults, migrating...")
            
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let image = UIImage(data: data) {
                
                // Save to file system
                saveImage(image)
                
                // Remove from UserDefaults
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                debugLog("✅ ImageStorageManager: Migration complete. Removed from UserDefaults.")
            } else {
                debugLog("❌ ImageStorageManager: Failed to retrieve legacy image data.")
            }
        }
    }
}

