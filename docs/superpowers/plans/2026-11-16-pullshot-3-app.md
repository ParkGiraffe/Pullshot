# Pullshot 3단계: 앱 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스위치를 꽂으면 저절로 열어 게임별 캡처를 격자로 보여 주고, 새 항목 가져오기와 번호 붙여 내보내기를 하는 SwiftUI 앱(`Pullshot.app`)을 만들고 실기기로 확인합니다.

**Architecture:** 앱 타깃 `PullshotApp`은 Kit을 묶는 가장자리입니다. 기기와 주고받는 일은 전용 직렬 큐에서 도는 액터 `DeviceWorker` 하나가 모두 맡고, 화면 상태는 `@MainActor @Observable`인 `LibraryModel`이 가집니다. 화면이 칸마다 묻는 옮긴 기록은 값(`LedgerIndex`)으로 받아 두고, 날짜 묶기와 요약처럼 화면과 무관한 계산은 Kit에 둡니다. 번들은 Xcode 프로젝트 없이 Makefile이 조립하고 ad-hoc 서명합니다.

**Tech Stack:** Swift 6.2 도구(로컬 Swift 6.3.3), SwiftPM, macOS 15 이상, SwiftUI, AppKit, QuickLook, IOKit, Synchronization, Swift Testing, SwiftLint, SwiftFormat.

**Spec:** `docs/superpowers/specs/2026-11-15-pullshot-design.md`의 6.1~6.7, 7, 11절입니다. 화면은 `mockups/library-v2.html`과 PNG 두 장을 따르되, 플레이 묶음은 빼고 격자는 최신순입니다(6.5). 실기기 사실은 `docs/hardware-notes.md`입니다.

**이 계획의 범위:** 세 계획 중 마지막입니다. 2단계가 넘긴 연결 감시(꽂고 빼기, 두 대 전환), 썸네일 캐시, 날짜 보기, Quick Look, 현지화, 파일 로그, 내보낼 기준 폴더 기억을 여기서 합니다. DMG와 GitHub 릴리스(설계 10절 결정 뒤), 앱 아이콘, 강제 종료 뒤 남은 세션을 마지막 트랜잭션 ID로 닫는 실험, 설계 12절의 다음 버전 후보는 하지 않습니다.

## Global Constraints

1단계와 2단계 계획의 Global Constraints를 모두 이어받습니다. 3단계에서 더하는 것은 이렇습니다.

- 앱 타깃 이름은 `PullshotApp`(`Sources/PullshotApp`)입니다. `Sources/Pullshot`은 대소문자를 가리지 않는 APFS에서 CLI의 `Sources/pullshot`과 같은 폴더가 됩니다. 번들 안 실행 파일 이름은 `Pullshot`입니다.
- 번들은 `dist/Pullshot.app`입니다. `CFBundleIdentifier` `com.parkgiraffe.Pullshot`, `CFBundleName` `Pullshot`, `LSMinimumSystemVersion` `15.0`, `CFBundleDevelopmentRegion` `ko`, `CFBundleLocalizations` `[ko, en]`, 버전 `0.1.0`이고 `codesign --force --sign -`로 ad-hoc 서명합니다. 샌드박스와 엔타이틀먼트는 쓰지 않습니다(CLI와 같은 사용자 공간 USB 접근).
- 문자열은 `App/ko.lproj/Localizable.strings`와 `App/en.lproj/Localizable.strings`입니다. 이 맥은 Xcode가 아니라 Command Line Tools가 골라져 있어 `xcstringstool`이 없으므로 설계 6.7의 대안(.strings)을 씁니다. 키는 한국어 원문이고 한국어 표에도 같은 줄을 둡니다. SwiftPM 리소스로 넣지 않고 Makefile이 `Contents/Resources`에 복사하므로, 코드는 `Text("…")`과 `String(localized: "…")`의 기본 번들(`Bundle.main`)을 씁니다. 새 문구를 쓰는 태스크는 두 표에 같은 키를 더합니다. 영어는 복수형이 필요 없는 문장(예: `Items: %lld`)으로 씁니다.
- 색은 강조 `#7A69FF`, 새 항목 `#FF9F2E`이고 나머지는 시스템 색입니다. 라이트와 다크는 시스템을 따릅니다.
- 크기는 사이드바 236pt, 오른쪽 칸 280pt, 격자 칸 사이 3pt, 칸 비율 16:9, 썸네일 크기 막대 120~360pt(기본 180pt)입니다. 창 폭이 980pt보다 좁으면 오른쪽 칸을 접습니다.
- 기기 일은 모두 `DeviceWorker`에서 합니다. `Session`, `HostTransport`, `TransferLedger`는 이 액터 밖으로 나가지 않고, 밖으로는 `Sendable` 값만 넘깁니다. Kit의 `isCancelled` 자리에는 `{ Task.isCancelled }`를 넘깁니다.
- Kit은 SwiftUI와 AppKit을 쓰지 않고 사용자 문구를 두지 않습니다. 앱 문구는 `AppErrorMessages`, `TransferText`와 문자열 표에만 둡니다.
- 파일 로그 `~/Library/Logs/Pullshot/pullshot.log`에는 파일 이름, 게임 이름, 경로, 일련번호를 쓰지 않습니다. 사용자가 이슈에 그대로 붙일 수 있어야 하기 때문입니다.
- 설정은 `SettingsKey`의 키로만 `UserDefaults`에 읽고 씁니다. 실행 인자 `-ledgerFolder <경로>`, `-importFolder <경로>`, `-demoAlbum YES`는 UserDefaults 인자 도메인으로 같은 키를 덮어씁니다(실기기 확인과 화면 확인용).
- 이 맥(Command Line Tools, Swift 6.3.3)에서는 `swift test`가 `no such module 'Testing'`으로 빌드되지 않습니다(2026-11-16 확인). Xcode를 고르기 전까지 아래 플래그를 붙입니다. 이 계획의 `swift test`는 모두 `swift test $TESTING`입니다.

  ```bash
  F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  TESTING="-Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib"
  ```

- 화면 자체는 테스트하지 않습니다. 화면 밖으로 뺄 수 있는 규칙(문자열 표, 로그 가림, 기기 고르기, 오류 문구, 보일 캡처, 고르기, 이름 미리보기, 결과 문구)만 `PullshotAppTests`에서 테스트합니다. 화면은 태스크마다 `make run-app` 뒤 `-demoAlbum YES`로 띄워 Orca computer-use(`computer-use` 스킬)로 보고, 실기기 화면은 Task 13에서 몰아서 봅니다. 이 맥은 원격 서버라 사용자에게 화면을 보여 줄 때는 화면 공유(`vnc://mac-studio`)를 안내합니다.

## Review Focus

1. 옮기는 중 케이블이 빠질 때: 받은 캡처는 기록에 남고, 결과에 받지 못한 수가 보이며, 안내 화면으로 돌아갔다가 다시 꽂으면 저절로 엽니다. Task 6의 `연 기기가 빠지면 남은 기기 중 첫 기기를 고른다`, Task 11의 `연결이 끊겨 받지 못한 수를 결과에 적는다`, Task 13 Step 5가 맡습니다.
2. 사이드바 범위나 필터를 바꾼 뒤 앞 선택이 남아 보이지 않는 캡처까지 내보낼 때: 보이지 않게 된 캡처는 고른 것에서 빠져야 합니다. Task 9의 `보이지 않게 된 캡처는 고른 것에서 뺀다`가 맡습니다.
3. 로그 파일에 게임 이름이나 파일 이름이 남아 이슈와 함께 공개될 때: Task 5의 `파일 이름이 든 오류도 로그에는 이름을 남기지 않는다`가 맡습니다.
4. 영어 표에 키가 빠지거나 서식 지정자(`%lld`, `%@`)가 달라 문장이 깨질 때: Task 1의 `두 언어 표의 키가 같다`, `같은 키는 서식 지정자가 같다`가 맡습니다.
5. 옮기는 중에 앱을 끝낼 때: 세션을 닫고 끝나야 다음 연결이 USB 리셋까지 가지 않습니다. 화면 밖 테스트로 잡을 수 없어 Task 12의 끝내기 처리와 Task 13 Step 6의 실기기 확인이 맡습니다.

## 미리 정한 것

스펙이 만드는 사람에게 맡겼거나 정하지 않은 부분입니다. 실행하는 사람은 이대로 짜고, 다르게 하려면 원장에 판정을 남깁니다.

