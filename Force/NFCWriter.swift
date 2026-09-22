import Foundation
import CoreNFC

/// Writes the App Clip URL to a tag. The owner must retain this object for the session.
class NFCWriter: NSObject, NFCNDEFReaderSessionDelegate {
    private let url: String
    private let completion: (String) -> Void
    private var finished = false
    private var session: NFCNDEFReaderSession?

    init(url: String, completion: @escaping (String) -> Void) {
        self.url = url
        self.completion = completion
    }

    func start() {
        guard NFCNDEFReaderSession.readingAvailable else {
            finish("NFC is not available on this device")
            return
        }
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "Hold your iPhone near an NFC sticker to write the App Clip link"
        self.session = session
        session.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        guard let nfcError = error as? NFCReaderError else {
            finish("NFC error: \(error.localizedDescription)")
            return
        }
        switch nfcError.code {
        case .readerSessionInvalidationErrorUserCanceled:
            finish("NFC writing cancelled")
        case .readerSessionInvalidationErrorSessionTimeout:
            finish("NFC session timed out")
        case .readerSessionInvalidationErrorFirstNDEFTagRead:
            finish("App Clip link successfully written to NFC sticker!")
        default:
            finish("NFC error: \(error.localizedDescription)")
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag detected")
            return
        }
        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: "Failed to connect to NFC tag: \(error.localizedDescription)")
                return
            }
            self.writeURL(to: tag, session: session)
        }
    }

    private func writeURL(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { status, _, error in
            if let error {
                session.invalidate(errorMessage: "Failed to query NFC tag: \(error.localizedDescription)")
                return
            }
            guard status == .readWrite else {
                session.invalidate(errorMessage: self.statusMessage(status))
                return
            }
            self.writeMessage(to: tag, session: session)
        }
    }

    private func writeMessage(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: url)!) else {
            session.invalidate(errorMessage: "Failed to create URL payload")
            return
        }
        tag.writeNDEF(NFCNDEFMessage(records: [payload])) { error in
            if let error {
                session.invalidate(errorMessage: "Failed to write to NFC tag: \(error.localizedDescription)")
                return
            }
            session.alertMessage = "Successfully wrote App Clip link to NFC sticker!"
            self.finish("App Clip link successfully written to NFC sticker!")
            session.invalidate()
        }
    }

    private func statusMessage(_ status: NFCNDEFStatus) -> String {
        switch status {
        case .notSupported: return "NFC tag is not supported"
        case .readOnly: return "NFC tag is read-only"
        default: return "Unknown NFC tag status"
        }
    }

    private func finish(_ message: String) {
        guard !finished else { return }
        finished = true
        session = nil
        DispatchQueue.main.async {
            self.completion(message)
        }
    }
}
