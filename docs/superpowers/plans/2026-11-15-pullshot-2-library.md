# Pullshot 2단계: 보관함 로직 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 훑은 캡처를 게임과 플레이로 묶고, Mac으로 옮긴 기록을 남겨 새 항목을 가려내며, 가져오기와 내보내기(번호 붙이기 포함)를 하는 라이브러리 기능을 PullshotKit에 만들고, CLI로 실기기에서 써 봅니다.

**Architecture:** 묶기(`Play`, `Game`)는 `Capture` 배열만 받는 순수 함수입니다. 옮긴 기록(`TransferLedger`)은 Application Support의 JSON Lines 파일에 덧붙여 쓰고, 열 때 한 번 읽어 메모리 색인을 만듭니다. 가져오기와 내보내기는 "어느 폴더에 어떤 이름으로"를 정하는 `TransferItem`과, 그것을 받아 내려받고 기록하는 `Transfer`로 나눕니다. `Transfer`는 `Session` 대신 `DownloadSource` 프로토콜에 기대어 가짜 기기로 테스트합니다. CLI는 Kit을 묶기만 합니다.

**Tech Stack:** Swift 6.2 도구(로컬 Swift 6.3), SwiftPM, macOS 15 이상, Foundation, Swift Testing, swift-argument-parser(CLI만), SwiftLint, SwiftFormat.

**Spec:** `docs/superpowers/specs/2026-11-15-pullshot-design.md`의 6.2, 6.3, 6.4, 7절입니다. 실기기 사실은 `docs/hardware-notes.md`입니다.

**나중 결정(2026-11-15):** Task 8에서 실제 캡처로 플레이 목록을 본 뒤, 사용자가 플레이별 보기는 필요 없다고 해 Task 1의 `Play`와 CLI `--plays`를 뺐습니다. 3단계 앱의 기본 보기는 최신순입니다.

**이 계획의 범위:** 세 계획 중 두 번째입니다. 연결 감시(꽂고 빼기 알림, 두 대 전환), 썸네일 캐시, 날짜 보기의 월과 날 묶기, Quick Look, 현지화, 파일 로그, 내보낼 기준 폴더 기억하기는 3단계(SwiftUI 앱)에서 합니다. 강제 종료 뒤 마지막 트랜잭션 ID로 남은 세션을 닫는 실험(hardware-notes)은 이 계획에 넣지 않습니다. 앱은 정상 종료 때 세션을 닫으므로 급하지 않습니다. 1단계 브랜치가 main에 머지된 뒤 main에서 `library` 브랜치를 땁니다. 머지 전이면 `ptp-core-cli` 끝에서 땁니다.

## Global Constraints

1단계 계획의 Global Constraints를 모두 이어받습니다. 특히 커밋 규칙, `make check`, 한국어 테스트 이름, Kit은 도메인 오류를 던지고 문구는 가장자리에서 바꾸는 규칙, 통합 로그의 `privacy: .private`, 새 패키지 금지가 그대로입니다. 2단계에서 더하는 것은 이렇습니다.

- 옮긴 기록은 `~/Library/Application Support/Pullshot/`에 둡니다. 기록에는 일련번호와 파일 이름이 들어가므로 리포, 통합 로그(public), 테스트 픽스처 파일에 남기지 않습니다.
- 기록의 열쇠는 기기 일련번호, 게임 폴더 이름, 파일 이름, 크기입니다(설계 6.3). 실기기에서 일련번호가 세션과 USB 리셋을 넘어 같음을 확인했으므로 열쇠에 둡니다(hardware-notes). 핸들과 저장소 ID는 저장하지 않습니다.
- 새 항목은 기록에 없는 캡처입니다. 가져오기, 내보내기, 처음 연결 답(폴더에서 찾기, 모두 옮긴 것으로)이 모두 기록을 남깁니다.
- 플레이는 같은 게임 안에서 캡처 사이가 60분을 넘게 비면 나눕니다. 기준은 상수 `Play.maxGap` 하나입니다.
- 가져올 곳 기본값은 `~/Pictures/Pullshot/<게임 이름>/<원래 파일 이름>`입니다.
- 번호 붙이기 이름은 `001_20261114_211205.jpg` 형식입니다. 찍은 시각 오름차순, 최소 3자리, 개수가 많으면 자릿수를 늘립니다.
- 저장한 파일의 만든 날짜와 수정 날짜를 찍은 시각으로 맞춥니다. 파일 안 메타데이터(EXIF, QuickTime)는 건드리지 않습니다.
- 같은 이름과 크기의 파일이 이미 있으면 받지 않고 기록만 남깁니다. 이름만 같으면 1단계 `DestinationNamer`대로 "이름 2.확장자"로 따로 받습니다. 덮어쓰지 않습니다.
- 취소는 세션을 버리지 않습니다(1단계 Task 13 판정, 설계 6.1의 "세션을 버리고 다시 연결"을 대신함). 연결이 끊긴 경우에만 멈춥니다.

## Review Focus

1. 앱이나 전원이 꺼져 기록 파일의 마지막 줄이 잘렸을 때: 앞 줄은 모두 읽고, 그 뒤에 쓰는 기록도 잃지 않아야 합니다. Task 2의 `끝 줄이 잘린 기록 파일도 앞 줄을 읽고 이어서 기록한다`가 맡습니다.
2. 가져오는 중에 케이블이 빠질 때: 그 전에 받은 캡처는 기록에 남고, 요약은 시도하지 못한 수를 따로 셉니다(1단계에서 미룬 문제). Task 5의 `연결이 끊기면 멈추고 시도하지 못한 수를 센다`가 맡습니다.
3. 가져올 곳에 이름은 같고 크기가 다른 파일(사용자가 고친 사진)이 있을 때: 원래 파일은 그대로 두고 따로 받습니다. Task 5의 `이름만 같은 파일이 있으면 번호를 붙여 따로 받고 원래 파일은 그대로 둔다`가 맡습니다.
4. 처음 연결 답에서 고른 폴더에 읽을 수 없는 하위 폴더가 있을 때: 그 폴더만 건너뛰고 나머지에서 찾습니다. Task 3의 `읽을 수 없는 하위 폴더가 있어도 나머지에서 찾는다`가 맡습니다.
5. 같은 초에 찍은 캡처(순번 00, 01)를 번호 붙여 내보낼 때: 이름이 겹치지 않고 순번 순으로 번호를 받습니다. Task 4의 `같은 초에 찍은 캡처도 서로 다른 번호를 받는다`가 맡습니다.

## 미리 정한 것

