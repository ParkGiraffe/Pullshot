import ArgumentParser
import Foundation
import PullshotKit

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "캡처를 원본 그대로 받습니다. 받을 폴더 아래 게임 이름 폴더에 저장합니다."
    )

    @Flag(help: "모든 캡처를 받습니다.")
    var all = false

    @Argument(help: "받을 캡처입니다. list에 나온 파일 이름이나 \"게임/파일 이름\"입니다.")
    var names: [String] = []

    @Option(help: "이 게임의 캡처만 받습니다.")
    var game: String?

    @Option(help: "받을 폴더입니다.")
    var out = "~/Pictures/Pullshot"

    @OptionGroup var connection: ConnectionOptions

    func validate() throws {
        guard all || !names.isEmpty else { throw ValidationError("--all이나 받을 캡처 이름을 주세요.") }
    }

    func run() throws {
        try Terminal.run {
            Terminal.listenForInterrupt()
            let connection = try Connection.open(connection)
            defer { connection.close() }
            let scan = try AlbumScanner(source: connection.session).scan(isCancelled: { Terminal.isInterrupted })
            let captures = List.only(game, in: scan).captures
            let chosen = all ? captures : captures.filter { names.contains($0.filename) || names.contains($0.id) }
            let missing = all ? [] : names.filter { name in !chosen.contains { $0.filename == name || $0.id == name } }
            missing.forEach { Terminal.error("찾지 못한 캡처: \($0)") }
            var tally = Tally(failed: missing.count)
            try save(chosen, with: connection.session, tally: &tally)
            print("저장 \(tally.saved)개, 건너뜀 \(tally.skipped)개, 실패 \(tally.failed)개")
            if Terminal.isInterrupted {
                throw ExitCode(130)
            }
            if tally.failed > 0 {
                throw ExitCode.failure
            }
        }
    }

    private func save(_ captures: [Capture], with session: Session, tally: inout Tally) throws {
        let root = URL(filePath: (out as NSString).expandingTildeInPath)
        for capture in captures {
            // 세션이 어긋났으면 남은 캡처도 모두 실패하므로 멈춥니다.
            guard !Terminal.isInterrupted, session.isValid else { return }
            let game = capture.gameName
            let folder = root.appending(path: game)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            switch DestinationNamer.decide(filename: capture.filename, size: capture.size, in: folder) {
            case .skip:
                tally.skipped += 1
            case let .write(destination):
                do {
                    try session.download(
                        capture.handle,
                        expectedSize: capture.size,
                        to: destination,
                        isCancelled: { Terminal.isInterrupted }
                    )
                    tally.saved += 1
                    print("저장: \(game)/\(destination.lastPathComponent)")
                } catch SessionError.cancelled {
                    return
                } catch {
                    tally.failed += 1
                    Terminal.error("\(capture.id): \(ErrorMessages.message(for: error))")
                }
            }
        }
    }
}

private struct Tally {
    var saved = 0
    var skipped = 0
    var failed: Int
}
