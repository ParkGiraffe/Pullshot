import Foundation
import Testing
@testable import PullshotKit

@Suite("PTP 데이터셋 테스트")
struct DatasetTests {
    @Suite("기기 정보")
    struct Device {
        @Test func `모델, 일련번호, 펌웨어, 지원 명령을 읽는다`() throws {
            let info = try DeviceInfo(deviceInfoFixture(
                model: "Nintendo Switch 2",
                serial: "TEST0001",
                version: "23.0.1",
                operations: Array(0x1001 ... 0x100A)
            ))

            #expect(info.model == "Nintendo Switch 2")
            #expect(info.serialNumber == "TEST0001")
            #expect(info.deviceVersion == "23.0.1")
            #expect(info.operationsSupported == Array(0x1001 ... 0x100A))
        }
    }

    @Suite("저장소 정보")
    struct Storage {
        @Test func `용량이 모두 1인 비트면 알 수 없음으로 둔다`() throws {
            let info = try StorageInfo(storageInfoFixture(maxCapacity: .max))

            #expect(info.maxCapacity == nil)
            #expect(info.freeSpace == nil)
        }
    }

    @Suite("객체 정보")
    struct Object {
        @Test func `폴더의 한글 이름과 폴더 여부를 읽는다`() throws {
            let info = try ObjectInfo(objectInfoFixture(filename: "젤다무쌍 봉인전기", format: .association, size: 0))

            #expect(info.isFolder)
            #expect(info.filename == "젤다무쌍 봉인전기")
        }

        @Test func `사진의 크기, 부모, 찍은 시각 문자열을 읽는다`() throws {
            let photo = try ObjectInfo(objectInfoFixture(
                filename: "20261114211205_1.jpg",
                size: 1_153_024,
                parent: 0x10,
                captureDate: "20261114T211205"
            ))

            #expect(!photo.isFolder)
            #expect(photo.compressedSize == 1_153_024)
            #expect(photo.parent == 0x10)
            #expect(photo.captureDate == "20261114T211205")
        }
    }

    @Suite("날짜 문자열")
    struct DateTime {
        static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        static let expected = Date(timeIntervalSince1970: 1_794_658_325)

        @Test(arguments: [
            ("20261114T211205", seoul),
            ("20261114T211205.5", seoul),
            ("20261114T121205Z", seoul),
            ("20261114T211205+0900", .gmt),
        ] as [(String, TimeZone)])
        func `시간대가 없으면 받은 시간대로, Z는 UTC로, 부호 붙은 네 자리는 그 오프셋으로 읽고 초 아래는 버린다`(
            text: String,
            timeZone: TimeZone
        ) {
            #expect(DateTimeString.parse(text, timeZone: timeZone) == Self.expected)
        }

        @Test func `형식이 다르거나 없는 날짜면 nil이다`() {
            #expect(DateTimeString.parse("2026-11-14", timeZone: .gmt) == nil)
            #expect(DateTimeString.parse("20260230T000000", timeZone: .gmt) == nil)
            #expect(DateTimeString.parse("", timeZone: .gmt) == nil)
        }
    }
}
