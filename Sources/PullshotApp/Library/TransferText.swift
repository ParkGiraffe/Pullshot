import Foundation
import PullshotKit

/// 옮기기 결과를 화면에 보일 문구로 바꿉니다.
enum TransferText {
    /// "저장 N개 · 건너뜀 N개 · 실패 N개 · 받지 못함 N개"입니다. 저장 말고는 0개인 칸을 뺍니다.
    static func summary(_ summary: TransferSummary) -> String {
        var parts = [String(localized: "저장 \(summary.saved.count)개")]
        if summary.skipped > 0 {
            parts.append(String(localized: "건너뜀 \(summary.skipped)개"))
        }
        if !summary.failures.isEmpty {
            parts.append(String(localized: "실패 \(summary.failures.count)개"))
        }
        if summary.notAttempted > 0 {
            parts.append(String(localized: "받지 못함 \(summary.notAttempted)개"))
        }
        return parts.joined(separator: " · ")
    }
}
