import Foundation

public extension Session {
    func thumbnail(_ handle: UInt32) throws -> Data {
        try transact(.getThumb, [handle]).data
    }

    /// 원본을 받아 `destination`에 바이트 그대로 저장합니다. 이미 있는 파일은 덮어쓰지 않습니다.
    /// 같은 폴더의 임시 파일에 흘려 쓰고 다 받은 뒤에 이름을 바꾸므로, 실패나 취소 뒤에는 아무 파일도 남지 않습니다.
    /// 취소하면 데이터 단계를 버리게 되어 이 세션은 더 쓸 수 없습니다.
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
        let partial = destination.deletingLastPathComponent().appending(path: ".\(name).pullshot-partial")
        try Data().write(to: partial)
        var isSaved = false
        defer {
            if !isSaved {
                try? fileManager.removeItem(at: partial)
            }
        }

        let file = try FileHandle(forWritingTo: partial)
        let received = try receiveObject(handle, into: file, progress: progress, isCancelled: isCancelled)
        try file.close()
        guard received.response.code == PTP.Response.ok.rawValue else {
            throw SessionError.response(PTP.Response(rawValue: received.response.code), operation: .getObject)
        }
        if let expectedSize, received.bytes != expectedSize {
            throw SessionError.sizeMismatch(expected: expectedSize, actual: received.bytes)
        }
        do {
            try fileManager.moveItem(at: partial, to: destination)
        } catch CocoaError.fileWriteFileExists {
            throw SessionError.destinationExists(name)
        }
        isSaved = true
    }

    /// GetObject의 데이터 단계를 파일에 흘려 쓰고 응답까지 받습니다.
    private func receiveObject(
        _ handle: UInt32,
        into file: FileHandle,
        progress: (UInt64) -> Void,
        isCancelled: () -> Bool
    ) throws -> (bytes: UInt64, response: Container) {
        let id = takeTransactionID()
        return try guarded {
            try send(.command(.getObject, transactionID: id, parameters: [handle]))
            let header = try awaitHeader()
            try requireTransaction(id, header.transactionID)
            guard header.kind == .data else {
                // 데이터 없이 바로 응답이 오면(예: 없는 핸들) 받은 바이트 없이 그 응답을 돌려줍니다.
                return try (0, nextContainer(timeout: Self.commandReadTimeout))
            }
            _ = buffer.removeFirst(upTo: ContainerHeader.size)
            var remaining = Int(header.length) - ContainerHeader.size
            var written: UInt64 = 0
            while remaining > 0 {
                guard !buffer.isEmpty else {
                    try buffer.append(transport.read(maxLength: Self.readLength, timeout: Self.dataReadTimeout))
                    continue
                }
                guard !isCancelled() else { throw SessionError.cancelled }
                let piece = buffer.removeFirst(upTo: remaining)
                try file.write(contentsOf: piece)
                remaining -= piece.count
                written += UInt64(piece.count)
                progress(written)
            }
            let response = try nextContainer(timeout: Self.commandReadTimeout)
            guard response.kind == .response else { throw unexpected(response) }
            try requireTransaction(id, response.transactionID)
            return (written, response)
        }
    }

    /// 다음 컨테이너의 헤더가 쌓일 때까지 읽습니다. 그 사이에 온 이벤트는 건너뜁니다.
    private func awaitHeader() throws -> ContainerHeader {
        var strayEvents = 0
        while true {
            guard let header = try buffer.peekHeader() else {
                try buffer.append(transport.read(maxLength: Self.readLength, timeout: Self.dataReadTimeout))
                continue
            }
            guard header.kind == .event else { return header }
            strayEvents += 1
            let event = try nextContainer(timeout: Self.commandReadTimeout)
            guard strayEvents <= Self.maxStrayEvents else { throw unexpected(event) }
        }
    }
}