스펙이 정하지 않았거나 실기기 결과로 바뀐 부분입니다. 실행하는 사람은 이대로 짜고, 다르게 하려면 원장에 판정을 남깁니다.

- 스위치에는 "기타"라는 폴더가 실제로 있습니다. 게임 폴더 밖 캡처와 뜻이 같으므로 화면과 가져올 곳에서는 "기타" 하나로 묶고, 기록의 열쇠에는 원래 `gameFolder`(nil 또는 "기타")를 그대로 둡니다.
- 게임 목록은 최근 캡처 순이고, 찍은 시각을 모르는 캡처만 있는 게임이 그다음, "기타"가 맨 끝입니다(1단계 `list`와 같음).
- 플레이 목록은 최근 플레이가 먼저이고, 플레이 안의 캡처는 찍은 순서(오래된 것 먼저)입니다. 연재 글을 쓰는 순서와 같습니다. 게임의 캡처 목록은 1단계처럼 최근 것이 먼저입니다.
- 찍은 시각을 모르는 캡처는 마지막 플레이 하나에 모읍니다.
- "지난번 옮긴 날과 개수"는 가져오기와 내보내기만 봅니다. 처음 연결 답으로 남긴 기록은 실제로 옮긴 날이 아니므로 뺍니다. 개수는 그날 옮긴 캡처 수입니다.
- 번호는 내보낼 폴더마다 따로 셉니다. 여러 게임을 게임 이름 폴더로 나눠 내보내면 폴더마다 001부터 시작합니다.
- 내보내기는 이미 가져온 캡처도 기기에서 받습니다(설계 11절이 맡긴 선택). Mac 파일 복사는 3단계에서 필요하면 더합니다.
- 기록 파일은 `transfers.jsonl`(옮긴 기록)과 `answered-devices.json`(처음 연결 질문에 답한 기기)입니다.

## 파일 구조

```
Sources/PullshotKit/
  Album/Play.swift Game.swift                 (Task 1)
  Library/CaptureKey.swift TransferLedger.swift (Task 2, 3)
  Library/FolderMatcher.swift FirstConnection.swift (Task 3)
  Library/TransferItem.swift                  (Task 4)
  Library/Transfer.swift                      (Task 5)
  Support/ListFormatter.swift                 (Task 6에서 고침)
Sources/pullshot/
  Pull.swift List.swift Connect.swift         (Task 6에서 고침)
  CaptureSelection.swift LedgerOptions.swift  (Task 6)
  Export.swift Ledger.swift                   (Task 7)
Tests/PullshotKitTests/
  Support/Fixtures.swift                      (Task 1에서 captureFixture, dateFixture 추가)
  Support/FakeDownloadSource.swift            (Task 5)
  PlayTests.swift GameTests.swift TransferLedgerTests.swift FirstConnectionTests.swift
  TransferItemTests.swift TransferTests.swift
Tests/PullshotCLITests/CaptureSelectionTests.swift (Task 6)
```

### Task 1: 플레이와 게임 묶기

**Files:**
- Create: `Sources/PullshotKit/Album/Play.swift`, `Sources/PullshotKit/Album/Game.swift`
- Modify: `Sources/PullshotKit/Support/ListFormatter.swift`, `Sources/pullshot/List.swift`, `Sources/pullshot/Pull.swift`(`ListFormatter.otherGames`를 `Game.otherName`으로), `docs/glossary.md`(플레이의 코드 `Play`)
- Modify: `Tests/PullshotKitTests/Support/Fixtures.swift`
- Test: `Tests/PullshotKitTests/PlayTests.swift`, `Tests/PullshotKitTests/GameTests.swift`

**Interfaces:**
- Produces:
  - 테스트 지원: `func dateFixture(_ text: String) -> Date`("yyyy-MM-dd HH:mm:ss", Asia/Seoul), `func captureFixture(_ filename: String = "2026111421120500_s.jpg", game: String? = "젤다무쌍 봉인전기", at capturedAt: String? = "2026-11-14 21:12:05", size: UInt64? = 5, kind: Capture.Kind = .photo, handle: UInt32 = 1) -> Capture`
  - `public struct Play: Equatable, Sendable { public var captures: [Capture]; public var start: Date?; public var end: Date?; public var photoCount: Int; public var videoCount: Int; public static let maxGap: TimeInterval; public static func split(_ captures: [Capture]) -> [Play] }`
  - `public struct Game: Equatable, Sendable, Identifiable { public var name: String; public var captures: [Capture]; public var plays: [Play]; public var id: String; public static let otherName = "기타"; public static func games(in captures: [Capture]) -> [Game] }`
  - `public extension Capture { var gameName: String }`(`gameFolder ?? Game.otherName`)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`PlayTests`(`@Suite("Play 테스트")`):

```swift
@Test func `캡처 사이가 60분을 넘으면 다른 플레이로 나눈다`() {
    let plays = Play.split([
        captureFixture("a.jpg", at: "2026-11-14 21:00:00"),
        captureFixture("d.jpg", at: "2026-11-14 23:30:01"),
        captureFixture("b.jpg", at: "2026-11-14 21:30:00"),
        captureFixture("c.jpg", at: "2026-11-14 22:30:00"),
    ])
    // 22:30에서 23:30:01은 60분 1초라 나누고, 21:30에서 22:30은 꼭 60분이라 잇습니다.
    #expect(plays.map { $0.captures.map(\.filename) } == [["d.jpg"], ["a.jpg", "b.jpg", "c.jpg"]])
    #expect(plays[1].start == dateFixture("2026-11-14 21:00:00"))
    #expect(plays[1].end == dateFixture("2026-11-14 22:30:00"))
}

@Test func `찍은 시각을 모르는 캡처는 마지막 플레이 하나로 모은다`() {
    let plays = Play.split([captureFixture("x.jpg", at: nil), captureFixture("a.jpg"), captureFixture("y.jpg", at: nil)])
    #expect(plays.map { $0.captures.map(\.filename) } == [["a.jpg"], ["x.jpg", "y.jpg"]])
    #expect(plays[1].start == nil)
}

@Test func `플레이마다 사진과 영상 수를 센다`() {
    let play = Play.split([captureFixture("a.jpg"), captureFixture("b.mp4", kind: .video), captureFixture("c.jpg")])[0]
    #expect(play.photoCount == 2)
    #expect(play.videoCount == 1)
}
```

`GameTests`(`@Suite("Game 테스트")`):

