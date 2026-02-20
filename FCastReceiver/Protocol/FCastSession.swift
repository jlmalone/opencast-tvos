import Foundation
import Network

// MARK: - Delegate

protocol FCastSessionDelegate: AnyObject {
    func session(_ session: FCastSession, didReceive opcode: Opcode, data: Data?)
    func sessionDidDisconnect(_ session: FCastSession)
}

// MARK: - FCastSession

/// Handles a single TCP connection: binary frame parsing and sending.
/// Frame format: [4 bytes: uint32 LE length][1 byte: opcode][N bytes: UTF-8 JSON body]
/// `length` = 1 (opcode) + body_length. No body for opcode-only messages.
class FCastSession {

    private enum ParseState {
        case waitingForLength
        case waitingForData(Int)
    }

    let connection: NWConnection
    weak var delegate: FCastSessionDelegate?
    private var buffer = Data()
    private var parseState = ParseState.waitingForLength

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.start(queue: .global(qos: .userInitiated))
        receiveLoop()
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            if isComplete || error != nil {
                self.delegate?.sessionDidDisconnect(self)
                return
            }
            self.receiveLoop()
        }
    }

    private func processBuffer() {
        while true {
            switch parseState {
            case .waitingForLength:
                guard buffer.count >= 4 else { return }
                // Use startIndex-relative access because Data.removeFirst() advances
                // startIndex without resetting it to 0, so buffer[0] would crash.
                let s = buffer.startIndex
                let length = Int(buffer[s])
                    | (Int(buffer[s + 1]) << 8)
                    | (Int(buffer[s + 2]) << 16)
                    | (Int(buffer[s + 3]) << 24)
                guard length > 0 && length <= 32768 else {
                    delegate?.sessionDidDisconnect(self)
                    return
                }
                // Data(dropFirst) creates a fresh Data with startIndex = 0
                buffer = Data(buffer.dropFirst(4))
                parseState = .waitingForData(length)

            case .waitingForData(let length):
                guard buffer.count >= length else { return }
                // Data(prefix) creates a new Data with startIndex = 0, so packetData[0] is safe
                let packetData = Data(buffer.prefix(length))
                buffer = Data(buffer.dropFirst(length))
                parseState = .waitingForLength

                guard let opcode = Opcode(rawValue: packetData[0]) else {
                    print("[FCastSession] Unknown opcode \(packetData[0]), skipping")
                    continue
                }
                let body = length > 1 ? Data(packetData.dropFirst()) : nil
                if let body, let str = String(data: body, encoding: .utf8) {
                    print("[FCastSession] RX opcode=\(opcode)(\(opcode.rawValue)) body=\(str)")
                } else {
                    print("[FCastSession] RX opcode=\(opcode)(\(opcode.rawValue)) no-body")
                }
                delegate?.session(self, didReceive: opcode, data: body)
            }
        }
    }

    /// Send a framed FCast message. Pass nil for opcodes with no payload (Pause, Resume, Stop, Ping, Pong).
    func send(_ opcode: Opcode, _ value: (any Encodable)? = nil) {
        var body = Data()
        if let value {
            guard let json = try? JSONEncoder().encode(value) else { return }
            body = json
        }
        let length = UInt32(1 + body.count)
        var frame = Data(capacity: 4 + 1 + body.count)
        frame.append(UInt8(length & 0xFF))
        frame.append(UInt8((length >> 8) & 0xFF))
        frame.append(UInt8((length >> 16) & 0xFF))
        frame.append(UInt8((length >> 24) & 0xFF))
        frame.append(opcode.rawValue)
        frame.append(body)
        connection.send(content: frame, completion: .contentProcessed({ _ in }))
    }

    func cancel() {
        connection.cancel()
    }
}
