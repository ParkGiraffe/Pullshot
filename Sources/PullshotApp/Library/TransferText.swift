import Foundation
import PullshotKit

enum TransferText {
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
