import Foundation

extension Session {
    /// 앞 연결이 남긴 바이트를 비울 때 한 번 읽기를 기다리는 시간과, 비우기에 쓰는 전체 시간입니다.
    static let drainReadTimeout: TimeInterval = 0.3
    static let drainBudget: TimeInterval = 60
}

public extension Session {
    /// 세션을 열고 기기 정보를 돌려줍니다. Tethersnap이 2026-08-30 스위치 2(펌웨어 22.5.0)에서 기록한 두 문제를 넘깁니다.
    /// - 전송 모드에 다시 들어온 스위치는 세션 없는 GetDeviceInfo를 거부합니다. 그때는 세션을 연 뒤에 받습니다.
    /// - 다른 프로세스가 연 세션이 남아 있으면 OpenSession이 거부됩니다.
    ///   세션 닫기, PTP 장치 리셋, USB 장치 리셋 순으로 풉니다.
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
            // 기기에 열린 세션을 남기면 다음 연결이 SessionAlreadyOpen으로 막힙니다.
            close()
            throw error
        }
    }

    /// CloseSession을 보냅니다. 기기가 이미 사라졌을 수 있어 실패는 무시합니다.
    /// 앞선 실패로 어긋난 세션도 닫아 둡니다. 스위치에 세션이 남으면 다음 연결이 USB 장치 리셋까지 가고
    /// 스위치가 PC로 복사 모드에서 나갑니다(2026-11-15, 펌웨어 23.5.0에서 확인).
    func close() {
        defer { isOpen = false }
        guard isOpen else { return }
        guard !isValid else {
            _ = try? exchange(.closeSession)
            return
        }
        // 끊긴 트랜잭션의 남은 데이터와 응답을 비우면 기기는 다음 트랜잭션 ID를 기다립니다.
        drainLeftovers()
        try? send(.command(.closeSession, transactionID: takeTransactionID()))
        _ = try? nextContainer(timeout: Self.commandReadTimeout)
    }

    /// 앞 연결이 취소나 시간 초과로 끝났으면 기기가 그 데이터 단계를 아직 보내고 있습니다.
    /// 새 세션의 첫 응답에 그 바이트가 섞이지 않도록 짧게 읽어 비웁니다.
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

    /// 남은 세션은 트랜잭션 ID를 알 수 없어 닫기가 거부되기 쉽습니다. 그러면 PTP 장치 리셋을 보내고,
    /// 스위치가 그 요청마저 멈춤(stall)으로 받으면 USB 장치를 다시 붙입니다.
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

    /// 마지막 수단입니다. 기기가 다시 나타나면 새 전송으로 다시 열어야 하므로, 다시 붙이기에 실패해도 재연결을 요구합니다.
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
