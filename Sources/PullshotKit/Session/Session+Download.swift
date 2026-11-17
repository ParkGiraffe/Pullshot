import Foundation

public extension Session {
    func thumbnail(_ handle: UInt32) throws -> Data {
        try transact(.getThumb, [handle]).data
    }

    func download(
        _ handle: UInt32,
        expectedSize: UInt64?,
        to destination: URL,
        progress: (UInt64) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) throws {
        let fileManager = FileManager.default
        let name = destination.lastPathComponent
        guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) else {
            throw SessionError.destinationExists(name)
        }
        guard !isCancelled() else { throw SessionError.cancelled }
        let partial = destination.deletingLastPathComponent().appending(path: ".\(name).pullshot-partial")
        try Data().write(to: partial)
        var isSaved = false
        defer {
            if !isSaved {
                try? fileManager.removeItem(at: partial)
            }
        }

        let file = try FileHandle(forWritingTo: partial)
        let reply = try receiveObject(handle, into: file, progress: progress, isCancelled: isCancelled)
        try file.close()
        guard !reply.isCancelled else { throw SessionError.cancelled }
        guard reply.response.code == PTP.Response.ok.rawValue else {
            throw SessionError.response(PTP.Response(rawValue: reply.response.code), operation: .getObject)
        }
        if let expectedSize, reply.bytes != expectedSize {
            throw SessionError.sizeMismatch(expected: expectedSize, actual: reply.bytes)
        }
        do {
            try fileManager.moveItem(at: partial, to: destination)
        } catch CocoaError.fileWriteFileExists {
            throw SessionError.destinationExists(name)
        }
        isSaved = true
    }

    private func receiveObject(
        _ handle: UInt32,
        into file: FileHandle,
        progress: (UInt64) -> Void,
        isCancelled: () -> Bool
    ) throws -> (bytes: UInt64, response: Container, isCancelled: Bool) {
        try invalidatingOnFailure {
            let id = takeTransactionID()
            try send(.command(.getObject, transactionID: id, parameters: [handle]))
            let header = try awaitHeader()
            try requireTransaction(id, header.transactionID)
            guard header.kind == .data else {
                return try (0, nextContainer(timeout: Self.commandReadTimeout), false)
            }
            _ = buffer.removeFirst(upTo: ContainerHeader.size)
            var remaining = Int(header.length) - ContainerHeader.size
            var written: UInt64 = 0
            var cancelled = false
            while remaining > 0 {
                guard !buffer.isEmpty else {
                    try fill(timeout: Self.dataReadTimeout)
                    continue
                }
                cancelled = cancelled || isCancelled()
                let piece = buffer.removeFirst(upTo: remaining)
                remaining -= piece.count
                guard !cancelled else { continue }
                try file.write(contentsOf: piece)
                written += UInt64(piece.count)
                progress(written)
            }
            let response = try nextContainer(timeout: Self.commandReadTimeout)
            guard response.kind == .response else { throw unexpected(response) }
            try requireTransaction(id, response.transactionID)
            return (written, response, cancelled)
        }
    }

    private func awaitHeader() throws -> ContainerHeader {
        var strayEvents = 0
        while true {
            guard let header = try buffer.peekHeader() else {
                try fill(timeout: Self.dataReadTimeout)
                continue
            }
            guard header.kind == .event else { return header }
            strayEvents += 1
            let event = try nextContainer(timeout: Self.commandReadTimeout)
            guard strayEvents <= Self.maxStrayEvents else { throw unexpected(event) }
        }
    }
}
