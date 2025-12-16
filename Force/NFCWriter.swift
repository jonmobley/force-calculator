import Foundation
import CoreNFC

class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    private let url: String
    private let completion: (String) -> Void
    
    init(url: String, completion: @escaping (String) -> Void) {
        self.url = url
        self.completion = completion
    }
    
    func writeToNFC() -> NFCNDEFReaderSession? {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion("NFC is not available on this device")
            return nil
        }
        
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Hold your iPhone near an NFC sticker to write the App Clip link"
        session.begin()
        return session
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                completion("NFC writing cancelled")
            case .readerSessionInvalidationErrorSessionTimeout:
                completion("NFC session timed out")
            default:
                completion("NFC error: \(error.localizedDescription)")
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // This method is called when reading, but we want to write
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to connect to NFC tag: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: "Failed to query NFC tag: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "NFC tag is not supported")
                case .readOnly:
                    session.invalidate(errorMessage: "NFC tag is read-only")
                case .readWrite:
                    // Create NDEF message with URL
                    guard let urlPayload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: self.url)!) else {
                        session.invalidate(errorMessage: "Failed to create URL payload")
                        return
                    }
                    
                    let message = NFCNDEFMessage(records: [urlPayload])
                    
                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Failed to write to NFC tag: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Successfully wrote App Clip link to NFC sticker!"
                            session.invalidate()
                            self.completion("App Clip link successfully written to NFC sticker!")
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown NFC tag status")
                }
            }
        }
    }
}
