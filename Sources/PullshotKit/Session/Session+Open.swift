import Foundation

public extension Session {
    /// 세션을 열고 기기 정보를 돌려줍니다. 스위치에서 알려진 두 문제를 넘깁니다.
    /// - 전송 모드에 다시 들어온 스위치는 세션 없는 GetDeviceInfo를 거부합니다(Tethersnap 0.1.0 기록, 펌웨어 22.5.0).
    ///   그때는 세션을 연 뒤에 받습니다.
    /// - 다른 프로세스가 연 세션이 남아 있으면 OpenSession이 거부됩니다(같은 기록).
    ///   세션 닫기, PTP 장치 리셋, USB 장치 리셋 순으로 풉니다.
    func open() throws -> DeviceInfo {
        let sessionless = try sessionlessDeviceInfo()
        try openSession(retryingStaleSession: true)
        isOpen = true
        nextTransactionID = 1
        return try sessionless ?? DeviceInfo(transact(.getDeviceInfo).data)
    }

    /// CloseSession을 보냅니다. 기기가 이미 사라졌을 수 있어 실패는 무시합니다.
    func close() {
        defer { isOpen = false }
        guard isOpen, isValid else { return }
        _ = try? exchange(.closeSession)
    }

    private func sessionlessDeviceInfo() throws -> DeviceInfo? {
        let exchanged = try exchange(.getDeviceInfo, transactionID: 0)
        guard exchanged.response.code == PTP.Response.ok.rawValue, !exchanged.data.isEmpty else { return nil }
        return try DeviceInfo(exchanged.data)
    }

    private func openSession(retryingStaleSession: Bool) throws {
        let response = try exchange(.openSession, [PTP.sessionID], transactionID: 0).response
        switch PTP.Response(rawValue: response.code) {
        case .ok:
            return
        case .sessionAlreadyOpen where retryingStaleSession:
            try closeStaleSession()
            try openSession(retryingStaleSession: false)
        default:
            throw SessionError.response(PTP.Response(rawValue: response.code), operation: .openSession)
        }
    }

    /// 남은 세션은 트랜잭션 ID를 알 수 없어 닫기가 거부되기 쉽습니다. 그러면 PTP 장치 리셋을 보내고,
    /// 스위치가 그 요청마저 멈춤(stall)으로 받으면 USB 장치를 다시 붙입니다.
    private func closeStaleSession() throws {
        let closed = try exchange(.closeSession, transactionID: 0).response.code == PTP.Response.ok.rawValue
        guard !closed else { return }
        do {
            try transport.resetPTPDevice()
            buffer = PacketBuffer()
        } catch {
            Log.usb.error("PTP 장치 리셋 실패, USB 장치를 다시 붙입니다: \(String(describing: error), privacy: .public)")
            try transport.resetUSBDevice()
            invalidate(because: SessionError.needsUSBReset)
            throw SessionError.needsUSBReset
        }
    }
}