- Xcode 프로젝트는 두지 않습니다. 빌드는 SwiftPM, 번들 조립과 서명은 Makefile입니다.
- 최근 옮긴 항목은 가져오기나 내보내기로 30일 안에 옮긴 캡처입니다. 처음 연결 답으로 남긴 기록은 세지 않습니다.
- 영상 길이는 보여 주지 않고 영상 표시(재생 아이콘)만 둡니다. ObjectInfo에 길이가 없고, 알려면 원본을 받아야 합니다(설계 11절).
- "새 항목 N개 가져오기"는 지금 보이는 캡처(사이드바 범위와 사진, 영상 필터) 가운데 새 항목을 가져옵니다. 게임을 보면 그 게임의 새 항목, 새 항목을 보면 전체 새 항목이라 설계 6.3과 같습니다.
- "게임 전체 내보내기"는 보이는 캡처를 모두 고르고, 오른쪽 칸은 고른 상태의 내보내기 설정으로 바뀝니다. 게임이 아닌 범위에서는 이름이 "모두 내보내기"입니다.
- 내보낼 기준 폴더에는 기본값이 없습니다. 처음 내보낼 때 폴더를 고르고 그 뒤로 기억합니다. 게임 이름 폴더 만들기(기본 켬)와 파일 이름 규칙(기본 원래 이름)도 기억합니다.
- 스페이스와 두 번 누르기는 기준 캡처(마지막으로 누른 캡처) 하나를 Quick Look으로 봅니다. 원본은 `$TMPDIR/Pullshot-preview/<게임 이름>/<파일 이름>`에 받고, 크기가 같은 파일이 있으면 다시 받지 않습니다. 이 폴더는 앱을 시작할 때와 끝낼 때 지웁니다. 미리보기는 옮긴 기록에 남기지 않습니다.
- 썸네일은 메모리(`NSCache`)와 디스크(`~/Library/Caches/Pullshot/Thumbnails/`)에 둡니다. 세션은 한 번에 한 트랜잭션이라 옮기는 동안의 썸네일 요청은 옮기기가 끝날 때까지 기다리고, 그사이 화면 밖으로 나간 칸의 요청은 취소돼 기기에 보내지 않습니다.
- 기기가 꽂히면 저절로 엽니다. 둘 이상이면 처음 찾은 것을 열고 기기 전환 단추로 바꿉니다. 연 기기가 빠지면 격자와 오른쪽 칸을 비우고 안내 화면으로 돌아갑니다.
- USB 리셋으로 남은 세션을 푼 뒤에는 "PC로 복사를 다시 켜 주세요" 안내를 두고, 스위치가 다시 PC로 복사 모드로 붙으면 저절로 다시 엽니다. 사진 전송 인터페이스가 늦게 생기는 경우를 위해 열기는 `noStillImageInterface`에서 0.5초 간격으로 5초까지 다시 시도합니다.
- 처음 연결 질문은 훑기를 마친 뒤 시트로 묻습니다. 답하지 않고 닫으면 다음 연결에서 다시 묻습니다(Kit의 `markAnswered`를 부르지 않음).
- 화살표는 보이는 순서대로 왼쪽과 오른쪽은 한 칸, 위와 아래는 한 줄(열 수만큼) 옮깁니다. 날짜 보기도 묶음 경계를 따지지 않고 같은 평평한 순서를 씁니다. 끝을 넘으면 첫 캡처나 마지막 캡처에서 멈춥니다.
- 날짜 보기에서 찍은 시각을 모르는 캡처는 맨 끝 "날짜 모름" 묶음에 둡니다.
- 앱을 끝낼 때 옮기는 중이면 취소하고 세션을 닫은 뒤 끝냅니다. 10초 안에 끝나지 않으면 그냥 끝냅니다.
- PTP와 USB 한 줄 기록(1단계 `trace`)은 설정의 "자세한 로그 남기기"를 켰을 때만 파일 로그에 씁니다. 한 번 훑는 데 수만 줄이 나오기 때문입니다. 연결, 훑기, 옮기기 결과와 오류는 늘 씁니다. 파일이 5MB를 넘으면 앱을 열 때 `pullshot.1.log`로 옮깁니다(앞 파일은 덮어씀).
- `-demoAlbum YES`로 열면 기기 없이 게임 세 개와 가짜 캡처, 색 썸네일로 화면을 채웁니다. 원격 맥에서 스위치 없이 화면을 확인하려는 것이고, 데모에서는 가져오기와 내보내기 단추를 끕니다.

## 파일 구조

```
App/Info.plist  App/ko.lproj/Localizable.strings  App/en.lproj/Localizable.strings  (Task 1)
Makefile                                         (Task 1)
Sources/PullshotKit/
  Library/LedgerIndex.swift                       (Task 2)
  Album/CaptureSummary.swift DateSections.swift   (Task 3)
  Library/ThumbnailCache.swift                    (Task 4)
  Console/ConsoleMonitor.swift                    (Task 5)
Sources/PullshotApp/
  PullshotApp.swift                               (Task 1, 12)
  Device/DeviceWorker.swift FileLog.swift         (Task 5)
  Library/LibraryModel.swift                      (Task 6, 이후 태스크가 더함)
  Library/ConsoleChoice.swift AppErrorMessages.swift SettingsKey.swift DemoAlbum.swift (Task 6)
  Library/ThumbnailStore.swift                    (Task 7)
  Library/CaptureQuery.swift                      (Task 8)
  Library/GridSelection.swift                     (Task 9)
  Library/ExportPreview.swift                     (Task 10)
  Library/TransferText.swift                      (Task 11)
  Views/LibraryWindow.swift Palette.swift         (Task 1)
  Views/ConnectionGuide.swift DeviceSwitcher.swift (Task 6)
  Views/CaptureGrid.swift CaptureCell.swift Thumbnail.swift (Task 7)
  Views/Sidebar.swift                             (Task 8)
  Views/Inspector.swift SettingsView.swift        (Task 10)
  Views/TransferPanel.swift FirstConnectSheet.swift (Task 11)
Tests/PullshotAppTests/
  Support/Fixtures.swift LocalizationTests.swift  (Task 1)
  FileLogTests.swift                              (Task 5)
  ConsoleChoiceTests.swift AppErrorMessagesTests.swift (Task 6)
  CaptureQueryTests.swift (Task 8)  GridSelectionTests.swift (Task 9)
  ExportPreviewTests.swift (Task 10)  TransferTextTests.swift (Task 11)
```

### Task 1: 앱 타깃 골격과 번들 조립

**Files:**
- Create: `App/Info.plist`, `App/ko.lproj/Localizable.strings`, `App/en.lproj/Localizable.strings`, `Sources/PullshotApp/PullshotApp.swift`, `Sources/PullshotApp/Views/LibraryWindow.swift`, `Sources/PullshotApp/Views/Palette.swift`, `Tests/PullshotAppTests/Support/Fixtures.swift`
- Modify: `Package.swift`, `Makefile`
- Test: `Tests/PullshotAppTests/LocalizationTests.swift`

**Interfaces:**
- Produces:
  - `Package.swift`: `.executable(name: "PullshotApp", targets: ["PullshotApp"])`, `.executableTarget(name: "PullshotApp", dependencies: ["PullshotKit"])`, `.testTarget(name: "PullshotAppTests", dependencies: ["PullshotApp", "PullshotKit"])`
  - `@main struct PullshotApp: App`(창은 `Window("Pullshot", id: "library") { LibraryWindow() }` 하나), `struct LibraryWindow: View`
  - `extension Color { static let pullshotAccent: Color; static let newCapture: Color }`(`#7A69FF`, `#FF9F2E`). 창 뿌리에 `.tint(.pullshotAccent)`
  - `make app`은 `dist/Pullshot.app`을 만들고 서명합니다. `make run-app`은 `make app` 뒤 `open dist/Pullshot.app`입니다.
  - 테스트 지원: `func stringsTable(_ language: String) throws -> [String: String]`(`#filePath`에서 리포 뿌리를 찾아 `App/<language>.lproj/Localizable.strings`를 `PropertyListSerialization`으로 읽음), Kit 테스트와 같은 모양의 `dateFixture(_:)`, `captureFixture(_:game:at:size:kind:handle:)`, `temporaryFolderFixture()`(`@testable import PullshotKit`, CLI 테스트 타깃처럼 이 타깃에 따로 둠)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`LocalizationTests`(`@Suite("문자열 표 테스트")`):

```swift
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
```