```swift
@Test func `게임은 최근 캡처 순이고 시각을 모르는 게임 다음에 기타를 끝에 둔다`() {
    let games = Game.games(in: [
        captureFixture("a.jpg", game: "Mario Kart World", at: "2026-11-05 10:00:00"),
        captureFixture("k.jpg", game: nil, at: "2026-11-20 09:00:00"),
        captureFixture("b.jpg", game: "Pokémon UNITE", at: nil),
        captureFixture("c.jpg", game: "젤다무쌍 봉인전기", at: "2026-11-14 21:00:00"),
    ])
    #expect(games.map(\.name) == ["젤다무쌍 봉인전기", "Mario Kart World", "Pokémon UNITE", "기타"])
}

@Test func `스위치의 기타 폴더와 게임 폴더 밖 캡처를 기타 하나로 묶는다`() {
    let games = Game.games(in: [captureFixture("a.jpg", game: "기타"), captureFixture("b.jpg", game: nil)])
    #expect(games.map(\.name) == ["기타"])
    #expect(games[0].captures.map(\.gameFolder) == ["기타", nil])
}

@Test func `게임의 캡처는 최근 것이 먼저이고 플레이도 함께 나눈다`() {
    let game = Game.games(in: [captureFixture("a.jpg", at: "2026-11-13 16:05:00"), captureFixture("b.jpg")])[0]
    #expect(game.captures.map(\.filename) == ["b.jpg", "a.jpg"])
    #expect(game.plays.count == 2)
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter "PlayTests|GameTests"`
Expected: 컴파일 실패("cannot find 'Play' in scope")

- [ ] **Step 3: `Play`, `Game`, `Capture.gameName`을 만들고 `ListFormatter.otherGames`를 `Game.otherName`으로 바꿉니다**

`Play.split`은 시각이 있는 캡처를 오름차순으로 정렬해 간격이 `maxGap`(3600초)을 넘을 때 끊고, 플레이 목록을 뒤집어 최근 것을 먼저 둡니다. 시각이 없는 캡처는 파일 이름 순으로 마지막 플레이 하나가 됩니다. `Game.games`는 `gameName`으로 묶고, 캡처는 `Capture.newestFirst`로, 게임은 첫 캡처끼리 `newestFirst`로 정렬하되 `Game.otherName`은 맨 끝에 둡니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests docs/glossary.md
git commit -m "플레이와 게임 묶기 추가"
```

### Task 2: 옮긴 기록

**Files:**
- Create: `Sources/PullshotKit/Library/CaptureKey.swift`, `Sources/PullshotKit/Library/TransferLedger.swift`
- Modify: `Sources/PullshotKit/Support/Log.swift`(분류 `library` 추가), `docs/glossary.md`(옮김의 코드 `TransferLedger`, 새 항목의 코드 `TransferLedger.newCaptures`)
- Test: `Tests/PullshotKitTests/TransferLedgerTests.swift`

**Interfaces:**
- Consumes: `Capture`, `captureFixture`, `dateFixture`(Task 1)
- Produces:
  - `public struct CaptureKey: Hashable, Codable, Sendable { public var serialNumber: String; public var gameFolder: String?; public var filename: String; public var size: UInt64?; public init(_ capture: Capture, serialNumber: String) }`
  - `public enum TransferKind: String, Codable, Sendable { case imported, exported, foundInFolder, markedAll }`
  - `public struct LedgerEntry: Codable, Equatable, Sendable { public var key: CaptureKey; public var kind: TransferKind; public var date: Date }`
  - `public struct LastTransfer: Equatable, Sendable { public var day: Date; public var count: Int }`
  - `public final class TransferLedger { public static let defaultDirectory: URL; public init(directory: URL = defaultDirectory) throws; public func record(_ captures: [Capture], serialNumber: String, as kind: TransferKind, at date: Date = Date()) throws; public func isTransferred(_ capture: Capture, serialNumber: String) -> Bool; public func newCaptures(_ captures: [Capture], serialNumber: String) -> [Capture]; public func transferredAt(_ capture: Capture, serialNumber: String) -> Date?; public func lastTransfer(of captures: [Capture], serialNumber: String, calendar: Calendar = .current) -> LastTransfer? }`
  - 테스트 지원: `func temporaryFolderFixture() -> URL`(임시 폴더 아래 새 UUID 경로, 만들지는 않음)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`@Suite("TransferLedger 테스트")` 아래 `@Suite("새 항목")`, `@Suite("저장")`, `@Suite("지난번 옮김")`:

```swift
@Test func `기록한 캡처는 다시 열어도 옮긴 것으로 남는다`() throws {
    let folder = temporaryFolderFixture()
    try TransferLedger(directory: folder).record([captureFixture()], serialNumber: "S1", as: .imported)
    #expect(try TransferLedger(directory: folder).isTransferred(captureFixture(), serialNumber: "S1"))
}

