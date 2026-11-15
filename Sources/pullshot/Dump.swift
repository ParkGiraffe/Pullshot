import ArgumentParser
import Foundation
import PullshotKit

struct Dump: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "실기기 응답을 그대로 기록합니다. 테스트 픽스처를 만들 때 씁니다."
    )

    @Option(help: "기록을 남길 폴더입니다.")
    var out: String

    @OptionGroup var connection: ConnectionOptions

    func run() throws {
        try Terminal.run {
            let folder = URL(filePath: (out as NSString).expandingTildeInPath)
            let files = folder.appending(path: "files")
            try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
            let connection = try Connection.open(connection, recordingTo: folder.appending(path: "transcript.jsonl"))
            defer { connection.close() }

            try write(Probe.report(connection), to: folder.appending(path: "probe.txt"))
            let scan = try AlbumScanner(source: connection.session).scan()
            try write(ListFormatter.lines(scan, timeZone: .current), to: folder.appending(path: "list.txt"))
            for capture in scan.captures.prefix(3) {
                do {
                    try connection.session.thumbnail(capture.handle)
                        .write(to: files.appending(path: "thumb-\(capture.filename)"))
                } catch {
                    Terminal.error("\(capture.id) 썸네일: \(ErrorMessages.message(for: error))")
                }
            }
            if let photo = scan.captures.first(where: { $0.kind == .photo }) {
                try connection.session.download(
                    photo.handle,
                    expectedSize: photo.size,
                    to: files.appending(path: photo.filename)
                )
            }
            print("기록을 남겼습니다: \(folder.path(percentEncoded: false))")
            Terminal.error("이 폴더에는 기기 일련번호와 캡처가 들어 있습니다. 공개 리포에 올리지 마세요.")
        }
    }

    private func write(_ lines: [String], to file: URL) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }
}
