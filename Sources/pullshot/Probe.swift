import ArgumentParser
import Foundation
import PullshotKit

struct Probe: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "기기 정보, 지원하는 PTP 명령, 저장소를 출력합니다.")

    @OptionGroup var connection: ConnectionOptions

    func run() throws {
        try Terminal.run {
            let connection = try Connection.open(connection)
            defer { connection.close() }
            try Self.report(connection).forEach { print($0) }
        }
    }

    static func report(_ connection: Connection) throws -> [String] {
        let info = connection.info
        let storages = try connection.session.storageIDs().map { id in
            let storage = try connection.session.storageInfo(id)
            let capacity = "용량 \(gigabytes(storage.maxCapacity)), 남은 공간 \(gigabytes(storage.freeSpace))"
            return String(format: "저장소 0x%08X: ", id) + "\(storage.storageDescription), \(capacity)"
        }
        return [
            "모델: \(info.model)",
            "제조사: \(info.manufacturer)",
            "시스템 버전: \(info.deviceVersion)",
            "일련번호: \(info.serialNumber)",
            "PTP 버전: \(info.standardVersion)",
            "지원 명령: " + info.operationsSupported.map { String(format: "0x%04X", $0) }.joined(separator: " "),
        ] + storages
    }

    private static func gigabytes(_ bytes: UInt64?) -> String {
        bytes.map { String(format: "%.1f GB", Double($0) / 1_000_000_000) } ?? "알 수 없음"
    }
}