@Test func `기록에 없는 캡처만 새 항목이고 기기와 크기가 다르면 다른 캡처다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    try ledger.record([captureFixture("a.jpg")], serialNumber: "S1", as: .exported)
    let candidates = [captureFixture("a.jpg"), captureFixture("a.jpg", size: 6), captureFixture("b.jpg")]
    #expect(ledger.newCaptures(candidates, serialNumber: "S1").map(\.size) == [6, 5])
    #expect(ledger.newCaptures([captureFixture("a.jpg")], serialNumber: "S2").count == 1)
}

@Test func `끝 줄이 잘린 기록 파일도 앞 줄을 읽고 이어서 기록한다`() throws {
    let folder = temporaryFolderFixture()
    try TransferLedger(directory: folder).record([captureFixture("a.jpg")], serialNumber: "S1", as: .imported)
    let file = try FileHandle(forWritingTo: folder.appending(path: "transfers.jsonl"))
    try file.seekToEnd()
    try file.write(contentsOf: Data(#"{"key":{"seri"#.utf8))
    try file.close()

    try TransferLedger(directory: folder).record([captureFixture("b.jpg")], serialNumber: "S1", as: .imported)
    let reopened = try TransferLedger(directory: folder)

    #expect(reopened.isTransferred(captureFixture("a.jpg"), serialNumber: "S1"))
    #expect(reopened.isTransferred(captureFixture("b.jpg"), serialNumber: "S1"))
}

@Test func `지난번 옮긴 날은 가져오기와 내보내기만 보고 그날 옮긴 수를 센다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    let (a, b, c) = (captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg"))
    try ledger.record([a, b], serialNumber: "S1", as: .imported, at: dateFixture("2026-11-08 10:00:00"))
    try ledger.record([a], serialNumber: "S1", as: .exported, at: dateFixture("2026-11-09 21:00:00"))
    try ledger.record([c], serialNumber: "S1", as: .markedAll, at: dateFixture("2026-11-10 09:00:00"))
    var seoul = Calendar(identifier: .gregorian)
    seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt

    #expect(ledger.lastTransfer(of: [a, b, c], serialNumber: "S1", calendar: seoul)
        == LastTransfer(day: dateFixture("2026-11-09 00:00:00"), count: 1))
    #expect(ledger.transferredAt(a, serialNumber: "S1") == dateFixture("2026-11-09 21:00:00"))
    #expect(ledger.transferredAt(c, serialNumber: "S1") == nil)
    #expect(ledger.isTransferred(c, serialNumber: "S1"))
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferLedgerTests`
Expected: 컴파일 실패("cannot find 'TransferLedger' in scope")

- [ ] **Step 3: `CaptureKey`, `TransferLedger`를 만듭니다**

- 파일은 `<directory>/transfers.jsonl`, 한 줄에 `LedgerEntry` 하나(`JSONEncoder`, 날짜는 `.iso8601`)입니다. `init`은 폴더를 만들고 파일을 한 번 읽습니다. 읽지 못한 줄은 건너뛰고 그 수를 `Log.library`에 남깁니다.
- `record`는 한 번의 호출에서 만든 줄을 모아 `open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)`로 연 파일에 `write` 한 번으로 덧붙입니다. 파일이 줄바꿈으로 끝나지 않으면(잘린 줄) 앞에 줄바꿈을 하나 넣어 새 줄이 잘린 줄에 붙지 않게 합니다. 쓰기에 실패하면 던집니다.
- 메모리 색인은 `CaptureKey`마다 "기록이 있음"과 "가져오기, 내보내기의 마지막 날짜"를 둡니다. `lastTransfer`는 주어진 캡처들의 마지막 날짜 중 가장 늦은 날을 `calendar.startOfDay`로 잡고, 그날 가져오기나 내보내기가 있었던 캡처 수를 셉니다.
- `defaultDirectory`는 `URL.applicationSupportDirectory.appending(path: "Pullshot")`입니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests docs/glossary.md
git commit -m "옮긴 기록 추가"
```

### Task 3: 처음 연결 질문

**Files:**
- Create: `Sources/PullshotKit/Library/FolderMatcher.swift`, `Sources/PullshotKit/Library/FirstConnection.swift`
- Modify: `Sources/PullshotKit/Library/TransferLedger.swift`(답한 기기 목록을 `init`에서 읽음)
- Test: `Tests/PullshotKitTests/FirstConnectionTests.swift`

**Interfaces:**
- Consumes: `TransferLedger`, `TransferKind.foundInFolder`, `.markedAll`(Task 2)
- Produces:
  - `public enum FirstConnectAnswer: Equatable, Sendable { case findInFolder(URL), markAll, leaveAllNew }`
  - `public extension TransferLedger { func needsFirstConnectQuestion(serialNumber: String) -> Bool; func answerFirstConnectQuestion(_ answer: FirstConnectAnswer, captures: [Capture], serialNumber: String, isCancelled: () -> Bool = { false }) throws -> Int }`(돌려주는 값은 기록에 넣은 캡처 수)
  - `public enum FolderMatcher { public static func captures(_ captures: [Capture], foundUnder folder: URL, isCancelled: () -> Bool = { false }) throws -> [Capture] }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`@Suite("처음 연결 테스트")` 아래 `@Suite("물을지")`, `@Suite("폴더에서 찾기")`:

```swift
@Test func `기록도 답도 없는 기기에만 묻고 한 번 답하면 다시 묻지 않는다`() throws {
    let folder = temporaryFolderFixture()
    let ledger = try TransferLedger(directory: folder)
    #expect(ledger.needsFirstConnectQuestion(serialNumber: "S1"))

    #expect(try ledger.answerFirstConnectQuestion(.leaveAllNew, captures: [captureFixture()], serialNumber: "S1") == 0)

    #expect(try !TransferLedger(directory: folder).needsFirstConnectQuestion(serialNumber: "S1"))
    #expect(ledger.newCaptures([captureFixture()], serialNumber: "S1").count == 1)
}

@Test func `기록이 이미 있는 기기는 묻지 않는다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    try ledger.record([captureFixture()], serialNumber: "S1", as: .imported)
    #expect(!ledger.needsFirstConnectQuestion(serialNumber: "S1"))
}

@Test func `모두 옮긴 것으로 표시하면 지금 캡처를 모두 기록한다`() throws {
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    let captures = [captureFixture("a.jpg"), captureFixture("b.jpg")]
    #expect(try ledger.answerFirstConnectQuestion(.markAll, captures: captures, serialNumber: "S1") == 2)
    #expect(ledger.newCaptures(captures, serialNumber: "S1").isEmpty)
}

@Test func `폴더 어디에 있든 이름과 크기가 같은 캡처만 옮긴 것으로 기록한다`() throws {
    let root = temporaryFolderFixture()
    try FileManager.default.createDirectory(at: root.appending(path: "2025/젤다"), withIntermediateDirectories: true)
    try Data(count: 5).write(to: root.appending(path: "2025/젤다/a.jpg"))
    try Data(count: 9).write(to: root.appending(path: "b.jpg"))
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    let captures = [captureFixture("a.jpg"), captureFixture("b.jpg"), captureFixture("c.jpg")]

    #expect(try ledger.answerFirstConnectQuestion(.findInFolder(root), captures: captures, serialNumber: "S1") == 1)
    #expect(ledger.newCaptures(captures, serialNumber: "S1").map(\.filename) == ["b.jpg", "c.jpg"])
}

@Test func `읽을 수 없는 하위 폴더가 있어도 나머지에서 찾는다`() throws {
    let root = temporaryFolderFixture()
    let locked = root.appending(path: "locked")
    try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
    try Data(count: 5).write(to: root.appending(path: "a.jpg"))
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path(percentEncoded: false))
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path(percentEncoded: false)) }

    #expect(try FolderMatcher.captures([captureFixture("a.jpg")], foundUnder: root).count == 1)
}

@Test func `찾기를 취소하면 아무것도 기록하지 않고 다시 묻는다`() throws {
    let root = temporaryFolderFixture()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(count: 5).write(to: root.appending(path: "2026111421120500_s.jpg"))
    let ledger = try TransferLedger(directory: temporaryFolderFixture())
    #expect(throws: CancellationError.self) {
        try ledger.answerFirstConnectQuestion(
            .findInFolder(root), captures: [captureFixture()], serialNumber: "S1", isCancelled: { true }
        )
    }
    #expect(ledger.needsFirstConnectQuestion(serialNumber: "S1"))
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter FirstConnectionTests`
Expected: 컴파일 실패("cannot find 'FolderMatcher' in scope")

