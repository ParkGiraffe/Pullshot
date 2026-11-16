import ArgumentParser
import Foundation
import PullshotKit

struct ConnectionOptions: ParsableArguments {
    @Flag(help: "USB 전송과 PTP 트랜잭션을 한 줄씩 표준 오류에 씁니다.")
    var verbose = false

    @Option(help: "주고받은 바이트를 이 파일에 JSON Lines로 남깁니다.")
    var record: Path?
}

/// 열린 연결 하나입니다. 명령이 끝나면 `close()`로 세션과 인터페이스를 놓습니다.
struct Connection {
    let console: AttachedConsole
    let transport: Transport
    let session: Session
    let info: DeviceInfo

    /// 첫 스위치를 엽니다. 남은 세션을 풀려고 USB 장치를 다시 붙였으면, 다시 나타나길 기다려 한 번 더 엽니다.
    static func open(_ options: ConnectionOptions, recordingTo recordFile: URL? = nil) throws -> Self {
        let trace = options.verbose ? Terminal.trace : nil
        let record = recordFile ?? options.record?.url
        for attempt in 1 ... 2 {
            guard let console = ConsoleLocator.attached().first else { throw missingConsole() }
            if console.model.isExperimental, attempt == 1 {
                Terminal.error("\(console.model.name) 지원은 실험 단계입니다. 문제가 있으면 --verbose 출력과 함께 GitHub 이슈로 알려 주세요.")
            }
            let host = try openTransport(console, trace: trace, isReattached: attempt > 1)
            let transport: Transport = try record.map { try RecordingTransport(wrapping: host, to: $0) } ?? host
            let session = Session(transport: transport, trace: trace)
            do {
                return try Self(console: console, transport: transport, session: session, info: session.open())
            } catch SessionError.needsUSBReset where attempt == 1 {
                transport.close()
                // USB 장치를 다시 붙이면 스위치가 PC로 복사 모드에서 나갑니다(2026-11-15, 펌웨어 23.5.0에서 확인).
                Terminal.error("이전 연결이 남아 있어 스위치의 USB 연결을 재설정했고, 이때 PC로 복사가 꺼졌습니다. 본체에서 PC로 복사를 다시 켜 주세요. 60초 기다립니다.")
                try waitForReattach()
            }
        }
        throw SessionError.needsUSBReset
    }

    func close() {
        session.close()
        transport.close()
    }

    /// 앨범을 훑습니다. Ctrl-C를 누르면 객체 사이에서 멈춥니다.
    func scanAlbum() throws -> AlbumScan {
        try AlbumScanner(source: session).scan(isCancelled: { Terminal.isInterrupted })
    }

    /// 다시 붙은 기기는 노드가 먼저 보이고 사진 전송 인터페이스는 조금 늦게 생기므로, 그동안은 몇 초 더 기다립니다.
    private static func openTransport(
        _ console: AttachedConsole,
        trace: ((String) -> Void)?,
        isReattached: Bool
    ) throws -> HostTransport {
        let deadline = Date().addingTimeInterval(isReattached ? 5 : 0)
        while true {
            do {
                return try HostTransport(console: console, trace: trace)
            } catch ConsoleAccessError.noStillImageInterface where Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    /// 사용자가 본체에서 PC로 복사를 다시 켤 때까지 기다립니다.
    private static func waitForReattach() throws {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            guard !Terminal.isInterrupted else { throw SessionError.cancelled }
            Thread.sleep(forTimeInterval: 0.5)
            if !ConsoleLocator.attached().isEmpty {
                return
            }
        }
        throw missingConsole()
    }

    private static func missingConsole() -> CLIError {
        ConsoleLocator.idle().first.map { CLIError.notInTransferMode($0.name) } ?? .noConsole
    }
}
