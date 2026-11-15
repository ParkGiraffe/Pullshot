import Foundation
import Testing
@testable import PullshotKit

/// 정해 둔 순서대로 쓰기를 확인하고 읽기에 답하는 가짜 전송입니다.
final class ScriptedTransport: Transport {
    enum Step {
        /// nil이면 내용은 따지지 않고 쓰기가 일어났는지만 봅니다.
        case expectWrite(Data?)
        case read(Data)
        case readError(TransportError)
    }

    private var steps: [Step]
    private(set) var written: [Data] = []
    private(set) var ptpResets = 0
    private(set) var usbResets = 0
    var ptpResetError: TransportError?

    init(_ steps: [Step]) {
        self.steps = steps
    }

    var isFinished: Bool {
        steps.isEmpty
    }

    func write(_ data: Data, timeout _: TimeInterval) throws {
        written.append(data)
        guard case let .expectWrite(expected) = steps.first else {
            Issue.record("예상하지 않은 쓰기: \(data as NSData)")
            throw TransportError.io(code: 0)
        }
        steps.removeFirst()
        if let expected {
            #expect(data == expected, "쓴 컨테이너가 다릅니다: \(data as NSData)")
        }
    }

    func read(maxLength _: Int, timeout _: TimeInterval) throws -> Data {
        switch steps.first {
        case let .read(data):
            steps.removeFirst()
            return data
        case let .readError(error):
            steps.removeFirst()
            throw error
        default:
            Issue.record("예상하지 않은 읽기")
            throw TransportError.timedOut
        }
    }

    func resetPTPDevice() throws {
        ptpResets += 1
        if let ptpResetError {
            throw ptpResetError
        }
    }

    func resetUSBDevice() throws {
        usbResets += 1
    }

    func close() {}
}

func responseFixture(_ code: UInt16, tid: UInt32, params: [UInt32] = []) -> Data {
    var payload = ByteWriter()
    params.forEach { payload.u32($0) }
    return Container(kind: .response, code: code, transactionID: tid, payload: payload.data).encoded()
}

func dataContainerFixture(_ operation: PTP.Operation, tid: UInt32, _ payload: Data) -> Data {
    Container(kind: .data, code: operation.rawValue, transactionID: tid, payload: payload).encoded()
}