- [ ] **Step 3: 처음 연결 질문과 `FolderMatcher`를 만듭니다**

- 답한 기기는 `<directory>/answered-devices.json`(일련번호 배열, `atomically: true`)에 둡니다. `needsFirstConnectQuestion`은 답한 적이 없고 그 기기의 기록도 없을 때만 참입니다.
- `answerFirstConnectQuestion`은 기록(`.foundInFolder` 또는 `.markedAll`)을 먼저 남기고 그다음 답한 기기에 넣습니다. 취소되면 둘 다 하지 않습니다.
- `FolderMatcher`는 `FileManager.enumerator(at:includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsPackageDescendants], errorHandler: { _, _ in true })`로 내려가며 이름별 크기 집합을 만듭니다. 심볼릭 링크는 따라가지 않습니다(열거자 기본값). 파일마다 `isCancelled()`를 보고 참이면 `CancellationError()`를 던집니다. 크기를 모르는 캡처는 맞추지 않습니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "처음 연결 질문과 폴더에서 찾기 추가"
```

### Task 4: 가져올 곳과 내보낼 이름

**Files:**
- Create: `Sources/PullshotKit/Library/TransferItem.swift`
- Test: `Tests/PullshotKitTests/TransferItemTests.swift`

**Interfaces:**
- Consumes: `Capture.gameName`(Task 1)
- Produces:
  - `public struct TransferItem: Equatable, Sendable { public var capture: Capture; public var folder: URL; public var filename: String }`
  - `public enum ExportNaming: Sendable { case original, numbered }`
  - `public struct ExportOptions: Equatable, Sendable { public var baseFolder: URL; public var makesGameFolder: Bool; public var naming: ExportNaming; public init(baseFolder: URL, makesGameFolder: Bool = true, naming: ExportNaming = .original) }`
  - `public extension TransferItem { static let defaultImportFolder: URL; static func imports(_ captures: [Capture], into root: URL = defaultImportFolder) -> [TransferItem]; static func exports(_ captures: [Capture], options: ExportOptions, timeZone: TimeZone = .current) -> [TransferItem] }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`@Suite("TransferItem 테스트")` 아래 `@Suite("가져올 곳")`, `@Suite("내보낼 이름")`. `seoul`은 `TimeZone(identifier: "Asia/Seoul")`, 기준 폴더는 `URL(filePath: "/tmp/blog")`입니다. 아래의 `\.folder.path`는 짧게 줄인 표기이고, 실제 테스트는 `{ $0.folder.path(percentEncoded: false) }`로 씁니다.

```swift
@Test func `가져올 곳은 게임 이름 폴더와 원래 파일 이름이다`() {
    let items = TransferItem.imports([captureFixture("a.jpg"), captureFixture("b.jpg", game: nil)], into: URL(filePath: "/p"))
    #expect(items.map(\.folder.path) == ["/p/젤다무쌍 봉인전기", "/p/기타"])
    #expect(items.map(\.filename) == ["a.jpg", "b.jpg"])
}

@Test func `게임 이름 폴더를 끄면 기준 폴더에 원래 이름으로 둔다`() {
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), makesGameFolder: false)
    #expect(TransferItem.exports([captureFixture("a.jpg")], options: options, timeZone: seoul).map(\.folder.path) == ["/tmp/blog"])
}

@Test func `번호를 붙이면 찍은 시각 오름차순으로 세 자리부터 센다`() {
    let captures = [
        captureFixture("2026111423400000_s.jpg", at: "2026-11-14 23:40:00"),
        captureFixture("2026111421120500_s.mp4", at: "2026-11-14 21:12:05", kind: .video),
    ]
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), naming: .numbered)
    let items = TransferItem.exports(captures, options: options, timeZone: seoul)
    #expect(items.map(\.filename) == ["001_20261114_211205.mp4", "002_20261114_234000.jpg"])
    #expect(items.map(\.folder.path) == ["/tmp/blog/젤다무쌍 봉인전기", "/tmp/blog/젤다무쌍 봉인전기"])
}

@Test func `같은 초에 찍은 캡처도 서로 다른 번호를 받는다`() {
    let captures = [
        captureFixture("2026101122320901_s.jpg", at: "2026-10-11 22:32:09"),
        captureFixture("2026101122320900_s.jpg", at: "2026-10-11 22:32:09"),
    ]
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), naming: .numbered)
    let items = TransferItem.exports(captures, options: options, timeZone: seoul)
    #expect(items.map(\.capture.filename) == ["2026101122320900_s.jpg", "2026101122320901_s.jpg"])
    #expect(items.map(\.filename) == ["001_20261011_223209.jpg", "002_20261011_223209.jpg"])
}

@Test func `천 개면 네 자리로 세고 번호는 게임 폴더마다 따로 센다`() {
    let many = (0 ..< 1000).map { captureFixture("\($0).jpg", at: "2026-11-14 21:12:05") }
    let other = [captureFixture("m.jpg", game: "Mario Kart World")]
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), naming: .numbered)
    let names = TransferItem.exports(many + other, options: options, timeZone: seoul).map(\.filename)
    #expect(names.first == "0001_20261114_211205.jpg")
    #expect(names.last == "001_20261114_211205.jpg")
}

@Test func `찍은 시각을 모르는 캡처는 번호 뒤에 원래 이름을 붙여 끝에 둔다`() {
    let options = ExportOptions(baseFolder: URL(filePath: "/tmp/blog"), naming: .numbered)
    let items = TransferItem.exports([captureFixture("x.jpg", at: nil), captureFixture("a.jpg")], options: options, timeZone: seoul)
    #expect(items.map(\.filename) == ["001_20261114_211205.jpg", "002_x.jpg"])
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferItemTests`
Expected: 컴파일 실패("cannot find 'TransferItem' in scope")

- [ ] **Step 3: `TransferItem`과 내보내기 옵션을 만듭니다**