`formatSpecifiers(_:)`는 같은 파일의 private 함수입니다. `%lld`, `%ld`, `%d`, `%@`, `%f`(위치 지정 `%1$@` 포함)를 찾아 위치 지정을 뺀 종류를 정렬해 돌려줍니다. 영어에서 순서를 바꿔도 같다고 봅니다.

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter LocalizationTests`
Expected: 빌드 실패("no such module 'PullshotApp'")

- [ ] **Step 3: 앱 타깃, 문자열 표, 번들 조립을 만듭니다**

- 창은 아직 가운데에 "스위치를 연결해 주세요" 한 줄만 둡니다. 두 표에 이 키를 넣습니다(영어 `Connect your Switch`).
- `Info.plist`는 Global Constraints의 값과 `CFBundleExecutable` `Pullshot`, `CFBundlePackageType` `APPL`, `NSHighResolutionCapable` 참, `NSPrincipalClass` `NSApplication`입니다.
- `make app`: `swift build -c release --product PullshotApp`, `dist/Pullshot.app/Contents/{MacOS,Resources}`를 새로 만들고 `$(swift build -c release --show-bin-path)/PullshotApp`을 `Contents/MacOS/Pullshot`으로, `App/Info.plist`를 `Contents/`로, `App/*.lproj`를 `Contents/Resources/`로 복사한 뒤 `codesign --force --sign -`. `.PHONY`에 `app run-app`을 더합니다.

- [ ] **Step 4: 통과와 번들을 확인합니다**

Run: `swift test`, `make check`, `plutil -lint App/Info.plist App/*.lproj/Localizable.strings`, `make app && codesign -dv dist/Pullshot.app 2>&1 | grep Signature`
Expected: 테스트 통과, 위반 없음, 세 파일 `OK`, `Signature=adhoc`. `make run-app`으로 "Pullshot" 창에 안내 한 줄이 보입니다.

- [ ] **Step 5: 커밋합니다**

```bash
git add Package.swift Makefile App Sources/PullshotApp Tests/PullshotAppTests
git commit -m "앱 타깃 골격과 번들 조립 추가"
```

### Task 2: 옮긴 기록 색인을 값으로 나누기

화면은 격자 칸마다 새 항목인지 묻습니다. `TransferLedger`는 파일을 쥔 클래스라 `DeviceWorker` 밖으로 낼 수 없으므로, 질의를 `Sendable` 값으로 옮겨 화면이 들고 있게 합니다.

**Files:**
- Create: `Sources/PullshotKit/Library/LedgerIndex.swift`
- Modify: `Sources/PullshotKit/Library/TransferLedger.swift`, `FirstConnection.swift`, `Transfer.swift`(`TransferFailure`, `TransferSummary`를 `Sendable`로), `TransferItem.swift`(`ExportNaming: String, CaseIterable`), `Sources/pullshot/` 아래 호출하는 곳, `docs/glossary.md`(새 항목의 코드를 `LedgerIndex.newCaptures`로)
- Test: `Tests/PullshotKitTests/TransferLedgerTests.swift`

**Interfaces:**
- Produces:
  - `public struct LedgerIndex: Equatable, Sendable { public init(); public func isTransferred(_ capture: Capture, serialNumber: String) -> Bool; public func newCaptures(_ captures: [Capture], serialNumber: String) -> [Capture]; public func transferredAt(_ capture: Capture, serialNumber: String) -> Date?; public func lastTransfer(of captures: [Capture], serialNumber: String, calendar: Calendar = .current) -> LastTransfer?; public func recentlyTransferred(_ captures: [Capture], serialNumber: String, since: Date) -> [Capture] }`. 색인을 쌓는 `mutating func insert(_ entry: LedgerEntry)`와 `func hasRecords(for serialNumber: String) -> Bool`은 internal입니다.
  - `TransferLedger`: `public private(set) var index = LedgerIndex()`. 위 다섯 질의는 `TransferLedger`에서 지우고 호출하는 곳(Kit, CLI, 테스트 25곳쯤)을 `ledger.index.…`로 바꿉니다.
  - `public struct TransferFailure: Sendable`, `public struct TransferSummary: Sendable`, `public enum ExportNaming: String, Sendable, CaseIterable`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`TransferLedgerTests`에 `@Suite("색인")`을 더하고, 기존 테스트의 질의는 `ledger.index.…`로 바꿉니다(기대값은 그대로).

```swift
@Test func `최근 옮긴 항목은 기준 시각 뒤에 가져오거나 내보낸 캡처다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    let (old, recent, found) = (captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg"))
    try ledger.record([old], serialNumber: "S1", as: .imported, at: dateFixture("2026-10-16 23:59:59"))
    try ledger.record([recent], serialNumber: "S1", as: .exported, at: dateFixture("2026-10-17 00:00:00"))
    try ledger.record([found], serialNumber: "S1", as: .foundInFolder, at: dateFixture("2026-11-10 12:00:00"))

    let since = dateFixture("2026-10-17 00:00:00")
    #expect(ledger.index.recentlyTransferred([old, recent, found], serialNumber: "S1", since: since).map(\.filename)
        == ["b.jpg"])
}

@Test func `꺼내 둔 색인은 뒤에 남긴 기록으로 바뀌지 않는다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    let before = ledger.index
    try ledger.record([captureFixture("a.jpg")], serialNumber: "S1", as: .imported)

    #expect(!before.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
    #expect(ledger.index.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferLedgerTests`
Expected: 컴파일 실패("value of type 'TransferLedger' has no member 'index'")

- [ ] **Step 3: `LedgerIndex`를 만들고 질의를 옮깁니다**

`recorded`와 `lastTransferDates`, `index(_:)`의 본문을 `LedgerIndex`로 옮깁니다. `recentlyTransferred`는 `transferredAt`이 `since`와 같거나 뒤인 캡처를 입력 순서대로 돌려줍니다. 처음 연결 답(`foundInFolder`, `markedAll`)은 `transferredAt`이 nil이라 저절로 빠집니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests docs/glossary.md
git commit -m "옮긴 기록 색인을 값으로 분리"
```

### Task 3: 캡처 요약과 날짜 묶기

**Files:**
- Create: `Sources/PullshotKit/Album/CaptureSummary.swift`, `Sources/PullshotKit/Album/DateSections.swift`
- Modify: `Tests/PullshotKitTests/Support/Fixtures.swift`(`calendarFixture()`)
- Test: `Tests/PullshotKitTests/CaptureSummaryTests.swift`, `Tests/PullshotKitTests/DateSectionsTests.swift`

**Interfaces:**
- Produces:
  - `public struct CaptureSummary: Equatable, Sendable { public var photoCount: Int; public var videoCount: Int; public var totalSize: UInt64; public var first: Date?; public var last: Date?; public init(_ captures: [Capture]) }`. `totalSize`는 크기를 아는 캡처의 합입니다. 툴바 부제와 오른쪽 칸 정보가 씁니다.
  - `public struct DateSections: Equatable, Sendable { public struct Day: Equatable, Sendable, Identifiable { public var start: Date; public var captures: [Capture]; public var id: Date }; public struct Month: Equatable, Sendable, Identifiable { public var start: Date; public var days: [Day]; public var id: Date }; public var months: [Month]; public var undated: [Capture]; public init(_ captures: [Capture], calendar: Calendar = .current) }`. 달, 날, 날 안의 캡처 모두 최근 것이 먼저입니다(`Capture.newestFirst`).
  - 테스트 지원: `func calendarFixture() -> Calendar`(그레고리력, Asia/Seoul)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Test func `사진과 영상 수, 아는 크기의 합, 처음과 마지막 찍은 때를 센다`() {
    let summary = CaptureSummary([
        captureFixture("a.jpg", at: "2026-11-01 09:00:00", size: 100),
        captureFixture("b.mp4", at: "2026-11-14 23:40:00", size: 300, kind: .video),
        captureFixture("c.jpg", at: nil, size: nil),
    ])
    #expect(summary.photoCount == 2)
    #expect(summary.videoCount == 1)
    #expect(summary.totalSize == 400)
    #expect(summary.first == dateFixture("2026-11-01 09:00:00"))
    #expect(summary.last == dateFixture("2026-11-14 23:40:00"))
}
```

`DateSectionsTests`(`@Suite("DateSections 테스트")`):

```swift
@Test func `달과 날로 묶고 최근 것이 먼저다`() {
    let sections = DateSections([
        captureFixture("a.jpg", at: "2026-10-31 13:20:00"),
        captureFixture("b.jpg", at: "2026-11-06 22:02:00"),
        captureFixture("c.jpg", at: "2026-11-06 23:48:00"),
        captureFixture("d.jpg", at: "2026-11-02 14:40:00"),
    ], calendar: calendarFixture())
    #expect(sections.months.map { $0.days.map { $0.captures.map(\.filename) } }
        == [[["c.jpg", "b.jpg"], ["d.jpg"]], [["a.jpg"]]])
    #expect(sections.months[0].start == dateFixture("2026-11-01 00:00:00"))
    #expect(sections.months[0].days[1].start == dateFixture("2026-11-02 00:00:00"))
}

@Test func `자정 직전과 자정은 다른 날이다`() {
    let sections = DateSections([
        captureFixture("a.jpg", at: "2026-11-06 23:59:59"),
        captureFixture("b.jpg", at: "2026-11-07 00:00:00"),
    ], calendar: calendarFixture())
    #expect(sections.months[0].days.map { $0.captures.map(\.filename) } == [["b.jpg"], ["a.jpg"]])
}

@Test func `찍은 시각을 모르는 캡처는 날짜 묶음 밖에 따로 둔다`() {
    let sections = DateSections([captureFixture("x.jpg", at: nil), captureFixture("a.jpg")], calendar: calendarFixture())
    #expect(sections.months.count == 1)
    #expect(sections.undated.map(\.filename) == ["x.jpg"])
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter "CaptureSummaryTests|DateSectionsTests"`
Expected: 컴파일 실패("cannot find 'CaptureSummary' in scope")

- [ ] **Step 3: `CaptureSummary`와 `DateSections`를 만듭니다**

날과 달의 시작은 `calendar.startOfDay(for:)`와 `calendar.dateInterval(of: .month, for:)`로 정합니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "캡처 요약과 날짜 묶기 추가"
```

### Task 4: 썸네일 디스크 캐시

스위치 2 앨범은 캡처가 3천 개가 넘고 GetThumb 한 번에 15~19KB입니다(hardware-notes). 연결할 때마다 다시 받지 않도록 디스크에 둡니다.

**Files:**
- Create: `Sources/PullshotKit/Library/ThumbnailCache.swift`
- Test: `Tests/PullshotKitTests/ThumbnailCacheTests.swift`

**Interfaces:**
- Consumes: `CaptureKey`(2단계), `Capture.isSafeFilename`
- Produces: `public struct ThumbnailCache: Sendable { public static let defaultDirectory: URL; public init(directory: URL = defaultDirectory); public func data(for key: CaptureKey) -> Data?; public func store(_ data: Data, for key: CaptureKey) }`. 기본 폴더는 `URL.cachesDirectory.appending(path: "Pullshot/Thumbnails")`입니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`@Suite("ThumbnailCache 테스트")`. 캐시마다 `ThumbnailCache(directory: temporaryFolderFixture())`를 씁니다.

```swift
@Test func `저장한 썸네일을 같은 열쇠로 다시 읽는다`() {
    let key = CaptureKey(captureFixture("a.jpg"), serialNumber: "S1")
    cache.store(Data([1, 2, 3]), for: key)
    #expect(cache.data(for: key) == Data([1, 2, 3]))
}

@Test func `크기가 다르면 다른 캡처로 본다`() {
    cache.store(Data([1]), for: CaptureKey(captureFixture("a.jpg", size: 5), serialNumber: "S1"))
    #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", size: 6), serialNumber: "S1")) == nil)
}

@Test func `폴더 밖 캡처와 기타 폴더 캡처를 섞지 않는다`() {
    cache.store(Data([1]), for: CaptureKey(captureFixture("a.jpg", game: nil), serialNumber: "S1"))
    #expect(cache.data(for: CaptureKey(captureFixture("a.jpg", game: "기타"), serialNumber: "S1")) == nil)
}

@Test func `경로로 쓸 수 없는 일련번호면 저장하지 않는다`() {
    let key = CaptureKey(captureFixture("a.jpg"), serialNumber: "../S1")
    cache.store(Data([1]), for: key)
    #expect(cache.data(for: key) == nil)
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter ThumbnailCacheTests`
Expected: 컴파일 실패("cannot find 'ThumbnailCache' in scope")

- [ ] **Step 3: `ThumbnailCache`를 만듭니다**

파일 자리는 `<directory>/<일련번호>/<폴더>/<파일 이름>-<크기>`입니다. 폴더는 `gameFolder`가 있으면 `g-<gameFolder>`, nil이면 `root`이고, 크기를 모르면 `unknown`입니다. 일련번호가 `Capture.isSafeFilename`을 통과하지 못하면 읽지도 쓰지도 않습니다. 쓰기는 `.atomic`이고 실패는 `Log.library`에 남기기만 합니다(경로는 private).

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "썸네일 디스크 캐시 추가"
```

### Task 5: 기기 일꾼, 기기 감시, 파일 로그

**Files:**
- Create: `Sources/PullshotKit/Console/ConsoleMonitor.swift`, `Sources/PullshotApp/Device/DeviceWorker.swift`, `Sources/PullshotApp/Device/FileLog.swift`
- Modify: `Sources/PullshotKit/Console/ConsoleLocator.swift`(찾기 사전 만들기를 함께 씀), `Sources/PullshotKit/Support/Log.swift`(`app` 분류)
- Test: `Tests/PullshotAppTests/FileLogTests.swift`, `Tests/PullshotKitTests/ConsoleTests.swift`(감시 만들기)

**Interfaces:**
- Consumes: `HostTransport`, `Session.open()`, `AlbumScanner`, `Transfer`, `TransferLedger`, `answerFirstConnectQuestion`, `ThumbnailCache`는 쓰지 않음(Task 7의 `ThumbnailStore`가 씀), `LedgerIndex`(Task 2)
- Produces:
  - Kit: `public final class ConsoleMonitor { public init(); public var changes: AsyncStream<Void> }`, `public static let app: Logger`(Log), internal `ConsoleLocator.matchingDictionary(productIDs: [UInt16]) -> CFMutableDictionary`
  - `final class FileLog: Sendable { static let defaultFile: URL; static let maxSize = 5_000_000; init(file: URL = defaultFile); func write(_ line: String); static func describe(_ error: any Error) -> String }`
  - `actor DeviceWorker { init(ledgerDirectory: URL, log: FileLog) throws; var index: LedgerIndex { get }; var serialNumber: String? { get }; func open(_ console: AttachedConsole, isVerbose: Bool) throws -> DeviceInfo; func scan(progress: @escaping @Sendable (Int) -> Void) throws -> AlbumScan; func needsFirstConnectQuestion() -> Bool; func answerFirstConnectQuestion(_ answer: FirstConnectAnswer, captures: [Capture]) throws -> Int; func thumbnail(of capture: Capture) throws -> Data; func transfer(_ items: [TransferItem], as kind: TransferKind, progress: @escaping @Sendable (TransferProgress) -> Void) throws -> TransferSummary; func preview(_ capture: Capture) throws -> URL; static let previewFolder: URL; func close() }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`FileLogTests`(`@Suite("FileLog 테스트")`):

```swift
@Test func `파일 이름이 든 오류도 로그에는 이름을 남기지 않는다`() {
    #expect(FileLog.describe(SessionError.destinationExists("젤다.jpg")) == "destinationExists")
    #expect(FileLog.describe(FolderMatchError.unreadableFolder(URL(filePath: "/Users/a/사진"))) == "unreadableFolder")
    #expect(FileLog.describe(CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: "/Users/a/b.jpg"]))
        == "NSCocoaErrorDomain 513")
}

@Test func `기기 오류는 종류와 코드를 남긴다`() {
    #expect(FileLog.describe(SessionError.transport(.disconnected)) == "transport(disconnected)")
    #expect(FileLog.describe(SessionError.response(PTP.Response(rawValue: 0x2002), operation: .getObject))
        == "response(0x2002, 0x1009)")
    #expect(FileLog.describe(ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad"))
        == "heldByAnotherApp(0xE00002C9, ptpcamerad)")
}

@Test func `열 때 5MB를 넘은 로그는 앞 파일로 옮기고 새로 쓴다`() throws {
    let folder = temporaryFolderFixture()
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "pullshot.log")
    try Data(count: 5_000_001).write(to: file)

    FileLog(file: file).write("열림")

    #expect(try Data(contentsOf: folder.appending(path: "pullshot.1.log")).count == 5_000_001)
    #expect(try String(contentsOf: file, encoding: .utf8).hasSuffix(" 열림\n"))
}
```

`ConsoleTests`에 더합니다.

```swift
@Test func `기기가 없어도 감시를 만들고 놓을 수 있다`() {
    var monitor: ConsoleMonitor? = ConsoleMonitor()
    _ = monitor?.changes
    monitor = nil
    #expect(monitor == nil)
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter "FileLogTests|ConsoleTests"`
Expected: 컴파일 실패("cannot find 'FileLog' in scope")

- [ ] **Step 3: `ConsoleMonitor`를 만듭니다**

`IONotificationPortCreate`로 포트를 만들고 `IONotificationPortSetDispatchQueue`로 전용 큐에 붙입니다. `kIOFirstMatchNotification`과 `kIOTerminatedNotification`을 각각 `IOServiceAddMatchingNotification`으로 겁니다. 이 호출이 사전의 참조 하나를 가져가므로 사전은 알림마다 새로 만듭니다. 제품 ID는 PC로 복사 모드와 대기 상태를 모두 넣습니다(`ConsoleModel.all`의 `productID`와 `idleProductID`). 알림을 받으면 반복자를 끝까지 비우고 `changes`에 한 번 알립니다. 처음 건 직후의 비우기는 알림을 켜는 일이라 알리지 않습니다. `deinit`에서 반복자와 포트를 놓고 스트림을 끝냅니다.

- [ ] **Step 4: `FileLog`를 만듭니다**

- 줄 형식은 `<ISO 8601 시각(밀리초)> <내용>\n`이고, `Mutex`(Synchronization)로 감싼 `FileHandle`에 한 줄씩 덧붙입니다. 쓰지 못해도 앱을 멈추지 않고 `Log.app`에 남깁니다.
- `describe`는 `SessionError`, `TransportError`, `ConsoleAccessError`, `FolderMatchError`를 위 테스트 꼴(case 이름, 코드는 `0x%04X` 또는 `0x%08X`, 이름과 경로 값은 뺌)로 쓰고, 그 밖은 `NSError`의 `domain code`로 씁니다.

- [ ] **Step 5: `DeviceWorker`를 만듭니다**

- 실행기는 `DispatchSerialQueue(label: "com.parkgiraffe.Pullshot.device")`이고 `nonisolated var unownedExecutor`로 돌려줍니다. 블로킹 USB 읽기가 협력 스레드 풀을 막지 않게 하려는 것입니다.
- `open`: 앞 세션을 닫고, `HostTransport`를 `noStillImageInterface`에서 0.5초 간격으로 5초까지 다시 시도해 연 뒤 `Session.open()`을 부릅니다. `isVerbose`면 두 곳의 `trace`에 `log.write`를 넘깁니다. `SessionError.needsUSBReset`이면 전송을 닫고 그대로 던집니다. 연결한 기기 이름과 펌웨어를 로그에 씁니다(일련번호는 쓰지 않음).
- 세션이 필요한 메서드는 세션이 없으면 `SessionError.invalidated`를 던집니다.
- `thumbnail`은 기기에 보내기 전에 `Task.isCancelled`면 `CancellationError`를 던집니다.
- `transfer`의 진행은 `bytes == 0`일 때와 앞 알림에서 0.1초가 지났을 때만 넘깁니다. 끝나면 저장, 건너뜀, 실패, 받지 못함 수를 로그에 씁니다.
- `preview`는 미리 정한 것의 자리에 `Session.download`로 받고 기록에 남기지 않습니다.
- 기록 폴더는 생성자 인자로 받습니다. 기본값과 `-ledgerFolder`는 Task 6에서 정합니다.

- [ ] **Step 6: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 7: 커밋합니다**

```bash
git add Sources Tests
git commit -m "DeviceWorker, ConsoleMonitor, 파일 로그 추가"
```

### Task 6: 연결 흐름과 안내 화면

**Files:**
- Create: `Sources/PullshotApp/Library/LibraryModel.swift`, `ConsoleChoice.swift`, `AppErrorMessages.swift`, `SettingsKey.swift`, `DemoAlbum.swift`, `Sources/PullshotApp/Views/ConnectionGuide.swift`, `Sources/PullshotApp/Views/DeviceSwitcher.swift`
- Modify: `Sources/PullshotApp/PullshotApp.swift`, `Sources/PullshotApp/Views/LibraryWindow.swift`, 문자열 표 두 개
- Test: `Tests/PullshotAppTests/ConsoleChoiceTests.swift`, `Tests/PullshotAppTests/AppErrorMessagesTests.swift`

**Interfaces:**
- Consumes: `DeviceWorker`, `FileLog`(Task 5), `ConsoleMonitor`, `ConsoleLocator.attached()`, `ConsoleLocator.idle()`, `LedgerIndex`(Task 2)
- Produces:
  - `enum ConsoleChoice { static func next(current: AttachedConsole?, attached: [AttachedConsole]) -> AttachedConsole? }`. 같은 기기인지는 `registryID`로 봅니다. 다시 꽂으면 바뀌므로 새 기기로 봅니다.
  - `enum AppErrorMessages { static func message(for error: any Error) -> String }`
  - `enum SettingsKey: String { case ledgerFolder, importFolder, exportFolder, makesGameFolder, exportNaming, thumbnailSize, viewMode, isVerboseLog, demoAlbum }`
  - `@MainActor @Observable final class LibraryModel { enum Connection: Equatable { case searching; case notInTransferMode(String); case reattachNeeded; case connecting(AttachedConsole); case scanning(AttachedConsole, seen: Int); case ready(AttachedConsole, DeviceInfo); case failed(AttachedConsole, message: String) }; private(set) var connection: Connection; private(set) var consoles: [AttachedConsole]; private(set) var captures: [Capture]; private(set) var index: LedgerIndex; private(set) var serialNumber: String?; private(set) var isDemo: Bool; var isAskingFirstConnect: Bool; let worker: DeviceWorker; init(worker: DeviceWorker); func watchConsoles() async; func choose(_ console: AttachedConsole) async; func retry() async }`
  - `enum DemoAlbum { static let console: AttachedConsole; static let info: DeviceInfo; static func captures(now: Date) -> [Capture] }`
  - 테스트 지원: `func consoleFixture(_ registryID: UInt64, model: ConsoleModel = .switch2) -> AttachedConsole`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`ConsoleChoiceTests`(`@Suite("ConsoleChoice 테스트")`):

```swift
@Test func `연 기기가 그대로 꽂혀 있으면 바꾸지 않는다`() {
    #expect(ConsoleChoice.next(current: consoleFixture(1), attached: [consoleFixture(2), consoleFixture(1)])
        == consoleFixture(1))
}

@Test func `연 기기가 빠지면 남은 기기 중 첫 기기를 고른다`() {
    #expect(ConsoleChoice.next(current: consoleFixture(1), attached: [consoleFixture(2)]) == consoleFixture(2))
}

@Test func `연 기기가 없으면 처음 찾은 기기를 고른다`() {
    #expect(ConsoleChoice.next(current: nil, attached: [consoleFixture(1), consoleFixture(2)]) == consoleFixture(1))
}

@Test func `꽂힌 기기가 없으면 고르지 않는다`() {
    #expect(ConsoleChoice.next(current: consoleFixture(1), attached: []) == nil)
}
```

`AppErrorMessagesTests`(`@Suite("AppErrorMessages 테스트")`). 테스트 번들에는 문자열 표가 없어 한국어 원문이 그대로 나옵니다.

```swift
@Test func `시스템 사진 도우미가 기기를 잡고 있으면 미리보기와 사진 앱을 닫으라고 한다`() {
    #expect(AppErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9, owner: "ptpcamerad"))
        == "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 닫고 다시 시도해 주세요.")
}

@Test func `다른 앱이 기기를 잡고 있으면 그 앱 이름을 알려 준다`() {
    #expect(AppErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C5, owner: "Tethersnap"))
        == "Tethersnap 앱이 스위치를 쓰고 있습니다. 그 앱을 닫고 다시 시도해 주세요.")
}

@Test func `케이블이 빠지면 연결이 끊겼다고 알린다`() {
    #expect(AppErrorMessages.message(for: SessionError.transport(.disconnected))
        == "스위치 연결이 끊겼습니다. 케이블을 확인해 주세요.")
}

@Test func `알 수 없는 접근 오류는 코드를 보여 준다`() {
    #expect(AppErrorMessages.message(for: ConsoleAccessError.other(code: 0xE000_02BC))
        == "스위치에 연결하지 못했습니다(오류 0xE00002BC).")
}

@Test func `찾을 폴더를 열 수 없으면 폴더 이름과 권한을 알려 준다`() {
    #expect(AppErrorMessages.message(for: FolderMatchError.unreadableFolder(URL(filePath: "/tmp/없는 폴더")))
        == "폴더를 열 수 없습니다: 없는 폴더. 폴더가 있는지, 읽을 권한이 있는지 확인해 주세요.")
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter "ConsoleChoiceTests|AppErrorMessagesTests"`
Expected: 컴파일 실패("cannot find 'ConsoleChoice' in scope")

- [ ] **Step 3: `ConsoleChoice`, `AppErrorMessages`, `SettingsKey`를 만듭니다**

`AppErrorMessages`는 CLI `ErrorMessages`의 갈래를 따르고, 위 테스트 문구와 함께 이 문구를 둡니다. 시간 초과 "스위치가 응답하지 않습니다. PC로 복사 화면이 켜져 있는지 확인해 주세요.", 사진 전송 기능 없음 "스위치의 사진 전송 기능을 찾지 못했습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요.", 같은 이름 "이미 같은 이름의 파일이 있습니다: %@", 크기 다름 "받은 크기가 스위치가 알린 크기와 달라 저장하지 않았습니다.", 취소(`SessionError.cancelled`, `CancellationError`) "취소했습니다.", 그 밖 "스위치와 통신하지 못했습니다. 도움말 메뉴의 로그 파일 보기에서 자세한 내용을 볼 수 있습니다."

- [ ] **Step 4: `LibraryModel`의 연결 흐름을 만듭니다**

- `watchConsoles()`: 처음 한 번 살피고, 그 뒤 `ConsoleMonitor().changes`마다 다시 살핍니다. 살피기는 `consoles = ConsoleLocator.attached()`를 받고 `ConsoleChoice.next`로 고릅니다.
  - 고른 기기가 지금 연 기기면 그대로 둡니다. 다르면 하던 일(훑기, 옮기기, 미리보기 작업)을 취소하고 `worker.close()` 뒤 그 기기를 엽니다.
  - 고를 기기가 없으면 하던 일을 취소하고 `worker.close()`, `captures`를 비웁니다. 그리고 `reattachNeeded`였으면 그대로 두고, `ConsoleLocator.idle()`에 기기가 있으면 `notInTransferMode(이름)`, 없으면 `searching`입니다.
- 열기: `connecting` → `worker.open` → `scanning(seen:)`(진행은 100개마다 반영) → `index`, `serialNumber`, `isAskingFirstConnect`(`needsFirstConnectQuestion`) → `ready`. `needsUSBReset`이면 `reattachNeeded`, 그 밖의 오류는 `failed(기기, AppErrorMessages 문구)`이고 로그에 `FileLog.describe`를 씁니다.
- `retry()`는 `failed`의 기기를 다시 엽니다. `choose(_:)`는 기기 전환 단추가 부릅니다.
- `PullshotApp`은 `FileLog`와 `DeviceWorker(ledgerDirectory:)`를 만듭니다. 기록 폴더는 `UserDefaults`의 `ledgerFolder`가 있으면 그것, 없으면 `TransferLedger.defaultDirectory`입니다. 기록을 열지 못하면 창에 "옮긴 기록을 열지 못했습니다" 한 줄만 두고 기기를 열지 않습니다.
- `demoAlbum`이 참이면 기기를 감시하지 않고 `ready(DemoAlbum.console, DemoAlbum.info)`, `captures = DemoAlbum.captures(now:)`, `isDemo = true`로 엽니다. 데모 캡처는 게임 세 개(그중 하나는 이름이 두 줄로 넘치게 긴 것)에 사진과 영상을 섞어 60개쯤, 최근 두 달에 흩어 둡니다.

- [ ] **Step 5: 안내 화면과 기기 칸을 만듭니다**

- `LibraryWindow`는 `NavigationSplitView`입니다. 사이드바 위에 `DeviceSwitcher`, 상세 칸은 `ready`가 아니면 `ConnectionGuide`, `ready`면 이 태스크에서는 "캡처 N개" 한 줄입니다. 창이 뜨면 `.task { await model.watchConsoles() }`.
- `ConnectionGuide` 문구: `searching` "스위치를 연결해 주세요"와 두 단계("독이 아니라 본체 아래쪽 USB-C 포트에 데이터 케이블을 연결합니다.", "본체 설정의 데이터 관리에서 PC로 복사를 켭니다."), `notInTransferMode` "%@가 연결돼 있지만 PC로 복사 모드가 아닙니다."와 둘째 단계, `reattachNeeded` "남은 연결을 풀려고 스위치를 USB에서 다시 연결했습니다. 본체에서 PC로 복사를 다시 켜 주세요.", `connecting` 진행 표시와 "연결하는 중", `scanning` "앨범을 읽는 중 · %lld개", `failed` 문구와 "다시 시도" 단추.
- `DeviceSwitcher`(시안 ①): 28pt 강조색 둥근 사각형 안 `gamecontroller` 아이콘, 기기 이름, 둘째 줄 상태(초록 점과 "연결됨 · <펌웨어>", "연결하는 중", "연결된 스위치 없음"). 기기가 둘 이상이면 오른쪽 `chevron.up.chevron.down` 메뉴로 고르고, 같은 이름이 둘이면 USB 일련번호 끝 네 자리를 괄호로 붙입니다. `isExperimental`이면 "실험적 지원" 캡슐과 도움말 "확인하지 못한 기기입니다. 문제가 있으면 설정에서 자세한 로그를 켜고 다시 해 본 뒤, 로그 파일과 함께 GitHub 이슈로 알려 주세요."를 둡니다.

- [ ] **Step 6: 통과와 화면을 확인합니다**

Run: `swift test`, `make check`, `make run-app`, `open dist/Pullshot.app --args -demoAlbum YES`
Expected: 테스트 통과, 위반 없음. 스위치 없이 열면 안내 화면과 "연결된 스위치 없음", 데모로 열면 "캡처 N개"와 "연결됨 · 23.5.0"이 보입니다.

- [ ] **Step 7: 커밋합니다**

```bash
git add App Sources Tests
git commit -m "연결 흐름과 연결 안내 화면 추가"
```

### Task 7: 썸네일과 격자

**Files:**
- Create: `Sources/PullshotApp/Library/ThumbnailStore.swift`, `Sources/PullshotApp/Views/CaptureGrid.swift`, `CaptureCell.swift`, `Thumbnail.swift`
- Modify: `LibraryWindow.swift`, `LibraryModel.swift`, 문자열 표 두 개

**Interfaces:**
- Consumes: `DeviceWorker.thumbnail(of:)`(Task 5), `ThumbnailCache`(Task 4), `DateSections`, `CaptureSummary`(Task 3), `LedgerIndex.isTransferred`(Task 2)
- Produces:
  - `@MainActor @Observable final class ThumbnailStore { init(worker: DeviceWorker, cache: ThumbnailCache = ThumbnailCache()); var serialNumber: String?; var isDemo: Bool; func image(for capture: Capture) async -> NSImage? }`. `serialNumber`가 바뀌면 메모리 캐시를 비웁니다.
  - `enum ViewMode: String, CaseIterable { case newest, byDate }`
  - `struct CaptureGrid: View { let captures: [Capture]; let viewMode: ViewMode; let cellWidth: CGFloat; let isNew: (Capture) -> Bool }`(고르기는 Task 9에서 더함), `struct CaptureCell: View`, `struct Thumbnail: View { let capture: Capture }`

- [ ] **Step 1: `ThumbnailStore`를 만듭니다**

메모리(`NSCache<NSString, NSImage>`, 열쇠 `capture.id`) → 디스크(`ThumbnailCache`, `CaptureKey`) → `worker.thumbnail(of:)` 순으로 찾고, 기기에서 받은 것은 디스크에 둡니다. 실패와 취소는 nil입니다. `isDemo`면 기기 대신 파일 이름으로 색상(hue)을 정한 단색 그림을 만듭니다.

- [ ] **Step 2: 격자와 칸을 만듭니다**

- `CaptureCell`(시안 ⑥): `Thumbnail`을 16:9로 채워 자르고, 새 항목이면 왼쪽 위에 8pt `newCapture` 점(흰 테두리 1.5pt), 영상이면 왼쪽 아래에 흰 `play.fill`(그림자)을 둡니다.
- `Thumbnail`은 회색 바탕 위에 `.task(id: capture.id)`로 그림을 받아 얹습니다. 칸이 화면을 벗어나면 이 작업이 취소돼 기기에 보내지 않습니다.
- `CaptureGrid`: `newest`는 `LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: 3)], spacing: 3)` 하나, `byDate`는 `DateSections`로 달 제목(큰 글씨 "11월"과 "2026년 · 사진 12 · 영상 1"), 날 제목("6일 금요일"과 시각 범위 "밤 10:02 ~ 11:48"), 날마다 같은 격자이고 끝에 "날짜 모름" 묶음입니다. 0개인 종류는 제목에서 뺍니다. 시각 범위는 `DateFormatter.dateFormat(fromTemplate: "Bhmm", options: 0, locale: .current)` 꼴(한국어에서 "밤 10:02")을 씁니다.
- 툴바에 썸네일 크기 막대(`minus.magnifyingglass` 120 … 360 `plus.magnifyingglass`)와 보기 전환(`Picker` segmented "최신순", "날짜")을 두고 `@AppStorage`(`thumbnailSize`, `viewMode`)에 둡니다.
- `ready`일 때 상세 칸은 `ScrollView { CaptureGrid(captures: model.captures, …) }`입니다. 새 항목 판정은 `!model.index.isTransferred(capture, serialNumber:)`입니다. 연결하면 `ThumbnailStore.serialNumber`를 맞춥니다.

- [ ] **Step 3: 확인합니다**

Run: `swift test`, `make check`, `make app && open dist/Pullshot.app --args -demoAlbum YES`
Expected: 테스트 통과, 위반 없음. 데모 격자가 16:9 칸과 3pt 틈으로 채워지고, 막대로 칸 크기가 바뀌며, 날짜 보기에서 달과 날 제목이 보입니다. 라이트와 다크 모두 봅니다.

- [ ] **Step 4: 커밋합니다**

```bash
git add App Sources
git commit -m "썸네일과 캡처 격자 추가"
```

### Task 8: 사이드바와 보기 범위

**Files:**
- Create: `Sources/PullshotApp/Library/CaptureQuery.swift`, `Sources/PullshotApp/Views/Sidebar.swift`
- Modify: `LibraryModel.swift`, `LibraryWindow.swift`, 문자열 표 두 개
- Test: `Tests/PullshotAppTests/CaptureQueryTests.swift`

**Interfaces:**
- Consumes: `Game.games(in:)`, `Capture.gameName`, `LedgerIndex.newCaptures`, `LedgerIndex.recentlyTransferred`(Task 2), `CaptureSummary`(Task 3), `Thumbnail`(Task 7)
- Produces:
  - `enum LibraryScope: Hashable { case all, new, videos, recentlyTransferred; case game(String) }`
  - `enum KindFilter: String, CaseIterable { case all, photos, videos }`
  - `struct CaptureQuery { static let recentPeriod: TimeInterval = 30 * 86_400; var scope: LibraryScope; var kind: KindFilter; func captures(in captures: [Capture], index: LedgerIndex, serialNumber: String, now: Date) -> [Capture] }`. 결과는 입력 순서(훑기의 최근 것 먼저)를 지킵니다.
  - `LibraryModel`: `var scope: LibraryScope = .all`, `var kind: KindFilter = .all`, `var gameSearch = ""`, `var visibleCaptures: [Capture] { get }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`CaptureQueryTests`(`@Suite("CaptureQuery 테스트")`). 기록은 `TransferLedger(directory: temporaryFolderFixture())`에 남기고 `ledger.index`를 넘깁니다.

```swift
@Test func `새 항목 범위는 기록에 없는 캡처만 보인다`() throws {
    let (old, new) = (captureFixture("a.jpg"), captureFixture("b.jpg"))
    try ledger.record([old], serialNumber: "S1", as: .imported)
    #expect(CaptureQuery(scope: .new, kind: .all)
        .captures(in: [new, old], index: ledger.index, serialNumber: "S1", now: .now).map(\.filename) == ["b.jpg"])
}

@Test func `최근 옮긴 항목은 30일 안에 가져오거나 내보낸 캡처다`() throws {
    let (a, b) = (captureFixture("a.jpg"), captureFixture("b.jpg"))
    try ledger.record([a], serialNumber: "S1", as: .imported, at: dateFixture("2026-10-16 23:59:59"))
    try ledger.record([b], serialNumber: "S1", as: .exported, at: dateFixture("2026-10-17 00:00:00"))
    let now = dateFixture("2026-11-16 00:00:00")
    #expect(CaptureQuery(scope: .recentlyTransferred, kind: .all)
        .captures(in: [a, b], index: ledger.index, serialNumber: "S1", now: now).map(\.filename) == ["b.jpg"])
}

@Test func `게임 범위에 영상 필터를 더하면 그 게임의 영상만 보인다`() {
    let captures = [
        captureFixture("a.mp4", kind: .video),
        captureFixture("b.jpg"),
        captureFixture("c.mp4", game: "마리오 카트 월드", kind: .video),
    ]
    #expect(CaptureQuery(scope: .game("젤다무쌍 봉인전기"), kind: .videos)
        .captures(in: captures, index: LedgerIndex(), serialNumber: "S1", now: .now).map(\.filename) == ["a.mp4"])
}

@Test func `기타 범위는 폴더 밖 캡처와 기타 폴더 캡처를 함께 보인다`() {
    let captures = [captureFixture("a.jpg", game: nil), captureFixture("b.jpg", game: "기타"), captureFixture("c.jpg")]
    #expect(CaptureQuery(scope: .game("기타"), kind: .all)
        .captures(in: captures, index: LedgerIndex(), serialNumber: "S1", now: .now).map(\.filename)
        == ["a.jpg", "b.jpg"])
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter CaptureQueryTests`
Expected: 컴파일 실패("cannot find 'CaptureQuery' in scope")

- [ ] **Step 3: `CaptureQuery`를 만들고 모델에 잇습니다**

`visibleCaptures`는 `CaptureQuery(scope:kind:)`에 `captures`, `index`, `serialNumber ?? ""`, `.now`를 넘긴 값입니다. 범위를 바꾸면 격자 스크롤을 맨 위로 돌립니다(`ScrollView`에 `.id(scope)`).

- [ ] **Step 4: 사이드바를 만듭니다**

- `List(selection:)`에 고정 항목(②)을 둡니다. "모든 항목"(`square.grid.2x2`), "새 항목"(`tray.and.arrow.down`, 개수는 `newCapture` 캡슐), "영상"(`video`), "최근 옮긴 항목"(`clock`)이고 오른쪽에 개수를 둡니다. 개수는 범위마다 `CaptureQuery(…, kind: .all)`로 셉니다.
- 그 아래 "게임 (N)" 묶음(③): `Game.games(in: captures)`를 `gameSearch`로 좁힌 것(`localizedStandardContains`)입니다. 줄마다 22pt 둥근 `Thumbnail`(그 게임의 첫 캡처), 두 줄까지 보이는 이름(넘치면 말줄임), 개수, 새 항목이 있으면 아이콘 오른쪽 위에 7pt `newCapture` 점입니다.
- 맨 아래 찾기 칸(④): `.safeAreaInset(edge: .bottom)`의 `TextField`("게임 이름으로 찾기", `line.3.horizontal.decrease`)입니다. 맞는 게임이 없으면 "찾는 게임이 없습니다"를 둡니다.
- 툴바 제목과 부제: `.navigationTitle`은 범위 이름(게임 이름, "모든 항목", "새 항목", "영상", "최근 옮긴 항목"), `.navigationSubtitle`은 보이는 캡처의 `CaptureSummary`로 "11월 1일~14일 · 사진 80 · 영상 6"입니다(기간은 `Date.IntervalFormatStyle`의 월과 일, 0개인 칸은 뺌).
- 툴바 필터 메뉴(`line.3.horizontal.decrease.circle`): "사진과 영상", "사진", "영상".
- 범위가 비면 격자 자리에 `ContentUnavailableView`를 둡니다. 새 항목이면 "새 항목이 없습니다"와 "모든 캡처를 Mac으로 옮겼습니다."입니다.

- [ ] **Step 5: 확인합니다**

Run: `swift test`, `make check`, `make app && open dist/Pullshot.app --args -demoAlbum YES`
Expected: 테스트 통과, 위반 없음. 사이드바 항목을 누르면 격자, 제목, 부제가 바뀌고, 긴 게임 이름은 두 줄에서 말줄임되며, 찾기 칸이 게임 목록을 좁힙니다.

- [ ] **Step 6: 커밋합니다**

```bash
git add App Sources Tests
git commit -m "사이드바와 보기 범위 추가"
```

### Task 9: 고르기, 키보드, 미리보기

**Files:**
- Create: `Sources/PullshotApp/Library/GridSelection.swift`
- Modify: `CaptureGrid.swift`, `CaptureCell.swift`, `LibraryModel.swift`, `LibraryWindow.swift`
- Test: `Tests/PullshotAppTests/GridSelectionTests.swift`

**Interfaces:**
- Consumes: `LibraryModel.visibleCaptures`(Task 8), `DeviceWorker.preview(_:)`(Task 5)
- Produces:
  - `struct GridSelection: Equatable { enum Click { case only, toggle, extend }; enum Move { case left, right, up, down }; private(set) var selected: Set<Capture.ID>; private(set) var anchor: Capture.ID?; mutating func click(_ id: Capture.ID, _ click: Click, in order: [Capture.ID]); mutating func move(_ move: Move, columns: Int, in order: [Capture.ID]); mutating func selectAll(_ order: [Capture.ID]); mutating func clear(); mutating func keep(_ order: [Capture.ID]); static func columns(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int }`
  - `LibraryModel`: `var selection = GridSelection()`, `var selectedCaptures: [Capture] { get }`(보이는 순서), `var previewURL: URL?`, `func preview() async`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`GridSelectionTests`(`@Suite("GridSelection 테스트")`). 순서는 `let order = ["a", "b", "c", "d", "e"]`처럼 짧은 문자열을 씁니다(`Capture.ID`는 `String`).

```swift
@Test func `그냥 누르면 그 캡처 하나만 고른다`() {
    var selection = GridSelection()
    selection.click("b", .only, in: order)
    selection.click("d", .only, in: order)
    #expect(selection.selected == ["d"])
    #expect(selection.anchor == "d")
}

@Test func `⌘를 누른 채 누르면 넣고 빼기를 바꾼다`() {
    var selection = GridSelection()
    selection.click("b", .only, in: order)
    selection.click("d", .toggle, in: order)
    selection.click("b", .toggle, in: order)
    #expect(selection.selected == ["d"])
}

@Test func `⇧를 누른 채 누르면 기준부터 누른 캡처까지 더한다`() {
    var selection = GridSelection()
    selection.click("b", .only, in: order)
    selection.click("d", .extend, in: order)
    #expect(selection.selected == ["b", "c", "d"])
    #expect(selection.anchor == "b")
}

@Test func `화살표는 기준에서 한 칸이나 한 줄 옮겨 하나만 고른다`() {
    let order = (0 ..< 10).map(String.init)
    var selection = GridSelection()
    selection.click("5", .only, in: order)
    selection.move(.right, columns: 4, in: order)
    #expect(selection.selected == ["6"])
    selection.move(.down, columns: 4, in: order)
    #expect(selection.selected == ["9"])
    selection.move(.down, columns: 4, in: order)
    #expect(selection.selected == ["9"])
    selection.move(.up, columns: 4, in: order)
    #expect(selection.selected == ["5"])
}

@Test func `고른 것이 없을 때 화살표는 첫 캡처를 고른다`() {
    var selection = GridSelection()
    selection.move(.down, columns: 4, in: order)
    #expect(selection.selected == ["a"])
}

@Test func `보이지 않게 된 캡처는 고른 것에서 뺀다`() {
    var selection = GridSelection()
    selection.selectAll(order)
    selection.click("e", .toggle, in: order)
    selection.keep(["a", "b"])
    #expect(selection.selected == ["a", "b"])
    #expect(selection.anchor == nil)
}

@Test func `열 수는 칸 최소 폭과 간격으로 정한다`() {
    #expect(GridSelection.columns(width: 900, minimum: 180, spacing: 3) == 4)
    #expect(GridSelection.columns(width: 100, minimum: 180, spacing: 3) == 1)
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter GridSelectionTests`
Expected: 컴파일 실패("cannot find 'GridSelection' in scope")

- [ ] **Step 3: `GridSelection`을 만듭니다**

`extend`는 기준이 없거나 보이는 순서에 없으면 `only`처럼 합니다. `keep`은 기준이 빠지면 기준을 지웁니다. `columns`는 `max(1, Int((width + spacing) / (minimum + spacing)))`이고, `LazyVGrid`의 `.adaptive` 열 수와 같은 식입니다.

- [ ] **Step 4: 격자에 고르기와 키보드를 잇습니다**

- 칸을 누를 때 `NSEvent.modifierFlags`로 `⌘` `toggle`, `⇧` `extend`, 그 밖 `only`를 고릅니다. 고른 칸은 3pt `pullshotAccent` 테두리와 오른쪽 아래 `checkmark.circle.fill`(흰 테두리)입니다. 빈 곳을 누르거나 Esc면 `clear()`입니다.
- 격자는 `.focusable()`이고 `.onKeyPress`로 화살표(열 수는 `GeometryReader` 폭과 `GridSelection.columns`), 스페이스(`preview()`)를 받습니다. ⌘A는 `.onCommand(#selector(NSResponder.selectAll(_:)))`로 받아 격자에 초점이 있을 때만 보이는 캡처를 모두 고릅니다.
- `visibleCaptures`가 바뀌면 `selection.keep`을 부르고, 범위를 바꾸면 `clear()`입니다.
- `preview()`는 기준 캡처를 `worker.preview`로 받아 `previewURL`에 두고, 창은 `.quickLookPreview($model.previewURL)`입니다. 두 번 누르기도 같습니다. 앱을 시작할 때 `DeviceWorker.previewFolder`를 지웁니다. 데모에서는 미리보기를 하지 않습니다.

- [ ] **Step 5: 확인합니다**

Run: `swift test`, `make check`, `make app && open dist/Pullshot.app --args -demoAlbum YES`
Expected: 테스트 통과, 위반 없음. 데모에서 누르기, ⌘ 누르기, ⇧ 누르기, ⌘A, 화살표, Esc가 위 규칙대로 동작하고, 찾기 칸에 글자를 칠 때 ⌘A가 글자를 고릅니다.

- [ ] **Step 6: 커밋합니다**

```bash
git add Sources Tests
git commit -m "캡처 고르기와 키보드, 미리보기 추가"
```

### Task 10: 오른쪽 칸과 설정

**Files:**
- Create: `Sources/PullshotApp/Library/ExportPreview.swift`, `Sources/PullshotApp/Views/Inspector.swift`, `Sources/PullshotApp/Views/SettingsView.swift`
- Modify: `LibraryWindow.swift`, `PullshotApp.swift`(`Settings` 장면), `LibraryModel.swift`, 문자열 표 두 개
- Test: `Tests/PullshotAppTests/ExportPreviewTests.swift`

**Interfaces:**
- Consumes: `CaptureSummary`(Task 3), `LedgerIndex.lastTransfer`, `newCaptures`(Task 2), `TransferItem.exports`, `TransferItem.imports`, `ExportOptions`, `ExportNaming`, `GridSelection`(Task 9)
- Produces:
  - `enum ExportPreview { static func lines(_ items: [TransferItem]) -> [String] }`. 다섯 개까지는 모두, 여섯 개부터는 앞 세 개, `…`, 마지막 하나입니다. 폴더가 둘 이상이면 `<폴더 이름>/<파일 이름>`입니다.
  - `LibraryModel`: `var importFolder: URL { get }`(설정 `importFolder`, 없으면 `TransferItem.defaultImportFolder`), `var exportOptions: ExportOptions? { get }`(기준 폴더를 고르기 전에는 nil), `var isInspectorShown: Bool`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`ExportPreviewTests`(`@Suite("ExportPreview 테스트")`). 항목은 `TransferItem.exports(_, options: ExportOptions(baseFolder: URL(filePath: "/tmp/블로그"), naming: .numbered), timeZone: TimeZone(identifier: "Asia/Seoul")!)`로 만듭니다.

```swift
@Test func `다섯 개까지는 모두 보인다`() {
    let captures = (0 ..< 5).map { captureFixture("\($0).jpg", at: "2026-11-06 22:0\($0):00") }
    #expect(ExportPreview.lines(items(captures)) == [
        "001_20261106_220000.jpg", "002_20261106_220100.jpg", "003_20261106_220200.jpg",
        "004_20261106_220300.jpg", "005_20261106_220400.jpg",
    ])
}

@Test func `여섯 개부터는 앞 세 개와 마지막 하나 사이를 줄인다`() {
    let captures = (0 ..< 8).map { captureFixture("\($0).jpg", at: "2026-11-06 22:0\($0):00") }
    #expect(ExportPreview.lines(items(captures)) == [
        "001_20261106_220000.jpg", "002_20261106_220100.jpg", "003_20261106_220200.jpg", "…",
        "008_20261106_220700.jpg",
    ])
}

@Test func `폴더가 둘 이상이면 폴더 이름을 붙인다`() {
    let captures = [captureFixture("a.jpg"), captureFixture("b.jpg", game: "마리오 카트 월드")]
    #expect(ExportPreview.lines(items(captures)).map { $0.split(separator: "/")[0] } == ["젤다무쌍 봉인전기", "마리오 카트 월드"])
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter ExportPreviewTests`
Expected: 컴파일 실패("cannot find 'ExportPreview' in scope")

- [ ] **Step 3: `ExportPreview`를 만듭니다**

- [ ] **Step 4: 오른쪽 칸을 만듭니다**

`.inspector(isPresented:)`로 280pt 칸을 두고, 툴바에 접기 단추(`sidebar.right`)를 둡니다. 창 폭이 980pt보다 좁으면 단추와 상관없이 접고, 넓어지면 사용자가 둔 상태로 돌아갑니다.

- 고른 것이 없을 때(시안 ⑦): 범위 이름, "정보" 아래 항목("86 (사진 80, 영상 6)"), 크기(`ByteCountFormatter`, 1000 단위), 처음 찍은 날, 마지막 찍은 날, 지난번 옮긴 날("11월 8일, 62개", 없으면 "없음"), 새 항목 수와 "새" 캡슐. 그 아래 가져올 곳(`importFolder/<게임 이름>`을 `~`로 줄여 보이고, 누르면 폴더 고르기), "새 항목 N개 가져오기" 강조 단추(0개면 끔), "게임 전체 내보내기"(게임이 아니면 "모두 내보내기", 누르면 `selectAll`).
- 고른 것이 있을 때(장면 2): 고른 캡처 썸네일 세 장까지 겹친 묶음, "N개 고름", "고른 항목" 아래 사진과 영상 수, 크기, 찍은 때(범위). 그 아래 내보낼 곳(기준 폴더, 없으면 "고르기…"), "게임 이름 폴더 만들기" 토글, 파일 이름(`Picker` "원래 이름 그대로", "찍은 순서대로 번호 붙이기"), `ExportPreview.lines`(고정폭 글꼴), "내보내기" 강조 단추. 기준 폴더가 없으면 내보내기를 누를 때 폴더를 먼저 고릅니다.
- 폴더 고르기는 `.fileImporter(allowedContentTypes: [.folder])`이고 경로를 `importFolder`, `exportFolder`에 둡니다. 게임 이름 폴더와 파일 이름 규칙은 `makesGameFolder`(기본 참), `exportNaming`(기본 `original`)에 둡니다.
- 데모에서는 가져오기와 내보내기 단추를 끕니다.

- [ ] **Step 5: 설정 창을 만듭니다**

`Settings { SettingsView() }`에 가져올 곳(경로와 "바꾸기…")과 "자세한 로그 남기기" 토글(설명 "스위치와 주고받은 내용을 로그 파일에 한 줄씩 남깁니다. 문제를 알릴 때만 켜 주세요.")을 둡니다. 토글은 다음 연결부터 `open(_:isVerbose:)`에 넘깁니다.

- [ ] **Step 6: 확인합니다**

Run: `swift test`, `make check`, `make app && open dist/Pullshot.app --args -demoAlbum YES`
Expected: 테스트 통과, 위반 없음. 데모에서 고르기 전과 뒤 오른쪽 칸이 시안 장면 1, 2의 순서로 보이고, 번호 붙이기를 고르면 미리보기가 `001_`부터 바뀌며, 창을 좁히면 오른쪽 칸이 먼저 접힙니다.

- [ ] **Step 7: 커밋합니다**

```bash
git add App Sources Tests
git commit -m "오른쪽 칸과 설정 창 추가"
```

### Task 11: 가져오기, 내보내기, 처음 연결 질문

**Files:**
- Create: `Sources/PullshotApp/Library/TransferText.swift`, `Sources/PullshotApp/Views/TransferPanel.swift`, `Sources/PullshotApp/Views/FirstConnectSheet.swift`
- Modify: `LibraryModel.swift`, `Inspector.swift`, `ConnectionGuide.swift`, 문자열 표 두 개
- Test: `Tests/PullshotAppTests/TransferTextTests.swift`

**Interfaces:**
- Consumes: `DeviceWorker.transfer`, `answerFirstConnectQuestion`, `index`(Task 5), `TransferItem.imports`, `exports`, `FolderMatcher.requireReadable`, `AppErrorMessages`(Task 6)
- Produces:
  - `enum TransferText { static func summary(_ summary: TransferSummary) -> String }`. "저장 N개 · 건너뜀 N개 · 실패 N개 · 받지 못함 N개"이고 저장 말고는 0개면 뺍니다.
  - `LibraryModel`: `struct TransferRun { var kind: TransferKind; var folder: URL; var progress: TransferProgress?; var summary: TransferSummary? }`, `private(set) var transferRun: TransferRun?`, `func importNew()`, `func export()`, `func cancelTransfer()`, `func dismissTransferResult()`, `func revealInFinder()`, `func answerFirstConnect(_ answer: FirstConnectAnswer) async -> String?`(문제가 있으면 문구)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`TransferTextTests`(`@Suite("TransferText 테스트")`):

```swift
@Test func `저장 말고는 0개인 칸을 뺀다`() {
    var summary = TransferSummary()
    summary.saved = [URL(filePath: "/tmp/a.jpg")]
    #expect(TransferText.summary(summary) == "저장 1개")
}

@Test func `연결이 끊겨 받지 못한 수를 결과에 적는다`() {
    var summary = TransferSummary()
    summary.saved = [URL(filePath: "/tmp/a.jpg")]
    summary.skipped = 2
    summary.failures = [TransferFailure(capture: captureFixture("b.jpg"), error: SessionError.transport(.disconnected))]
    summary.notAttempted = 3
    #expect(TransferText.summary(summary) == "저장 1개 · 건너뜀 2개 · 실패 1개 · 받지 못함 3개")
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferTextTests`
Expected: 컴파일 실패("cannot find 'TransferText' in scope")

- [ ] **Step 3: `TransferText`와 옮기기 흐름을 만듭니다**

- `importNew()`: 보이는 캡처의 새 항목을 `TransferItem.imports(_, into: importFolder)`로, `export()`: 고른 캡처를 `TransferItem.exports(_, options: exportOptions)`로 만들어 `worker.transfer`를 부르는 `Task`를 둡니다. 진행은 `transferRun.progress`에 두고, 끝나면 `summary`와 `index = await worker.index`를 맞춥니다. 옮기는 동안 가져오기, 내보내기, 기기 전환을 끕니다.
- `cancelTransfer()`는 그 `Task`를 취소합니다. Kit이 받던 파일의 남은 데이터를 끝까지 읽어 버리고 멈춥니다.
- `revealInFinder()`: 저장한 파일이 한 폴더에 있으면 그 파일들을, 여러 폴더면 기준 폴더(`folder`)를 `NSWorkspace.shared.activateFileViewerSelecting`으로 보입니다.
- 옮기던 중 기기가 빠지면 격자는 비우되 `transferRun`의 결과는 남겨, `ConnectionGuide` 위에 `TransferText.summary`와 "연결이 끊겨 남은 캡처를 받지 못했습니다. 다시 연결하면 새 항목으로 남아 있습니다." 한 줄을 둡니다.

- [ ] **Step 4: 진행 칸을 만듭니다**

`TransferPanel`은 오른쪽 칸 아래 단추 자리에 둡니다. 옮기는 중에는 "가져오는 중 3/24"(내보내기는 "내보내는 중"), 지금 파일 이름과 바이트 진행 막대, 전체 진행 막대, "취소" 단추입니다. 끝나면 `TransferText.summary`, 실패가 있으면 펼쳐 보는 목록(파일 이름과 `AppErrorMessages` 문구), "Finder에서 보기"와 "닫기" 단추입니다. 취소했으면 첫 줄에 "취소했습니다."를 둡니다.

- [ ] **Step 5: 처음 연결 질문을 만듭니다**

`isAskingFirstConnect`가 참이면 `FirstConnectSheet`를 띄웁니다. 제목 "이미 받아 둔 캡처가 있나요?", 설명 "처음 연결한 스위치입니다. 지금 있는 캡처가 모두 새 항목으로 보이지 않도록, 이미 Mac에 받아 둔 캡처를 옮긴 기록에 넣을 수 있습니다.", 단추 셋은 "폴더에서 찾기…"(폴더를 고르면 진행 표시와 취소 단추를 두고 `.findInFolder`), "지금 있는 캡처를 모두 옮긴 것으로 표시"(`.markAll`), "모두 새 항목으로 두기"(`.leaveAllNew`)이고 "나중에" 단추로 닫습니다. 답하면 "기록에 넣은 캡처 %lld개"를 보이고 "확인"으로 닫습니다. 폴더를 읽지 못하면 `AppErrorMessages` 문구를 시트 안에 둡니다.

- [ ] **Step 6: 확인합니다**

Run: `swift test`, `make check`, `make app`
Expected: 테스트 통과, 위반 없음. 실제 옮기기와 처음 연결 질문은 Task 13에서 실기기로 봅니다.

- [ ] **Step 7: 커밋합니다**

```bash
git add App Sources Tests
git commit -m "앱 가져오기, 내보내기, 처음 연결 질문 추가"
```

### Task 12: 끝내기, 도움말, README

**Files:**
- Modify: `Sources/PullshotApp/PullshotApp.swift`, `LibraryModel.swift`, `README.md`, 문자열 표 두 개

**Interfaces:**
- Consumes: `LibraryModel`, `DeviceWorker.close()`, `DeviceWorker.previewFolder`, `FileLog.defaultFile`
- Produces: `final class AppDelegate: NSObject, NSApplicationDelegate`(`@NSApplicationDelegateAdaptor`), `LibraryModel.shutdown() async`

- [ ] **Step 1: 끝내기를 만듭니다**

`applicationShouldTerminate`는 열린 세션이 없으면 `.terminateNow`, 있으면 `.terminateLater`를 돌려주고 `model.shutdown()`을 부릅니다. `shutdown()`은 하던 일을 취소하고 그 작업이 끝나길 기다린 뒤 `worker.close()`, 미리보기 폴더 지우기입니다. 끝나면 `NSApp.reply(toApplicationShouldTerminate: true)`이고, 10초가 지나면 기다리지 않고 같은 답을 보냅니다. 창을 닫으면 앱도 끝냅니다(`applicationShouldTerminateAfterLastWindowClosed`).

- [ ] **Step 2: 도움말 메뉴를 만듭니다**

`CommandGroup(replacing: .help)`에 "로그 파일 보기"를 두고 `FileLog.defaultFile`을 Finder에서 고릅니다. 파일이 아직 없으면 폴더를 엽니다.

- [ ] **Step 3: README를 고칩니다**

"진행 상황"을 앱이 생긴 상태로 고치고, `## 앱` 절에 `make app`, `open dist/Pullshot.app`, 처음 열 때 시스템 설정의 개인정보 보호 및 보안에서 열기를 허용해야 한다는 것(ad-hoc 서명), 화면에서 할 수 있는 일(게임별 보기, 새 항목 가져오기, 번호 붙여 내보내기, 스페이스로 크게 보기), 로그 위치와 "자세한 로그 남기기"를 적습니다. Nintendo Switch 실험적 지원 문장은 그대로 둡니다.

- [ ] **Step 4: 확인합니다**

Run: `swift test`, `make check`, `make app && open dist/Pullshot.app --args -demoAlbum YES` 뒤 ⌘Q
Expected: 테스트 통과, 위반 없음. 도움말 메뉴에서 로그 파일이 Finder에 보이고, ⌘Q로 바로 끝나며 `$TMPDIR/Pullshot-preview`가 남지 않습니다.

- [ ] **Step 5: 커밋합니다**

```bash
git add App Sources README.md
git commit -m "앱 끝내기, 도움말 메뉴, README 앱 절 추가"
```

### Task 13: 실기기 확인 (사용자와 20분)

사용자가 스위치 2를 이 맥에 꽂아 PC로 복사 모드로 둔 상태에서 합니다. 화면은 사용자가 화면 공유(`vnc://mac-studio`)로 함께 봅니다. 실제 기록을 더럽히지 않도록 `S`를 세션 스크래치 폴더로 두고 앱을 `open dist/Pullshot.app --args -ledgerFolder "$S/ledger" -importFolder "$S/import"`로 엽니다.

**Files:**
- Modify: `docs/hardware-notes.md`(3단계 확인 절 추가)

- [ ] **Step 1: 저절로 연결과 훑기를 봅니다**

스위치를 뺀 채 앱을 열어 안내 화면을 보고, 꽂은 뒤 "연결하는 중", "앨범을 읽는 중", 격자 순서로 바뀌는지 봅니다. 처음 연결 질문이 뜨면 "나중에"로 닫습니다.
Expected: 손대지 않아도 열리고, 게임 수와 캡처 수가 `swift run pullshot list --ledger-folder "$S/ledger" | grep -c "^  "`와 같습니다.

- [ ] **Step 2: 썸네일, 보기, 고르기를 봅니다**

캡처가 가장 많은 게임에서 빠르게 끝까지 스크롤하고, 날짜 보기, 영상 필터, 찾기 칸, 스페이스 미리보기(사진과 영상 하나씩)를 해 봅니다.
Expected: 썸네일이 칸이 보이는 대로 채워지고, 앱을 다시 열면 디스크 캐시에서 바로 뜹니다. 미리보기가 원본으로 열립니다.

- [ ] **Step 3: 가져오기와 처음 연결 질문을 봅니다**

영상이 있는 작은 게임에서 "새 항목 N개 가져오기"를 하고, 앱을 다시 열어 처음 연결 질문에 "폴더에서 찾기…"로 `$S/import`를 고릅니다.
Expected: 결과가 "저장 N개"이고, 다시 열었을 때 그 게임에 새 항목 점이 없으며, 받은 파일의 만든 날짜가 찍은 시각입니다.

- [ ] **Step 4: 번호 붙여 내보내기를 봅니다**

같은 게임에서 여덟 개를 골라 `$S/blog`로 "찍은 순서대로 번호 붙이기" 내보내기를 합니다.
Expected: 오른쪽 칸 미리보기와 Finder의 파일 이름이 같고, "Finder에서 보기"가 그 파일들을 고릅니다.

- [ ] **Step 5: 끊김과 다른 앱을 봅니다**

큰 게임 가져오기 도중 케이블을 뽑았다가 다시 꽂고, 미리보기 앱을 켠 채 다시 연결해 봅니다.
Expected: 안내 화면 위에 "받지 못함 N개" 결과가 남고, 다시 꽂으면 리셋 없이 저절로 열립니다. 미리보기가 켜져 있으면 미리보기와 사진 앱을 닫으라는 문구와 "다시 시도"가 보이고, 앱을 닫은 뒤 다시 시도하면 열립니다.

- [ ] **Step 6: 옮기는 중 끝내기를 봅니다**

큰 게임 가져오기 도중 ⌘Q로 끝내고 앱을 다시 엽니다.
Expected: 10초 안에 끝나고, 다시 열 때 USB 리셋 안내 없이 바로 연결됩니다(`log show --predicate 'subsystem == "com.parkgiraffe.Pullshot"' --last 5m | grep -c "USB 장치"`가 0).

- [ ] **Step 7: 기록하고 커밋합니다**

`docs/hardware-notes.md`에 "3단계 확인" 절을 더해 각 단계 결과, 걸린 시간(연결부터 격자까지, 썸네일이 처음 채워지는 데), 사용자 의견을 적습니다. 경로와 일련번호는 적지 않습니다.

```bash
git add docs/hardware-notes.md
git commit -m "3단계 실기기 확인 결과 추가"
```
