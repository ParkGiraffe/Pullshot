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

    @Test func `정보 창은 두 언어로 Nintendo와 관계없다고 밝힌다`() throws {
        let korean = try #require(infoPlist()["NSHumanReadableCopyright"] as? String)
        let english = try #require(stringsTable("en", table: "InfoPlist")["NSHumanReadableCopyright"])
        #expect(korean.contains("Nintendo가 만들거나 승인한 프로젝트가 아닌"))
        #expect(english.contains("not made or endorsed by Nintendo"))
    }
}

/// 위치 지정(`%1$@`)을 뺀 서식 지정자 종류를 정렬해 돌려줍니다. 영어에서 순서를 바꿔도 같다고 봅니다.
private func formatSpecifiers(_ text: String) -> [String] {
    text.matches(of: /%(?:\d+\$)?(lld|ld|d|@|f)/).map { String($0.output.1) }.sorted()
}