- `defaultImportFolder`는 `URL.picturesDirectory.appending(path: "Pullshot")`입니다.
- `exports`는 폴더별로 묶고(폴더 순서는 입력에서 처음 나온 순서), 폴더 안에서 찍은 시각 오름차순, 시각이 같으면 파일 이름 순, 시각이 없으면 끝으로 정렬합니다. 번호 자릿수는 `max(3, 그 폴더 개수의 자릿수)`입니다.
- 번호 붙인 이름의 시각은 `yyyyMMdd_HHmmss`(`en_US_POSIX`, 주어진 시간대)이고, 확장자는 원래 파일 이름의 것을 그대로 씁니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "가져올 곳과 내보낼 이름 규칙 추가"
```

### Task 5: 옮기기 실행

**Files:**
- Create: `Sources/PullshotKit/Library/Transfer.swift`, `Tests/PullshotKitTests/Support/FakeDownloadSource.swift`
- Test: `Tests/PullshotKitTests/TransferTests.swift`

**Interfaces:**
- Consumes: `Session.download(_:expectedSize:to:progress:isCancelled:)`, `Session.isValid`, `DestinationNamer.decide(filename:size:in:)`(1단계), `TransferLedger.record`(Task 2), `TransferItem`(Task 4)
- Produces:
  - `public protocol DownloadSource: AnyObject { var isValid: Bool { get }; func download(_ handle: UInt32, expectedSize: UInt64?, to destination: URL, progress: (UInt64) -> Void, isCancelled: () -> Bool) throws }`, `extension Session: DownloadSource {}`
  - `public struct TransferProgress: Equatable, Sendable { public var index: Int; public var total: Int; public var capture: Capture; public var bytes: UInt64 }`
  - `public struct TransferFailure { public var capture: Capture; public var error: any Error }`
  - `public struct TransferSummary { public var saved: [URL]; public var skipped: Int; public var failures: [TransferFailure]; public var notAttempted: Int; public var isCancelled: Bool }`
  - `public struct Transfer { public init(source: DownloadSource, ledger: TransferLedger, serialNumber: String); public func run(_ items: [TransferItem], as kind: TransferKind, progress: (TransferProgress) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws -> TransferSummary }`
  - 테스트 지원: `final class FakeDownloadSource: DownloadSource { enum Outcome { case write, fail(any Error), disconnect, cancel }; var outcomes: [UInt32: Outcome]; private(set) var downloaded: [UInt32] }`. `write`는 `expectedSize`바이트(없으면 1바이트)를 쓰고, `disconnect`는 `isValid`를 거짓으로 바꾼 뒤 `SessionError.transport(.disconnected)`를, `cancel`은 `SessionError.cancelled`를 던집니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`@Suite("Transfer 테스트")` 아래 `@Suite("받기")`, `@Suite("이미 있는 파일")`, `@Suite("멈춤")`. 각 테스트는 `temporaryFolderFixture()`를 받을 곳과 기록 폴더로 씁니다. 캡처가 여럿이면 `captureFixture("\(n).jpg", handle: n)`으로 handle 1, 2, 3을 만들고 `TransferItem.imports`로 넘깁니다.

```swift
@Test func `받은 파일은 기록에 남고 만든 날짜와 수정 날짜가 찍은 시각이다`() throws {
    let (root, ledger, source) = try (temporaryFolderFixture(), TransferLedger(directory: temporaryFolderFixture()), FakeDownloadSource())
    let capture = captureFixture("a.jpg")
    let summary = try Transfer(source: source, ledger: ledger, serialNumber: "S1")
        .run(TransferItem.imports([capture], into: root), as: .imported)

    let attributes = try FileManager.default.attributesOfItem(atPath: summary.saved[0].path(percentEncoded: false))
    #expect(attributes[.creationDate] as? Date == capture.capturedAt)
    #expect(attributes[.modificationDate] as? Date == capture.capturedAt)
    #expect(ledger.isTransferred(capture, serialNumber: "S1"))
}

@Test func `같은 이름과 크기의 파일이 있으면 받지 않고 기록만 남긴다`() throws {
    // root/젤다무쌍 봉인전기/a.jpg에 5바이트를 미리 둡니다.
    #expect(source.downloaded.isEmpty)
    #expect(summary.skipped == 1)
    #expect(ledger.isTransferred(capture, serialNumber: "S1"))
}

@Test func `이름만 같은 파일이 있으면 번호를 붙여 따로 받고 원래 파일은 그대로 둔다`() throws {
    // root/젤다무쌍 봉인전기/a.jpg에 3바이트(0x01)를 미리 둡니다.
    #expect(summary.saved.map(\.lastPathComponent) == ["a 2.jpg"])
    #expect(try Data(contentsOf: original) == Data(repeating: 1, count: 3))
}

@Test func `한 캡처가 실패해도 나머지를 받는다`() throws {
    // handle 2의 결과: .fail(SessionError.response(.generalError, operation: .getObject))
    #expect(summary.saved.count == 2)
    #expect(summary.failures.map(\.capture.handle) == [2])
    #expect(summary.notAttempted == 0)
}

@Test func `연결이 끊기면 멈추고 시도하지 못한 수를 센다`() throws {
    // handle 1, 2, 3 중 2가 .disconnect
    #expect(summary.saved.count == 1)
    #expect(summary.failures.map(\.capture.handle) == [2])
    #expect(summary.notAttempted == 1)
    #expect(source.downloaded == [1, 2])
    #expect(ledger.newCaptures(captures, serialNumber: "S1").map(\.handle) == [2, 3])
}

@Test func `받는 중에 취소하면 남은 캡처를 받지 않고 받은 것만 기록한다`() throws {
    // handle 1, 2, 3 중 2가 .cancel
    #expect(summary.isCancelled)
    #expect(summary.saved.count == 1)
    #expect(summary.failures.isEmpty)
    #expect(summary.notAttempted == 2)
}

@Test func `캡처 사이에서 취소를 알아채면 다음 캡처를 시작하지 않는다`() throws {
    // isCancelled: { source.downloaded.count == 1 }
    #expect(source.downloaded == [1])
    #expect(summary.notAttempted == 2)
}

@Test func `진행은 캡처를 시작할 때와 바이트를 받을 때 알린다`() throws {
    // 캡처 두 개, progress를 배열에 모읍니다. 가짜 기기는 다 쓴 뒤 한 번 알립니다.
    #expect(reported.map(\.index) == [0, 0, 1, 1])
    #expect(reported.map(\.total) == [2, 2, 2, 2])
    #expect(reported.map(\.bytes) == [0, 5, 0, 5])
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferTests`
Expected: 컴파일 실패("cannot find 'Transfer' in scope")

- [ ] **Step 3: `DownloadSource`와 `Transfer`를 만듭니다**

캡처마다 이 순서로 처리합니다.

1. `isCancelled()`가 참이면 멈추고, 이 캡처부터 끝까지를 `notAttempted`로 셉니다. 아니면 `bytes: 0`으로 진행을 한 번 알립니다(건너뛰는 캡처도 전체 진행이 움직이도록).
2. 폴더를 만듭니다. 실패하면 그 캡처만 실패로 셉니다.
3. `DestinationNamer.decide`가 `.skip`이면 기록만 남기고 `skipped`를 셉니다. `.write`면 받습니다.
4. 받은 뒤 `[.creationDate, .modificationDate]`를 `capturedAt`으로 맞춥니다. 시각이 없거나 맞추지 못하면 로그만 남깁니다. 그다음 그 캡처를 기록에 남깁니다.
5. `SessionError.cancelled`면 `isCancelled`를 참으로 두고 이 캡처부터 끝까지를 `notAttempted`로 셉니다. 다른 오류는 실패로 세고, 그 뒤 `source.isValid`가 거짓이면 멈추고 남은 수를 `notAttempted`로 셉니다.

기록 쓰기 실패만 던집니다. 받은 파일을 기록 없이 남기면 다음 연결에서 새 항목으로 다시 보이기 때문입니다(그래도 같은 이름과 크기라 다시 받지는 않습니다).

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`
Expected: 모두 통과하고 위반이 없습니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "가져오기와 내보내기 실행 추가"
```

### Task 6: CLI 가져오기와 목록에 기록 잇기

**Files:**
- Create: `Sources/pullshot/CaptureSelection.swift`, `Sources/pullshot/LedgerOptions.swift`
- Modify: `Sources/pullshot/Pull.swift`, `Sources/pullshot/List.swift`, `Sources/pullshot/Dump.swift`, `Sources/PullshotKit/Support/ListFormatter.swift`
- Test: `Tests/PullshotCLITests/CaptureSelectionTests.swift`, `Tests/PullshotKitTests/CLISupportTests.swift`(목록 형식)

**Interfaces:**
- Consumes: `Game.games`, `Play`(Task 1), `TransferLedger`(Task 2, 3), `TransferItem.imports`(Task 4), `Transfer`(Task 5), `connection.info.serialNumber`
- Produces:
  - `struct CaptureSelection { var names: [String]; var game: String?; var isAll: Bool; var isNewOnly: Bool; func choose(from captures: [Capture], isNew: (Capture) -> Bool) -> (chosen: [Capture], missing: [String]) }`
  - `struct LedgerOptions: ParsableArguments { @Option(name: .customLong("ledger-folder"), help: "옮긴 기록을 둘 폴더입니다. 기본은 ~/Library/Application Support/Pullshot입니다.") var folder: String?; func open() throws -> TransferLedger }`
  - `ListFormatter.lines(_ scan: AlbumScan, isNew: (Capture) -> Bool = { _ in false }, showsPlays: Bool = false, timeZone: TimeZone) -> [String]`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`CaptureSelectionTests`(`@Suite("CaptureSelection 테스트")`):

```swift
@Test func `파일 이름이나 게임과 파일 이름으로 고르고 못 찾은 이름을 알린다`() {
    let selection = CaptureSelection(names: ["a.jpg", "Mario Kart World/m.jpg", "zz.jpg"], game: nil, isAll: false, isNewOnly: false)
    let result = selection.choose(from: [captureFixture("a.jpg"), captureFixture("m.jpg", game: "Mario Kart World")], isNew: { _ in true })
    #expect(result.chosen.map(\.filename) == ["a.jpg", "m.jpg"])
    #expect(result.missing == ["zz.jpg"])
}

@Test func `새 항목만 고르면 기록에 없는 캡처 중 그 게임 것만 남는다`() {
    let selection = CaptureSelection(names: [], game: "기타", isAll: false, isNewOnly: true)
    let captures = [captureFixture("a.jpg", game: nil), captureFixture("b.jpg", game: "기타"), captureFixture("c.jpg")]
    #expect(selection.choose(from: captures, isNew: { $0.filename != "b.jpg" }).chosen.map(\.filename) == ["a.jpg"])
}
```

`CLISupportTests`의 목록 형식에 더합니다(기존 두 테스트의 기대값은 그대로 통과해야 합니다).

```swift
@Test func `새 항목에는 줄 끝에 새를 붙인다`() {
    let scan = AlbumScan(captures: [captureFixture("2026111421120500_s.jpg")], skipped: [])
    #expect(ListFormatter.lines(scan, isNew: { _ in true }, timeZone: Self.seoul) == [
        "젤다무쌍 봉인전기 (1)",
        "  2026111421120500_s.jpg  사진  0.0 MB  2026-11-14 21:12  새",
    ])
}

