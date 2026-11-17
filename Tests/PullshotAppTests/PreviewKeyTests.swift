import AppKit
import Testing
@testable import PullshotApp

@Suite("PreviewKey 테스트")
struct PreviewKeyTests {
    @Test func `왼쪽과 오른쪽 화살표는 한 장 옮긴다`() throws {
        #expect(try PreviewKey(keyFixture(.leftArrow)) == .move(.left))
        #expect(try PreviewKey(keyFixture(.rightArrow)) == .move(.right))
    }

    @Test func `위와 아래 화살표는 한 줄 옮긴다`() throws {
        #expect(try PreviewKey(keyFixture(.upArrow)) == .move(.up))
        #expect(try PreviewKey(keyFixture(.downArrow)) == .move(.down))
    }

    @Test func `스페이스와 Esc는 패널을 닫는다`() throws {
        #expect(try PreviewKey(keyFixture(" ")) == .close)
        #expect(try PreviewKey(keyFixture("\u{1B}")) == .close)
    }

    @Test func `⌘나 ⇧를 함께 누른 화살표는 패널에 맡긴다`() throws {
        #expect(try PreviewKey(keyFixture(.rightArrow, modifiers: .command)) == nil)
        #expect(try PreviewKey(keyFixture(.downArrow, modifiers: .shift)) == nil)
    }

    @Test func `다른 글자 키는 패널에 맡긴다`() throws {
        #expect(try PreviewKey(keyFixture("a")) == nil)
    }
}

/// 실제 화살표 키처럼 기능 키와 숫자판 표시를 함께 단 키 누름입니다.
private func keyFixture(_ key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
    try keyFixture(String(Character(key.unicodeScalar)), modifiers: modifiers.union([.function, .numericPad]))
}

private func keyFixture(_ characters: String, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
    try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: 0
    ))
}
