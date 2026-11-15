import ArgumentParser
import Foundation
import PullshotKit

struct Probe: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "기기 정보, 지원 명령, 저장소를 보여 줍니다.")

    @OptionGroup var connection: ConnectionOptions

    func run() throws {
        try Terminal.run {
            Terminal.listenForInterrupt()
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
            "펌웨어: \(info.deviceVersion)",
            "일련번호: \(info.serialNumber)",
            "PTP 버전: \(info.standardVersion)",
            "지원 명령: " + info.operationsSupported.map { String(format: "0x%04X", $0) }.joined(separator: " "),
        ] + storages
    }

    private static func gigabytes(_ bytes: UInt64?) -> String {
        bytes.map { String(format: "%.1f GB", Double($0) / 1_000_000_000) } ?? "알 수 없음"
    }
}