@Test func `플레이로 보면 플레이 제목 아래에 찍은 순서로 둔다`() {
    let scan = AlbumScan(captures: [
        captureFixture("b.jpg", at: "2026-11-14 23:40:00"),
        captureFixture("a.mp4", at: "2026-11-14 21:12:05", kind: .video),
    ], skipped: [])
    #expect(ListFormatter.lines(scan, showsPlays: true, timeZone: Self.seoul) == [
        "젤다무쌍 봉인전기 (2)",
        "  플레이 2026-11-14 21:12 ~ 23:40 · 사진 1 · 영상 1",
        "    a.mp4  영상  0.0 MB  2026-11-14 21:12",
        "    b.jpg  사진  0.0 MB  2026-11-14 23:40",
    ])
}
```

크기 칸 표기(`0.0 MB`)는 1단계 `ListFormatter`의 기존 형식을 따릅니다. 기존 형식이 다르면 기존 형식에 맞춰 기대값을 고치고 원장에 적습니다.

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter "CaptureSelectionTests|CLISupportTests"`
Expected: 컴파일 실패("cannot find 'CaptureSelection' in scope", "extra argument 'isNew'")

- [ ] **Step 3: 목록 형식, 고르기, 기록 옵션을 만들고 `pull`과 `list`에 잇습니다**

