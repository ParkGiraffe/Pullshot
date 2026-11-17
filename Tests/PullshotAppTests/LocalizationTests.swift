import Foundation
import Testing

@Suite("문자열 표 테스트")
struct LocalizationTests {
    @Test func `두 언어 표의 키가 같다`() throws {
        #expect(try Set(stringsTable("ko").keys) == Set(stringsTable("en").keys))
    }

    @Test func `같은 키는 서식 지정자가 같다`() throws {
        let english = try stringsTable("en")
        for (key, korean) in try stringsTable("ko") {
            #expect(formatSpecifiers(korean) == formatSpecifiers(english[key] ?? ""), "\(key)")
        }
    }

    @Test func `한국어 표는 키와 값이 같다`() throws {
        for (key, value) in try stringsTable("ko") {
            #expect(key == value)
        }
    }
}

private func formatSpecifiers(_ text: String) -> [String] {
    text.matches(of: /%(?:\d+\$)?(lld|ld|d|@|f)/).map { String($0.output.1) }.sorted()
}
