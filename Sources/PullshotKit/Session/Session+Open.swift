import Foundation

extension Session {
    static let drainReadTimeout: TimeInterval = 0.3
    static let drainBudget: TimeInterval = 60
}

public extension Session {
    func open() throws -> DeviceInfo {
        drainLeftovers()
        let sessionlessInfo = try sessionlessDeviceInfo()
        try openSession(isRetry: false)
        isOpen = true
        nextTransactionID = 1
        if let sessionlessInfo {
            return sessionlessInfo
        }
        do {
            return try DeviceInfo(transact(.getDeviceInfo).data)
        } catch {
            close()
            throw error
        }
    }

    func close() {
        defer { isOpen = false }
        guard isOpen else { return }
        guard !isValid else {
            _ = try? exchange(.closeSession)
            return
        }
        drainLeftovers()
        try? send(.command(.closeSession, transactionID: takeTransactionID()))
        _ = try? nextContainer(timeout: Self.commandReadTimeout)
    }

    private func drainLeftovers() {
        buffer = PacketBuffer()
        let deadline = Date().addingTimeInterval(Self.drainBudget)
        while Date() < deadline {
            guard let chunk = try? transport.read(maxLength: Self.readLength, timeout: Self.drainReadTimeout),
                  !chunk.isEmpty
            else { return }
            Log.ptp.notice("앞 연결이 남긴 \(chunk.count)바이트를 버립니다")
        }
    }

    private func sessionlessDeviceInfo() throws -> DeviceInfo? {
        let reply = try exchange(.getDeviceInfo, transactionID: 0)
        guard reply.response.code == PTP.Response.ok.rawValue, !reply.data.isEmpty else { return nil }
        return try? DeviceInfo(reply.data)
    }

    private func openSession(isRetry: Bool) throws {
        let response = try exchange(.openSession, [PTP.sessionID], transactionID: 0).response
        guard response.code != PTP.Response.ok.rawValue else { return }
        if isRetry {
            try resetUSBDevice()
        }
        guard PTP.Response(rawValue: response.code) == .sessionAlreadyOpen else {
            throw SessionError.response(PTP.Response(rawValue: response.code), operation: .openSession)
        }
        try closeStaleSession()
        try openSession(isRetry: true)
    }

    private func closeStaleSession() throws {
        let isClosed = try exchange(.closeSession, transactionID: 0).response.code == PTP.Response.ok.rawValue
        guard !isClosed else { return }
        do {
            try transport.resetPTPDevice()
            buffer = PacketBuffer()
        } catch {
            Log.usb.error("PTP 장치 리셋 실패: \(String(describing: error), privacy: .private)")
            try resetUSBDevice()
        }
    }

    private func resetUSBDevice() throws -> Never {
        invalidate(because: SessionError.needsUSBReset)
        do {
            try transport.resetUSBDevice()
        } catch {
            Log.usb.error("USB 장치를 다시 붙이지 못했습니다: \(String(describing: error), privacy: .private)")
        }
        throw SessionError.needsUSBReset
    }
}
