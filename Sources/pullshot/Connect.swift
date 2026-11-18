import ArgumentParser
import Foundation
import PullshotKit

struct ConnectionOptions: ParsableArguments {
    @Flag(help: "USB 전송과 PTP 트랜잭션을 한 줄씩 표준 오류에 출력합니다.")
    var verbose = false

    @Option(help: "주고받은 바이트를 이 파일에 JSON Lines 형식으로 저장합니다.")
    var record: Path?
}

struct Connection {
    let console: AttachedConsole
    let transport: Transport
    let session: Session
    let info: DeviceInfo

    static func open(_ options: ConnectionOptions, recordingTo recordFile: URL? = nil) throws -> Self {
        let trace = options.verbose ? Terminal.trace : nil
        let record = recordFile ?? options.record?.url
        for attempt in 1 ... 2 {
            guard let console = ConsoleLocator.attached().first else { throw missingConsole() }
            if console.model.isExperimental, attempt == 1 {
                Terminal.error("\(console.model.name) 지원은 실험 단계입니다. 문제가 생기면 --verbose 출력을 첨부해 GitHub 이슈로 알려 주세요.")
            }
            let host = try HostTransport.open(
                console,
                trace: trace,
                waitingUpTo: attempt > 1 ? 5 : 0,
                isCancelled: { Terminal.isInterrupted }
            )
            let transport: Transport = try record.map { try RecordingTransport(wrapping: host, to: $0) } ?? host
            let session = Session(transport: transport, trace: trace)
            do {
                return try Self(console: console, transport: transport, session: session, info: session.open())
            } catch SessionError.needsUSBReset where attempt == 1 {
                transport.close()
                Terminal
                    .error("이전 연결이 남아 있어 스위치의 USB 연결을 재설정했고, 이때 PC로 복사가 꺼졌습니다. 본체에서 PC로 복사를 다시 켜 주세요. 최대 60초 기다립니다.")
                try waitForReattach()
            }
        }
        throw SessionError.needsUSBReset
    }

    func close() {
        session.close()
        transport.close()
    }

    func scanAlbum() throws -> AlbumScan {
        try AlbumScanner(source: session).scan(isCancelled: { Terminal.isInterrupted })
    }

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
