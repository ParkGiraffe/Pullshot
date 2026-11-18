import ArgumentParser
import Foundation
import PullshotKit

enum TransferReport {
    static func progress(_ progress: TransferProgress) {
        guard progress.bytes == 0 else { return }
        Terminal.error("\(progress.index + 1)/\(progress.total) \(progress.capture.id)")
    }

    static func finish(_ summary: TransferSummary, missing: Int, under root: URL) throws {
        let rootPath = root.path(percentEncoded: false) + "/"
        summary.saved.forEach { print("저장: " + $0.path(percentEncoded: false).replacing(rootPath, with: "")) }
        summary.failures.forEach { Terminal.error("\($0.capture.id): \(ErrorMessages.message(for: $0.error))") }
        let failed = summary.failures.count + missing
        print("저장 \(summary.saved.count)개, 건너뜀 \(summary.skipped)개, 실패 \(failed)개, 가져오지 못함 \(summary.notAttempted)개")
        if summary.isCancelled {
            Terminal.error("취소했습니다.")
            throw ExitCode(130)
        }
        if failed > 0 || summary.notAttempted > 0 {
            throw ExitCode.failure
        }
    }
}
