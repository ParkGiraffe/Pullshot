import PullshotKit
import SwiftUI

/// 오른쪽 칸 아래 단추 자리에 두는 옮기기 진행과 결과입니다. 결과는 닫을 때까지 남깁니다.
struct TransferPanel: View {
    let run: LibraryModel.TransferRun
    let model: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if run.isFinished {
                result
            } else {
                progress
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    @ViewBuilder private var progress: some View {
        if let current = run.progress {
            let fileFraction = fileFraction(of: current)
            Group {
                if run.kind == .imported {
                    Text("가져오는 중 \(current.index + 1)/\(current.total)")
                } else {
                    Text("내보내는 중 \(current.index + 1)/\(current.total)")
                }
            }
            .font(.headline)
            .monospacedDigit()
            Text(verbatim: current.capture.filename)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            ProgressView(value: fileFraction)
                .controlSize(.small)
            ProgressView(value: (Double(current.index) + (fileFraction ?? 0)) / Double(current.total))
        } else {
            ProgressView()
                .progressViewStyle(.linear)
        }
        Button("취소") {
            model.cancelTransfer()
        }
    }

    @ViewBuilder private var result: some View {
        if run.summary?.isCancelled == true {
            Text("취소했습니다.")
        }
        if let summary = run.summary {
            Text(TransferText.summary(summary))
                .font(.headline)
            if !summary.failures.isEmpty {
                DisclosureGroup("실패한 항목") {
                    ForEach(summary.failures, id: \.capture.id) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: failure.capture.filename)
                            Text(AppErrorMessages.message(for: failure.error))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        if let errorMessage = run.errorMessage {
            Text(errorMessage)
        }
        HStack {
            Button("Finder에서 보기") {
                model.revealInFinder()
            }
            Spacer(minLength: 0)
            Button("닫기") {
                model.dismissTransferResult()
            }
        }
    }

    /// 크기를 모르는 캡처는 받은 비율도 모르므로 nil이고, 막대는 움직이는 모양으로 둡니다.
    private func fileFraction(of progress: TransferProgress) -> Double? {
        guard let size = progress.capture.size, size > 0 else { return nil }
        return min(Double(progress.bytes) / Double(size), 1)
    }
}
