import ArgumentParser
import Foundation
import PullshotKit

/// `pull`과 `export`의 진행과 결과를 씁니다. 결과 파일 목록은 표준 출력, 진행과 오류는 표준 오류입니다.
enum TransferReport {
    static func progress(_ progress: TransferProgress) {
        guard progress.bytes == 0 else { return }
        Terminal.error("\(progress.index + 1)/\(progress.total) \(progress.capture.id)")
    }

    /// 요약을 쓰고, 취소면 종료 코드 130, 실패나 받지 못한 캡처가 있으면 1로 끝냅니다.
    static func finish(_ summary: TransferSummary, missing: Int, under root: URL) throws {
        let rootPath = root.path(percentEncoded: false) + "/"
        summary.saved.forEach { print("저장: " + $0.path(percentEncoded: false).replacing(rootPath, with: "")) }
        summary.failures.forEach { Terminal.error("\($0.capture.id): \(ErrorMessages.message(for: $0.error))") }
        let failed = summary.failures.count + missing
        print("저장 \(summary.saved.count)개, 건너뜀 \(summary.skipped)개, 실패 \(failed)개, 받지 못함 \(summary.notAttempted)개")
        if summary.isCancelled {
            Terminal.error("취소했습니다.")
            throw ExitCode(130)
        }
        if failed > 0 || summary.notAttempted > 0 {
            throw ExitCode.failure
        }
    }
}