- `ListFormatter.lines`는 `Game.games(in: scan.captures)`로 묶습니다. 플레이 제목은 `플레이 <시작> ~ <끝 HH:mm> · 사진 N · 영상 N`이고, 0개인 종류는 뺍니다. 시각을 모르는 플레이는 `플레이 시각 모름 · 사진 N`입니다.
- `pull`: `Pull.swift`의 고르기를 `CaptureSelection`으로 옮기고 `--new` 플래그를 더합니다. `validate`는 `--all`, `--new`, 이름 중 하나를 요구합니다. 받기는 `TransferItem.imports(_, into: out)`과 `Transfer.run(_, as: .imported)`로 하고, 요약은 `저장 N개, 건너뜀 N개, 실패 N개, 받지 못함 N개`입니다. 취소면 종료 코드 130, 실패나 받지 못함이 있으면 1입니다. `Tally`와 `save`는 지웁니다.
- `list`: `--new`(새 항목만)와 `--plays`(플레이 제목) 플래그를 더하고, 새 항목 표시는 늘 켭니다.
- `pull`과 `list`는 `needsFirstConnectQuestion`이 참이면 표준 오류에 `처음 연결한 기기입니다. 이미 받아 둔 캡처가 있으면 pullshot ledger --from-folder <폴더>로 기록에 넣어 주세요.`를 쓰고 계속합니다.
- `dump`의 `ListFormatter.lines` 호출은 기본값으로 그대로 둡니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test` 뒤 `make check`, 그리고 `swift run pullshot pull --help`
Expected: 모두 통과하고 위반이 없으며, 도움말에 `--new`와 `--ledger-folder`가 나옵니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources Tests
git commit -m "CLI 가져오기와 목록에 옮긴 기록 연결"
```

### Task 7: CLI 내보내기와 처음 연결 답 명령

**Files:**
- Create: `Sources/pullshot/Export.swift`, `Sources/pullshot/Ledger.swift`
- Modify: `Sources/pullshot/Pullshot.swift`(하위 명령 추가), `Sources/pullshot/Terminal.swift`(`CancellationError`도 "취소했습니다."와 130), `README.md`(CLI 절 추가)
- Test: `Tests/PullshotCLITests/ErrorMessagesTests.swift`에는 더할 것이 없으면 그대로 둡니다. 이 태스크의 동작은 Task 4, 5, 3의 Kit 테스트가 맡고, 명령은 도움말과 Task 8 실기기로 확인합니다.

**Interfaces:**
- Consumes: `CaptureSelection`, `LedgerOptions`(Task 6), `TransferItem.exports`, `ExportOptions`(Task 4), `Transfer`(Task 5), `answerFirstConnectQuestion`(Task 3)

- [ ] **Step 1: `export` 명령을 만듭니다**

`pullshot export [이름…] [--game G] [--all] [--new] --out <기준 폴더> [--numbered] [--no-game-folder] [--dry-run]`. `--dry-run`은 연결과 훑기만 하고 `폴더/파일 이름`을 한 줄씩 출력합니다. 설계 6.4의 파일 이름 미리보기를 CLI로 보는 방법입니다. 실제 내보내기는 `Transfer.run(_, as: .exported)`이고 요약과 종료 코드는 `pull`과 같습니다.

- [ ] **Step 2: `ledger` 명령을 만듭니다**

`pullshot ledger (--from-folder <폴더> | --mark-all | --leave-new)`. 셋 중 하나만 받습니다(`validate`). 연결하고 훑은 뒤 `answerFirstConnectQuestion`을 부르고 `기록에 넣은 캡처 N개`를 출력합니다. 이미 답한 기기에서도 실행할 수 있습니다.

- [ ] **Step 3: README에 CLI 절을 더합니다**

`## CLI` 절에 `probe`, `list [--new] [--plays]`, `pull`, `export`, `ledger`, `dump`를 한 줄씩 적고, 옮긴 기록 위치와 새 항목의 뜻을 한 문장으로 적습니다.

- [ ] **Step 4: 확인합니다**

Run: `swift test`, `make check`, `swift run pullshot export --help`, `swift run pullshot ledger --help`, `swift run pullshot ledger`(답 없이)
Expected: 모두 통과하고 위반이 없으며, 마지막 명령은 "--from-folder, --mark-all, --leave-new 중 하나를 주세요."와 종료 코드 64가 나옵니다

- [ ] **Step 5: 커밋합니다**

```bash
git add Sources README.md
git commit -m "CLI 내보내기와 처음 연결 답하기 추가"
```

### Task 8: 실기기 확인 (사용자와 10분)

사용자가 스위치 2를 PC로 복사 모드로 연결해 둔 상태에서 합니다. 실제 기록을 더럽히지 않도록 모든 명령에 `--ledger-folder "$S/ledger"`를 붙이고, `S`는 세션 스크래치 폴더입니다.

**Files:**
- Modify: `docs/hardware-notes.md`(2단계 확인 절 추가)

- [ ] **Step 1: 플레이 나누기를 실제 캡처로 봅니다**

Run: `swift run pullshot list --plays --game "<캡처가 가장 많은 게임>" --ledger-folder "$S/ledger" | head -60`
Expected: 플레이 제목이 실제로 앉아서 한 단위와 맞는지 사용자에게 보여 주고 의견을 받습니다. 60분이 맞지 않다는 의견이면 사용자가 정한 값으로 `Play.maxGap`을 바꾸는 커밋을 따로 합니다.

- [ ] **Step 2: 새 항목 가져오기를 두 번 합니다**

Run: `swift run pullshot pull --new --game "<영상이 있는 작은 게임>" --out "$S/import" --ledger-folder "$S/ledger"`를 두 번
Expected: 첫 번째는 처음 연결 안내와 함께 모두 저장, 두 번째는 `저장 0개`. 받은 파일의 `stat -f "%SB %Sm"`이 `list`의 찍은 시각과 같습니다.

- [ ] **Step 3: 번호 붙여 내보내기를 합니다**

Run: `swift run pullshot export --game "<같은 게임>" --all --numbered --out "$S/blog" --dry-run --ledger-folder "$S/ledger"` 뒤 `--dry-run` 없이 한 번 더
Expected: 미리보기 이름과 실제 이름이 같고, `001_`부터 찍은 순서입니다.

- [ ] **Step 4: 폴더에서 찾기를 합니다**

사용자에게 예전에 받아 둔 캡처가 있는 폴더를 묻습니다. 없으면 Step 2의 `$S/import`를 씁니다.
Run: `swift run pullshot ledger --from-folder "<폴더>" --ledger-folder "$S/ledger2"` 뒤 `swift run pullshot list --new --ledger-folder "$S/ledger2" | head`
Expected: 찾은 수가 출력되고, 그 캡처는 `--new` 목록에서 빠집니다.

- [ ] **Step 5: 기록하고 커밋합니다**

`docs/hardware-notes.md`에 "2단계 확인" 절을 더해 플레이 나누기에 대한 사용자 의견, 가져오기와 내보내기 결과, 폴더에서 찾기 결과(개수만)를 적습니다. 경로와 일련번호는 적지 않습니다.

```bash
git add docs/hardware-notes.md
git commit -m "2단계 실기기 확인 결과 추가"
```
