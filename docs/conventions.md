# Coding Conventions

English | [한국어](conventions.ko.md)

This is the standard for writing and reviewing Pullshot code. It adapts two sources to Swift.

- The coding principles and rules the author followed at a previous company: naming, tests, errors, and commits
- The SwiftLint, SwiftFormat, and pre-commit configuration from Tethersnap (https://github.com/Luminoid/Tethersnap): lint and format rules

When the two conflict, the first wins. The 120-character line length, Korean test titles, and the commit format are examples.

## Coding Principles

1. Code is its own documentation, so readability comes first.
2. All code you write remains as maintenance debt, so implement with as little code as possible and do not spell out arguments that match the default.
3. A name is the first thing that reveals the intent of the code, so refine it to show behavior and domain rather than implementation.
4. If a test title depends on the implementation, the test has to change every time the implementation does, so describe tests in domain language.
5. Code smells grow into debt the longer they are left alone, so refactor them as soon as you find them.
6. Writing code is like writing prose, so put a blank line only where the thought changes, not just because the syntax changes, as in declaration, execution, and return.

## Naming Policy

- Give a Bool a prefix that fits its meaning: `is` for state and attributes, `has` for possession, `can` for ability, and `should` for intent (`isOpen`, `hasThumbnail`).
- Name an event or result that happened at one point in time with a past participle and no prefix (`opened`, `cancelled`).
- Name values that are not functions with a noun (phrase).
- Inline a value that is used only once, but keep it as a variable if its name explains the intent, the line becomes too long, or it would be recomputed on every iteration of a loop.
- Use names defined by a standard or a device as they are (`GetObjectHandles` and `StorageID` from PTP).
- Define terms and code names in `docs/glossary.md`.

## Control Flow Policy

- Use `switch` only to branch on the same enum value. Write range comparisons, compound conditions, and extra branching inside a case with `if`.

## Error Policy

- PullshotKit throws domain errors (`SessionError`, `ConsoleAccessError`, and so on) as they are, and Kit types carry no user-facing text.
- Convert errors into user-facing text only in the CLI's `ErrorMessages`, the app's `AppErrorMessages`, and the string tables. If both need the same text, each writes its own.

## Testing Policy

- Use Swift Testing, and make assertions with `#expect` and `#require`.
- Give each type a `@Suite("<type> 테스트")` (`<type> tests`), and inside it a `@Suite("<behavior>")` for each behavior.
- Write test titles in Korean domain language, describing the condition and the result as in "when ~, then ~" (the "~하면 ~한다" form).

  ```swift
  @Suite("Session 테스트")
  struct SessionTests {
      @Suite("세션 열기")
      struct Opening {
          @Test func `세션 없이 기기 정보를 거부하면 세션 안에서 다시 받는다`() throws { … }
      }
  }
  ```

- Do not build expected values with the code under test. Write values calculated by hand.
- Build test data with `<target>Fixture(...)` fixtures that have default values, so each test passes only the values that differ.
- Real-device dumps (`LocalFixtures/`) contain device serial numbers and the user's photos and videos, so do not commit them.

## Comments and Logging Policy

- Do not write comments in code. Put the reason for a change in the commit message, and facts confirmed on real devices in `docs/hardware-notes.md`.
- Use `os.Logger` (subsystem `com.parkgiraffe.Pullshot`) for logging, and record file names, game names, paths, and serial numbers with `privacy: .private`.
- Users attach the app log file (`FileLog`) to issues, so do not record file names, game names, paths, or serial numbers in it.

## Lint and Format Policy

- SwiftLint `--strict` and SwiftFormat `--lint` run in `make check` and the pre-commit hook. Set up the hook once with `make setup-hooks`.
- Keep each line within 120 characters. Add a trailing comma after the last element of a collection literal, but not in a function call.
- The `identifier_name` rule is turned off because tests use Korean titles.

## Adding Packages

- PullshotKit uses no external packages, and only the CLI uses swift-argument-parser.
- Before adding a new package or replacing existing code with a package, propose it first and get approval.

## Commits

- End the title with a Korean noun form in the shape `{대상} {액션}` (`{target} {action}`), as in `PTP 컨테이너 추가` (Add PTP container) and `Session 재연결 순서 수정` (Fix Session reconnect order).
- Keep it within 72 characters and do not end it with a period. Write identifiers exactly as they are spelled, and separate multiple ones with commas.
- Omit the body if the title conveys enough. In the body, briefly state what changed and why rather than how it was written, in the formal 하십시오 register.
