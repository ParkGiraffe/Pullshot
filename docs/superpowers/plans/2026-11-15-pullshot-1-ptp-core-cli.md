# Pullshot 1단계: PTP 핵심과 CLI 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스위치를 USB로 연결해 기기 정보, 게임별 캡처 목록, 썸네일, 원본 파일을 받아 오는 라이브러리(PullshotKit)와 개발용 CLI(`pullshot`)를 만들고, 실기기로 검증합니다.

**Architecture:** PullshotKit 안에서 PTP 프로토콜(바이트, 컨테이너, 데이터셋, 세션)을 `Transport` 프로토콜 뒤에 두고, 실제 USB 전송(`HostTransport`)과 테스트용 가짜 전송, 기록과 재생 전송을 갈아 끼웁니다. 앨범 훑기는 세션 위의 `AlbumSource` 프로토콜에만 기대어 가짜 앨범으로 테스트합니다. CLI는 Kit을 묶기만 합니다.

**Tech Stack:** Swift 6.2 도구(로컬 Swift 6.3), SwiftPM, macOS 15 이상, IOKit과 IOUSBHost, Swift Testing, swift-argument-parser(CLI만), SwiftLint, SwiftFormat.

**Spec:** `docs/superpowers/specs/2026-11-15-pullshot-design.md` (리포를 만들기 전에는 `~/Desktop/Coding/Tethersnap/.claude/plans/new-app/design.md`)

**이 계획의 범위:** 세 계획 중 첫 번째입니다. 2단계는 보관함 로직(플레이 나누기, 옮긴 기록, 처음 연결 창, 가져오기와 내보내기), 3단계는 SwiftUI 앱입니다. 2단계와 3단계는 Task 13의 실기기 결과(일련번호가 세션마다 같은지, 파일 이름 형식)를 보고 씁니다.

## Global Constraints

- 리포 `~/Desktop/Coding/Pullshot`, 기본 브랜치 `main`. GitHub 공개 리포(`ParkGiraffe/Pullshot`) 만들기와 푸시는 사용자에게 확인받은 뒤에 합니다.
- `swift-tools-version: 6.2`, `platforms: [.macOS(.v15)]`.
- PullshotKit은 외부 의존성이 없습니다. swift-argument-parser는 CLI 타깃만 씁니다. libgphoto2, libmtp는 쓰지 않습니다.
- Tethersnap 리포의 `Sources/`와 `Tests/`를 열지 않습니다. 필요한 사실은 설계 문서 3절과 이 계획에 있습니다. 타입과 파일 이름도 Tethersnap과 다르게 짓습니다.
- USB ID: Switch 2 `0x057E:0x2061`, Switch 1 `0x057E:0x201D`(실험적 지원).
- 쓰는 PTP 명령은 기본 명령 `0x1001`~`0x100A`뿐입니다. 평면 목록 질의(GetObjectHandles의 세 번째 인자 `0x00000000`)는 보내지 않습니다.
- 핸들과 저장소 ID는 세션 안에서만 쓰고 저장하지 않습니다.
- 기기를 다른 앱이 잡은 오류 `0xE00002C5`, `0xE00002C9`는 일반 오류가 아니라 안내 문구로 보여 줍니다.
- 받은 파일은 바이트 그대로 저장합니다. 같은 폴더의 임시 파일에 쓰고 끝나면 이름을 바꾸며, 실패나 취소 때는 임시 파일을 지웁니다. 이미 있는 파일을 덮어쓰지 않습니다.
- 통합 로그(`os.Logger`, subsystem `com.parkgiraffe.Pullshot`)에서 파일 이름, 게임 이름, 경로, 일련번호는 `privacy: .private`로 남깁니다.
- 실기기 덤프(`LocalFixtures/`)는 일련번호와 사용자 캡처가 들어 있으므로 커밋하지 않습니다.
- 커밋 메시지는 한국어 `{대상} {액션}` 형식(pr-title)이고, cue의 커밋 규칙을 함께 지킵니다. 72자 이내, 마침표 없음, 명사형 종결, 식별자는 표기 그대로입니다. 본문이 필요하면 하십시오체로 무엇을, 왜 바꿨는지 적습니다. `Co-Authored-By`, `Generated with` 표기를 넣지 않습니다.
- `make check`(SwiftLint `--strict`, SwiftFormat `--lint`)가 통과해야 커밋합니다.
- 코딩 규칙의 정본은 Task 1에서 만드는 `docs/conventions.md`입니다. cue의 코드 작성 원칙과 규칙 파일, Tethersnap의 SwiftLint, SwiftFormat, pre-commit 설정을 Swift에 맞게 옮긴 것이고, 둘이 부딪히면 cue를 따릅니다. 구현과 리뷰는 매 태스크 이 문서를 기준으로 합니다.
- 테스트 이름: 이 계획의 테스트 함수 이름(`readsLittleEndianIntegers` 등)은 자리표시입니다. 구현할 때는 `@Suite("<타입> 테스트")` 아래에 동작별 `@Suite("<동작>")`을 두고, 테스트는 한국어 도메인 문장의 raw identifier로 씁니다. 예: ``@Test func `세션 없이 기기 정보를 거부하면 세션 안에서 다시 받는다`()``. 단언(`#expect`)과 값은 계획 그대로입니다. Swift 6.3에서 동작을 확인했습니다.
- 오류는 Kit이 도메인 오류 그대로 던지고, 사용자 문구로 바꾸는 일은 가장자리(CLI의 `ErrorMessages`, 3단계의 앱)에서 한 곳에 모아 합니다. Kit 타입에는 사용자 문구를 두지 않습니다.
- 새 패키지는 추가하기 전에 사용자에게 제안하고 승인을 받습니다. 지금 승인된 것은 swift-argument-parser 하나입니다.

## Review Focus

1. 게임 폴더와 파일 이름의 한글, 악센트(é), 보조 평면 문자: PTP 문자열(UTF-16LE)에서 깨지지 않아야 합니다. Task 1의 `ptpStringRoundTripsNonASCIIText`가 맡습니다.
2. 내려받는 중 케이블 뽑기: 목적지에도 임시 파일에도 아무것도 남지 않고 세션은 무효가 되어야 합니다. Task 6의 `failedDownloadLeavesNoFiles`가 맡습니다.
3. 받을 곳에 같은 이름 파일이 이미 있을 때: 덮어쓰지 않습니다. Task 6의 `downloadRefusesToOverwrite`와 Task 12의 `uniqueDestination…` 테스트가 맡습니다.
4. 기기가 보낸 파일 이름이 비었거나 `..`, `/`, NUL을 담을 때: 받을 폴더 밖에 쓰지 않도록 그 항목을 건너뜁니다. Task 8의 `unsafeFilenamesAreSkipped`가 맡습니다.
5. 객체 하나나 저장소 하나를 읽지 못할 때: 훑기 전체가 멈추지 않고 그 항목만 건너뜁니다. Task 8의 `objectInfoFailureIsSkipped`, `unavailableStorageIsSkipped`가 맡습니다.

## 파일 구조

```
Pullshot/
  Package.swift  Makefile  Brewfile  .gitignore  .swiftlint.yml  .swiftformat
  LICENSE  README.md  THIRD_PARTY_LICENSES.md
  Scripts/git-hooks/pre-commit
  docs/superpowers/specs/2026-11-15-pullshot-design.md, mockups/
  docs/superpowers/plans/2026-11-15-pullshot-1-ptp-core-cli.md
  docs/conventions.md docs/glossary.md        (Task 1)
  docs/hardware-notes.md                      (Task 13)
  Sources/PullshotKit/
    Protocol/ByteReader.swift ByteWriter.swift DecodingError.swift
    Protocol/PTP.swift                         코드 상수(명령, 응답, 컨테이너 종류, 객체 형식)
    Protocol/Container.swift                   컨테이너와 헤더
    Protocol/DeviceInfo.swift StorageInfo.swift ObjectInfo.swift DateTimeString.swift
    Protocol/PacketBuffer.swift
    Session/Transport.swift                    전송 프로토콜과 TransportError
    Session/Session.swift Session+Download.swift Session+Open.swift SessionError.swift
    Session/TransferLog.swift                  RecordingTransport, ReplayTransport
    Album/Capture.swift AlbumScanner.swift
    Console/ConsoleModel.swift ConsoleAccessError.swift ConsoleLocator.swift
    Console/HostTransport.swift EndpointSelection.swift
    Support/Log.swift DestinationNamer.swift ListFormatter.swift
  Sources/pullshot/                            CLI (Task 12)
  Tests/PullshotKitTests/
    Support/ScriptedTransport.swift Support/Fixtures.swift Support/FakeAlbumSource.swift
    …Tests.swift (태스크마다 하나)
  Tests/PullshotCLITests/ErrorMessagesTests.swift (Task 12)
  LocalFixtures/                               (.gitignore, Task 13)
```

---

### Task 1: 패키지 골격과 PTP 바이트 코딩

**Files:**
- Create: `Package.swift`, `.gitignore`, `.swiftlint.yml`, `.swiftformat`, `Brewfile`, `Makefile`, `Scripts/git-hooks/pre-commit`, `LICENSE`, `README.md`
- Create: `Sources/PullshotKit/Protocol/ByteReader.swift`, `ByteWriter.swift`, `DecodingError.swift`
- Create: `docs/superpowers/specs/`(설계 문서와 `mockups/` 복사), `docs/superpowers/plans/`(이 계획 복사)
- Test: `Tests/PullshotKitTests/ByteCodingTests.swift`

**Interfaces:**
- Produces:
  - `public struct ByteReader { init(_ data: Data); var remaining: Int; mutating func u8/u16/u32/u64() throws -> UIntN; mutating func string() throws -> String; mutating func u16Array() throws -> [UInt16]; mutating func u32Array() throws -> [UInt32]; mutating func bytes(_ count: Int) throws -> Data }`
  - `public struct ByteWriter { init(); private(set) var data: Data; mutating func u8/u16/u32/u64(_:); mutating func string(_:); mutating func u16Array(_:); mutating func u32Array(_:); mutating func bytes(_:) }`
  - `public enum PTPDecodingError: Error, Equatable { case truncated(needed: Int, available: Int), badString, badContainerLength(UInt32), unknownContainerKind(UInt16) }`

- [ ] **Step 1: 리포와 도구 설정을 만듭니다**

```bash
mkdir -p ~/Desktop/Coding/Pullshot && cd ~/Desktop/Coding/Pullshot && git init -b main
brew bundle   # swiftlint, swiftformat (이미 있으면 그대로 지나감)
```

- `Package.swift`: 이름 `Pullshot`, `defaultLocalization: "ko"`, 제품 `.library(name: "PullshotKit")`, 타깃 `PullshotKit`(경로 `Sources/PullshotKit`), 테스트 타깃 `PullshotKitTests`. CLI 타깃과 swift-argument-parser는 Task 12에서 더합니다.
- `.gitignore`: `.build/`, `.swiftpm/`, `.DS_Store`, `LocalFixtures/`, `dist/`.
- `.swiftlint.yml`: Tethersnap과 같은 규칙 묶음을 새로 씁니다. `disabled_rules: [function_body_length, function_parameter_count, identifier_name, large_tuple, trailing_whitespace]`, `opt_in_rules: [contains_over_filter_count, empty_count, first_where, force_unwrapping, for_where, implicit_return, prefer_self_in_static_references, private_over_fileprivate, sorted_first_last]`, `included: [Sources, Tests]`, `excluded: [.build]`, `trailing_comma: { mandatory_comma: true }`, `line_length: 120`(cue의 printWidth). `identifier_name`을 끄는 것은 한국어 raw identifier 테스트 이름 때문입니다.
- `.swiftformat`: `--swiftversion 6.2 --indent 4 --maxwidth 120 --trailing-commas collections-only --hexliteralcase uppercase --ranges spaced --importgrouping testable-bottom --self remove --wraparguments preserve --wrapcollections preserve --header ignore`, `--enable docComments,isEmpty,preferFinalClasses,redundantThrows,sortImports,unusedPrivateDeclarations`, `--disable consecutiveSpaces,markTypes,redundantSelf,unusedArguments`.
- `docs/conventions.md`: 아래 내용을 한국어로 정리합니다. cue 문서를 그대로 옮기지 않고 우리 말로 씁니다(cue 코드와 문서는 공개 리포에 올리지 않습니다).
  - 원칙 여섯: 가독성 우선, 최소한의 코드와 기본값 생략, 구현이 아니라 동작과 도메인을 드러내는 이름, 도메인 언어의 테스트 제목, 코드 스멜은 보는 즉시 리팩터링, 생각 단위로 빈 줄
  - 이름: Bool은 `is`, `has`, `can`, `should`, 한 시점의 사건은 과거분사(`opened`), 함수가 아닌 값은 명사(구), 한 번만 쓰는 값은 이름이 뜻을 더할 때만 변수로 둠
  - 제어 흐름: 같은 열거값으로 가를 때만 `switch`, 나머지는 `if`
  - 테스트: 타입별 `@Suite("<타입> 테스트")`, 동작별 하위 `@Suite`, 한국어 문장 테스트 이름, 픽스처는 `<대상>Fixture(...)` 함수와 기본값
  - 오류: Kit은 던지고, 문구 변환은 가장자리 한 곳
  - 주석: 무엇이 아니라 왜. 실기기에서 확인한 사실은 날짜와 펌웨어를 함께 적음. 선언 앞 설명은 `///`
  - 로그: 파일 이름, 게임 이름, 경로, 일련번호는 `privacy: .private`
  - 커밋: 위 Global Constraints의 커밋 규칙
- `docs/glossary.md`: 용어, 뜻, 코드 이름 세 칸 표입니다. 기기(`Console`), 캡처(`Capture`), 게임(`gameFolder`), 앨범(`AlbumScan`), 세션(`Session`), 전송(`Transport`), 옮김(2단계), 새 항목(2단계), 플레이(2단계)를 적습니다.
- `Brewfile`: `brew "swiftlint"`, `brew "swiftformat"`.
- `Makefile`: `build`(`swift build`), `test`(`swift test`), `lint`, `format`, `check`(`swiftlint --strict && swiftformat --lint .`), `setup-hooks`(`git config core.hooksPath Scripts/git-hooks`).
- `Scripts/git-hooks/pre-commit`: 스테이징된 `.swift` 파일에 `swiftlint --strict`와 `swiftformat --lint`를 돌립니다.
- `LICENSE`: MIT, `Copyright (c) 2026 ParkGiraffe`.
- `README.md`: 한 줄 소개, "Nintendo Switch 2, Nintendo Switch(실험적)의 캡처를 USB로 Mac에 옮기는 앱", 면책 문구("Pullshot은 Nintendo와 관계없는 독립 오픈소스 프로젝트입니다. Nintendo Switch는 Nintendo의 상표이며, 호환 기기를 설명하는 데만 씁니다."), 감사의 글("스위치의 PTP 동작에 관한 사실은 Tethersnap(https://github.com/Luminoid/Tethersnap)의 README와 CHANGELOG에서 배웠습니다. 코드는 가져오지 않았습니다.").
- 설계 문서, `mockups/`, 이 계획을 `docs/superpowers/` 아래로 복사합니다.

- [ ] **Step 2: 실패하는 테스트를 씁니다**

```swift
import Foundation
import Testing
@testable import PullshotKit

@Suite struct ByteCodingTests {
    @Test func readsLittleEndianIntegers() throws {
        var reader = ByteReader(Data([0x01, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12,
                                      0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01]))
        #expect(try reader.u8() == 0x01)
        #expect(try reader.u16() == 0x1234)
        #expect(try reader.u32() == 0x1234_5678)
        #expect(try reader.u64() == 0x0123_4567_89AB_CDEF)
        #expect(reader.remaining == 0)
    }

    @Test func ptpStringLayoutCountsTheTerminator() {
        var writer = ByteWriter()
        writer.string("AB")
        #expect(writer.data == Data([0x03, 0x41, 0x00, 0x42, 0x00, 0x00, 0x00]))
        var empty = ByteWriter()
        empty.string("")
        #expect(empty.data == Data([0x00]))
    }

    @Test func ptpStringRoundTripsNonASCIIText() throws {
        for text in ["젤다무쌍 봉인전기", "Pokémon LEGENDS Z-A", "𝄞 악보", ""] {
            var writer = ByteWriter()
            writer.string(text)
            var reader = ByteReader(writer.data)
            #expect(try reader.string() == text)
        }
    }

    @Test func arraysCarryA32BitCount() throws {
        var writer = ByteWriter()
        writer.u16Array([0x1001, 0x100A])
        #expect(writer.data == Data([0x02, 0, 0, 0, 0x01, 0x10, 0x0A, 0x10]))
        var reader = ByteReader(writer.data)
        #expect(try reader.u16Array() == [0x1001, 0x100A])
    }

    @Test func truncatedInputThrows() {
        var reader = ByteReader(Data([0x01]))
        #expect(throws: PTPDecodingError.truncated(needed: 2, available: 1)) { try reader.u16() }
    }
}
```

- [ ] **Step 3: 실패를 확인합니다**

Run: `swift test --filter ByteCodingTests`
Expected: 컴파일 실패("cannot find 'ByteReader' in scope")

- [ ] **Step 4: `ByteReader`, `ByteWriter`, `PTPDecodingError`를 구현합니다**

PTP 문자열은 첫 바이트가 종결 문자를 포함한 UTF-16 코드 단위 수(0이면 빈 문자열)이고, 이어서 UTF-16LE 코드 단위와 `0x0000` 종결 문자가 옵니다. 쓰기는 254 코드 단위를 넘으면 `precondition`으로 막습니다. 읽기에서 잘못된 UTF-16이면 `badString`을 던집니다. 배열은 `u32` 개수 뒤에 원소가 이어집니다. `Data` 조각(`dropFirst` 결과)은 시작 인덱스가 0이 아닐 수 있으므로 `init`에서 `Data(data)`로 복사해 0부터 읽습니다.

- [ ] **Step 5: 통과를 확인합니다**

Run: `swift test --filter ByteCodingTests && make check`
Expected: 5개 테스트가 통과하고, 린트와 포맷 위반이 없습니다.

- [ ] **Step 6: 커밋합니다**

모든 커밋은 `ptp-core-cli` 브랜치에 쌓습니다. `main`으로 합치는 일은 사용자가 정합니다.

```bash
make setup-hooks
git switch -c ptp-core-cli
git add docs LICENSE README.md && git commit -m "Pullshot 설계 문서와 코딩 규칙 정의"
git add -A && git commit -m "패키지 골격과 PTP 바이트 코딩 추가"
```

### Task 2: PTP 코드와 컨테이너

**Files:**
- Create: `Sources/PullshotKit/Protocol/PTP.swift`, `Container.swift`
- Test: `Tests/PullshotKitTests/ContainerTests.swift`

**Interfaces:**
- Consumes: `ByteReader`, `ByteWriter`, `PTPDecodingError` (Task 1)
- Produces:
  - `public enum PTP` 네임스페이스. `PTP.allStorages: UInt32 = 0xFFFF_FFFF`, `PTP.rootParent: UInt32 = 0xFFFF_FFFF`, `PTP.sessionID: UInt32 = 1`
  - `PTP.ContainerKind: UInt16 { command = 1, data = 2, response = 3, event = 4 }`
  - `PTP.Operation: RawRepresentable<UInt16>, Hashable, Sendable`: `getDeviceInfo 0x1001, openSession 0x1002, closeSession 0x1003, getStorageIDs 0x1004, getStorageInfo 0x1005, getNumObjects 0x1006, getObjectHandles 0x1007, getObjectInfo 0x1008, getObject 0x1009, getThumb 0x100A`, `static let baseline: [Operation]`(위 10개 순서대로)
  - `PTP.Response: RawRepresentable<UInt16>, Hashable, Sendable`: `ok 0x2001, generalError 0x2002, sessionNotOpen 0x2003, invalidTransactionID 0x2004, operationNotSupported 0x2005, parameterNotSupported 0x2006, incompleteTransfer 0x2007, invalidObjectHandle 0x2009, accessDenied 0x200F, noThumbnailPresent 0x2010, storeNotAvailable 0x2013, deviceBusy 0x2019, sessionAlreadyOpen 0x201E`
  - `PTP.ObjectFormat: RawRepresentable<UInt16>, Hashable, Sendable`: `undefined 0x3000, association 0x3001, mpeg 0x300B, exifJPEG 0x3801, png 0x380B, mp4Container 0xB982`
  - `public struct ContainerHeader: Equatable { length: UInt32; kind: PTP.ContainerKind; code: UInt16; transactionID: UInt32; static let size = 12; init(_ data: Data) throws }`
  - `public struct Container: Equatable { kind; code: UInt16; transactionID: UInt32; payload: Data; func encoded() -> Data; static func command(_ op: PTP.Operation, transactionID: UInt32, parameters: [UInt32] = []) -> Container; var parameters: [UInt32] }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct ContainerTests {
    @Test func commandContainerLayout() {
        let container = Container.command(.openSession, transactionID: 0, parameters: [1])
        #expect(container.encoded() == Data([0x10, 0, 0, 0, 0x01, 0x00, 0x02, 0x10,
                                             0, 0, 0, 0, 0x01, 0, 0, 0]))
    }

    @Test func headerParsesLengthKindCodeAndTransaction() throws {
        let header = try ContainerHeader(Data([0x0C, 0, 0, 0, 0x03, 0x00, 0x01, 0x20, 0x05, 0, 0, 0]))
        #expect(header == ContainerHeader(length: 12, kind: .response, code: 0x2001, transactionID: 5))
    }

    @Test func headerRejectsImpossibleLengthAndKind() {
        #expect(throws: PTPDecodingError.badContainerLength(8)) {
            try ContainerHeader(Data([8, 0, 0, 0, 3, 0, 0x01, 0x20, 0, 0, 0, 0]))
        }
        #expect(throws: PTPDecodingError.unknownContainerKind(9)) {
            try ContainerHeader(Data([12, 0, 0, 0, 9, 0, 0x01, 0x20, 0, 0, 0, 0]))
        }
    }

    @Test func responseParametersDecode() {
        var payload = ByteWriter()
        payload.u32(7)
        payload.u32(9)
        let container = Container(kind: .response, code: 0x2001, transactionID: 1, payload: payload.data)
        #expect(container.parameters == [7, 9])
    }

    @Test func baselineIsTheTenStandardOperations() {
        #expect(PTP.Operation.baseline.map(\.rawValue) == Array(0x1001 ... 0x100A))
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter ContainerTests`
Expected: 컴파일 실패("cannot find 'Container' in scope")

- [ ] **Step 3: `PTP`, `ContainerHeader`, `Container`를 구현합니다**

`command`는 인자를 5개까지만 받습니다(`precondition`). 길이는 헤더 12바이트에 페이로드를 더한 값입니다. `ContainerHeader.init(_ data:)`는 extension에 둬서 테스트가 쓰는 멤버별 init을 남깁니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter ContainerTests && make check`
Expected: 5개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "PTP 컨테이너 추가"
```

### Task 3: PTP 데이터셋과 날짜 해석

**Files:**
- Create: `Sources/PullshotKit/Protocol/DeviceInfo.swift`, `StorageInfo.swift`, `ObjectInfo.swift`, `DateTimeString.swift`
- Create: `Tests/PullshotKitTests/Support/Fixtures.swift`
- Test: `Tests/PullshotKitTests/DatasetTests.swift`

**Interfaces:**
- Consumes: `ByteReader`, `ByteWriter`, `PTP.ObjectFormat`
- Produces:
  - `public struct DeviceInfo: Equatable, Sendable { standardVersion: UInt16; vendorExtensionID: UInt32; operationsSupported: [UInt16]; manufacturer: String; model: String; deviceVersion: String; serialNumber: String; init(_ data: Data) throws }`
  - `public struct StorageInfo: Equatable, Sendable { storageType: UInt16; maxCapacity: UInt64?; freeSpace: UInt64?; storageDescription: String; volumeLabel: String; init(_ data: Data) throws }` (용량이 `0xFFFF_FFFF_FFFF_FFFF`이면 `nil`)
  - `public struct ObjectInfo: Equatable, Sendable { storageID: UInt32; format: PTP.ObjectFormat; compressedSize: UInt32; parent: UInt32; filename: String; captureDate: String; modificationDate: String; var isFolder: Bool; init(_ data: Data) throws }`
  - `public enum DateTimeString { static func parse(_ text: String, timeZone: TimeZone) -> Date? }`
  - 테스트 지원: `Fixtures.deviceInfo(model:serial:version:operations:) -> Data`, `Fixtures.storageInfo(maxCapacity:) -> Data`, `Fixtures.objectInfo(filename:format:size:parent:storageID:captureDate:) -> Data`

데이터셋 필드 순서(PIMA 15740):
- DeviceInfo: StandardVersion u16, VendorExtensionID u32, VendorExtensionVersion u16, VendorExtensionDesc 문자열, FunctionalMode u16, OperationsSupported u16 배열, EventsSupported u16 배열, DevicePropertiesSupported u16 배열, CaptureFormats u16 배열, ImageFormats u16 배열, Manufacturer, Model, DeviceVersion, SerialNumber 문자열
- StorageInfo: StorageType u16, FilesystemType u16, AccessCapability u16, MaxCapacity u64, FreeSpaceInBytes u64, FreeSpaceInImages u32, StorageDescription, VolumeLabel 문자열
- ObjectInfo: StorageID u32, ObjectFormat u16, ProtectionStatus u16, ObjectCompressedSize u32, ThumbFormat u16, ThumbCompressedSize u32, ThumbPixWidth u32, ThumbPixHeight u32, ImagePixWidth u32, ImagePixHeight u32, ImageBitDepth u32, ParentObject u32, AssociationType u16, AssociationDesc u32, SequenceNumber u32, Filename, CaptureDate, ModificationDate, Keywords 문자열

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct DatasetTests {
    @Test func deviceInfoParsesIdentityAndOperations() throws {
        let info = try DeviceInfo(Fixtures.deviceInfo(model: "Nintendo Switch 2", serial: "TEST0001",
                                                      version: "23.0.1", operations: Array(0x1001 ... 0x100A)))
        #expect(info.model == "Nintendo Switch 2")
        #expect(info.serialNumber == "TEST0001")
        #expect(info.deviceVersion == "23.0.1")
        #expect(info.operationsSupported == Array(0x1001 ... 0x100A))
    }

    @Test func storageCapacityOfAllOnesIsUnknown() throws {
        let info = try StorageInfo(Fixtures.storageInfo(maxCapacity: .max))
        #expect(info.maxCapacity == nil)
        #expect(info.freeSpace == nil)
    }

    @Test func objectInfoParsesNameFolderAndDates() throws {
        let info = try ObjectInfo(Fixtures.objectInfo(filename: "젤다무쌍 봉인전기", format: .association, size: 0,
                                                      parent: 0, storageID: 0x0001_0001, captureDate: ""))
        #expect(info.isFolder)
        #expect(info.filename == "젤다무쌍 봉인전기")
        let photo = try ObjectInfo(Fixtures.objectInfo(filename: "20261114211205_1.jpg", format: .exifJPEG,
                                                       size: 1_153_024, parent: 0x10, storageID: 0x0001_0001,
                                                       captureDate: "20261114T211205"))
        #expect(photo.compressedSize == 1_153_024)
        #expect(photo.parent == 0x10)
        #expect(photo.captureDate == "20261114T211205")
    }

    @Test func dateTimeStringParsesLocalUTCAndOffsetForms() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let expected = Date(timeIntervalSince1970: 1_794_658_325) // 2026-11-14 12:12:05 UTC
        #expect(DateTimeString.parse("20261114T211205", timeZone: seoul) == expected)
        #expect(DateTimeString.parse("20261114T211205.5", timeZone: seoul) == expected)
        #expect(DateTimeString.parse("20261114T121205Z", timeZone: seoul) == expected)
        #expect(DateTimeString.parse("20261114T211205+0900", timeZone: .gmt) == expected)
    }

    @Test func dateTimeStringRejectsMalformedAndImpossibleDates() {
        #expect(DateTimeString.parse("2026-11-14", timeZone: .gmt) == nil)
        #expect(DateTimeString.parse("20260230T000000", timeZone: .gmt) == nil)
        #expect(DateTimeString.parse("", timeZone: .gmt) == nil)
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter DatasetTests`
Expected: 컴파일 실패

- [ ] **Step 3: 데이터셋, `DateTimeString`, `Fixtures`를 구현합니다**

세 데이터셋의 `init(_ data:)`는 extension에 둬서 멤버별 init을 남깁니다(Task 8의 가짜 앨범이 씁니다). `DateTimeString`은 `yyyyMMdd'T'HHmmss` 뒤의 `.s`를 버리고, `Z`는 UTC, `±hhmm`은 그 오프셋, 없으면 받은 `timeZone`으로 해석합니다. `Calendar`로 만든 날짜를 다시 성분으로 풀어 입력과 다르면(2월 30일) `nil`입니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter DatasetTests && make check`
Expected: 5개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "PTP 데이터셋과 날짜 해석 추가"
```

### Task 4: PacketBuffer

**Files:**
- Create: `Sources/PullshotKit/Protocol/PacketBuffer.swift`
- Test: `Tests/PullshotKitTests/PacketBufferTests.swift`

**Interfaces:**
- Consumes: `ContainerHeader`, `Container`
- Produces: `public struct PacketBuffer { init(); var count: Int; mutating func append(_ chunk: Data); func peekHeader() throws -> ContainerHeader?; mutating func removeFirst(upTo count: Int) -> Data; mutating func nextContainer() throws -> Container? }`
  - `peekHeader()`는 12바이트 미만이면 `nil`입니다.
  - `nextContainer()`는 컨테이너 전체가 쌓였을 때만 꺼내고, 아니면 `nil`입니다.
  - `removeFirst(upTo:)`는 큰 데이터를 흘려 쓰는 쪽(Task 6)이 씁니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct PacketBufferTests {
    let data = Container(kind: .data, code: 0x1004, transactionID: 1, payload: Data([1, 0, 0, 0, 1, 0, 1, 0])).encoded()
    let ok = Container(kind: .response, code: 0x2001, transactionID: 1, payload: Data()).encoded()

    @Test func containerSplitAcrossChunksWaitsForTheRest() throws {
        var buffer = PacketBuffer()
        buffer.append(data.prefix(5))
        #expect(try buffer.nextContainer() == nil)
        buffer.append(data.dropFirst(5))
        #expect(try buffer.nextContainer()?.code == 0x1004)
    }

    @Test func coalescedContainersComeOutInOrder() throws {
        var buffer = PacketBuffer()
        buffer.append(data + ok)
        #expect(try buffer.nextContainer()?.kind == .data)
        #expect(try buffer.nextContainer()?.kind == .response)
        #expect(buffer.count == 0)
    }

    @Test func zeroLengthChunkChangesNothing() throws {
        var buffer = PacketBuffer()
        buffer.append(Data())
        #expect(buffer.count == 0)
        #expect(try buffer.peekHeader() == nil)
    }

    @Test func streamingTakesPayloadAndLeavesTheResponse() throws {
        var buffer = PacketBuffer()
        buffer.append(data + ok)
        let header = try #require(try buffer.peekHeader())
        _ = buffer.removeFirst(upTo: ContainerHeader.size)
        let payload = buffer.removeFirst(upTo: Int(header.length) - ContainerHeader.size)
        #expect(payload.count == 8)
        #expect(try buffer.nextContainer()?.code == 0x2001)
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter PacketBufferTests`
Expected: 컴파일 실패

- [ ] **Step 3: `PacketBuffer`를 구현합니다**

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter PacketBufferTests && make check`
Expected: 4개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "PacketBuffer 추가"
```

### Task 5: Session 트랜잭션

**Files:**
- Create: `Sources/PullshotKit/Session/Transport.swift`, `Session.swift`, `SessionError.swift`, `Sources/PullshotKit/Support/Log.swift`
- Create: `Tests/PullshotKitTests/Support/ScriptedTransport.swift`
- Test: `Tests/PullshotKitTests/SessionTransactionTests.swift`

**Interfaces:**
- Consumes: Task 1~4 전부
- Produces:
  - `public protocol Transport: AnyObject { func write(_ data: Data, timeout: TimeInterval) throws; func read(maxLength: Int, timeout: TimeInterval) throws -> Data; func resetPTPDevice() throws; func resetUSBDevice() throws; func close() }`
  - `public enum TransportError: Error, Equatable { case timedOut, disconnected, stalled, io(code: UInt32) }`
  - `public enum SessionError: Error, Equatable { case response(PTP.Response, operation: PTP.Operation); case unexpectedContainer(kind: UInt16, code: UInt16); case transactionMismatch(expected: UInt32, got: UInt32); case transport(TransportError); case invalidated; case cancelled; case needsUSBReset; case destinationExists(String); case sizeMismatch(expected: UInt64, actual: UInt64) }`
  - `public final class Session { init(transport: Transport, trace: ((String) -> Void)? = nil); private(set) var isOpen: Bool; private(set) var isValid: Bool; func storageIDs() throws -> [UInt32]; func storageInfo(_ id: UInt32) throws -> StorageInfo; func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32]; func objectInfo(_ handle: UInt32) throws -> ObjectInfo }`
  - 내부: `func transact(_ op: PTP.Operation, _ params: [UInt32]) throws -> (data: Data, response: Container)`, 다음 트랜잭션 ID
  - `public enum Log { static let usb, ptp, album: Logger }` (subsystem `com.parkgiraffe.Pullshot`)
  - 테스트 지원: `final class ScriptedTransport: Transport { enum Step { case expectWrite(Data?), read(Data), readError(TransportError) }; init(_ steps: [Step]); var written: [Data]; var ptpResets: Int; var usbResets: Int; var ptpResetError: TransportError?; var isFinished: Bool }`와 `Fixtures.response(_ code: UInt16, tid: UInt32, params: [UInt32] = []) -> Data`, `Fixtures.data(_ op: PTP.Operation, tid: UInt32, _ payload: Data) -> Data`, `Session.openedForTesting(transport:) -> Session`(열린 상태, 다음 ID 1. 테스트가 `@testable import`로 쓰도록 `Session.swift` 안에 `internal static`으로 둡니다)

트랜잭션 규칙:
- 세션 없는 GetDeviceInfo와 OpenSession은 트랜잭션 ID 0, 세션 안의 첫 명령은 1부터 하나씩 늘립니다.
- 쓰기 제한 시간 5초, 명령 단계 읽기 10초, 한 번에 읽는 크기 `512 * 1024`바이트입니다.
- 0바이트 읽기(ZLP)는 버리고 다시 읽습니다. 이벤트 컨테이너(종류 4)는 로그만 남기고 버리되, 한 트랜잭션에서 16개를 넘으면 `unexpectedContainer`입니다.
- 응답의 트랜잭션 ID가 다르거나 전송 오류가 나면 `isValid = false`가 되고, 그 뒤 모든 호출은 `SessionError.invalidated`를 던집니다. OK가 아닌 응답은 `response(…)`를 던지되 세션은 유효합니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct SessionTransactionTests {
    @Test func storageIDsUsesTheNextTransactionID() throws {
        var ids = ByteWriter()
        ids.u32Array([0x0001_0001])
        let transport = ScriptedTransport([
            .expectWrite(Container.command(.getStorageIDs, transactionID: 1).encoded()),
            .read(Fixtures.data(.getStorageIDs, tid: 1, ids.data)),
            .read(Fixtures.response(0x2001, tid: 1)),
        ])
        let session = Session.openedForTesting(transport: transport)
        #expect(try session.storageIDs() == [0x0001_0001])
        #expect(transport.isFinished)
    }

    @Test func nonOKResponseThrowsAndKeepsTheSession() throws {
        let transport = ScriptedTransport([.expectWrite(nil), .read(Fixtures.response(0x2009, tid: 1))])
        let session = Session.openedForTesting(transport: transport)
        #expect(throws: SessionError.response(.invalidObjectHandle, operation: .getObjectInfo)) {
            try session.objectInfo(0x42)
        }
        #expect(session.isValid)
    }

    @Test func mismatchedTransactionInvalidatesTheSession() throws {
        let transport = ScriptedTransport([.expectWrite(nil), .read(Fixtures.response(0x2001, tid: 7))])
        let session = Session.openedForTesting(transport: transport)
        #expect(throws: SessionError.transactionMismatch(expected: 1, got: 7)) { try session.storageIDs() }
        #expect(!session.isValid)
        #expect(throws: SessionError.invalidated) { try session.storageIDs() }
    }

    @Test func transportFailureInvalidatesTheSession() throws {
        let transport = ScriptedTransport([.expectWrite(nil), .readError(.disconnected)])
        let session = Session.openedForTesting(transport: transport)
        #expect(throws: SessionError.transport(.disconnected)) { try session.storageIDs() }
        #expect(!session.isValid)
    }

    @Test func eventsAndZeroLengthReadsAreSkipped() throws {
        var ids = ByteWriter()
        ids.u32Array([])
        let event = Container(kind: .event, code: 0x4002, transactionID: 0, payload: Data()).encoded()
        let transport = ScriptedTransport([
            .expectWrite(nil), .read(Data()), .read(event),
            .read(Fixtures.data(.getStorageIDs, tid: 1, ids.data)), .read(Data()),
            .read(Fixtures.response(0x2001, tid: 1)),
        ])
        #expect(try Session.openedForTesting(transport: transport).storageIDs() == [])
    }

    @Test func objectHandlesSendsStorageFormatAndParent() throws {
        var handles = ByteWriter()
        handles.u32Array([0x10, 0x11])
        let transport = ScriptedTransport([
            .expectWrite(Container.command(.getObjectHandles, transactionID: 1,
                                           parameters: [0x0001_0001, 0, PTP.rootParent]).encoded()),
            .read(Fixtures.data(.getObjectHandles, tid: 1, handles.data)),
            .read(Fixtures.response(0x2001, tid: 1)),
        ])
        let session = Session.openedForTesting(transport: transport)
        #expect(try session.objectHandles(storage: 0x0001_0001, parent: PTP.rootParent) == [0x10, 0x11])
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter SessionTransactionTests`
Expected: 컴파일 실패

- [ ] **Step 3: `Transport`, `SessionError`, `Session`의 트랜잭션, `Log`, 테스트 지원을 구현합니다**

`transact`는 명령을 쓰고, 읽은 조각을 `PacketBuffer`에 쌓아 데이터 컨테이너(있으면)와 응답 컨테이너를 차례로 꺼냅니다. `trace`가 있으면 쓰기와 읽기마다 `"→ 0x1004 tid 1"`, `"← data 16B"`, `"← 0x2001 tid 1"` 꼴의 한 줄을 넘깁니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter SessionTransactionTests && make check`
Expected: 6개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "Session 트랜잭션 추가"
```

### Task 6: Session 내려받기와 썸네일

**Files:**
- Create: `Sources/PullshotKit/Session/Session+Download.swift`
- Test: `Tests/PullshotKitTests/SessionDownloadTests.swift`

**Interfaces:**
- Consumes: `Session.transact` 규칙, `PacketBuffer.removeFirst(upTo:)`, `SessionError`
- Produces:
  - `func thumbnail(_ handle: UInt32) throws -> Data`
  - `func download(_ handle: UInt32, expectedSize: UInt64?, to destination: URL, progress: (UInt64) -> Void = { _ in }, isCancelled: () -> Bool = { false }) throws`

내려받기 규칙:
- 시작 전에 `destination`이 있으면 명령을 보내지 않고 `destinationExists(파일 이름)`을 던집니다.
- 같은 폴더의 `.<파일 이름>.pullshot-partial`에 흘려 쓰고, 데이터 단계 읽기 제한 시간은 30초입니다. 조각을 쓸 때마다 누적 바이트로 `progress`를 부릅니다.
- 응답이 OK이고 받은 바이트가 `expectedSize`(nil이면 확인 생략)와 같을 때만 `destination`으로 이름을 바꿉니다. 바꿀 때 이미 있으면 덮어쓰지 않고 `destinationExists`입니다.
- 크기가 다르면 임시 파일을 지우고 `sizeMismatch`입니다.
- 전송 오류, 취소(`isCancelled()`가 참)에는 임시 파일을 지우고 세션을 무효로 합니다. 데이터 단계를 버렸으므로 그 세션은 다시 쓸 수 없습니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct SessionDownloadTests {
    let payload = Data((0 ..< 1500).map { UInt8($0 % 251) })
    var folder: URL { FileManager.default.temporaryDirectory.appending(path: "pullshot-\(UUID())") }

    func chunks(_ data: Data) -> [ScriptedTransport.Step] {
        let whole = Fixtures.data(.getObject, tid: 1, data)
        return [.expectWrite(nil), .read(whole.prefix(700)), .read(whole.dropFirst(700).prefix(600)),
                .read(whole.dropFirst(1300)), .read(Fixtures.response(0x2001, tid: 1))]
    }

    @Test func downloadStreamsToFileAndReportsProgress() throws {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appending(path: "20261114211205_1.jpg")
        var seen: [UInt64] = []
        try Session.openedForTesting(transport: ScriptedTransport(chunks(payload)))
            .download(1, expectedSize: 1500, to: target, progress: { seen.append($0) })
        #expect(try Data(contentsOf: target) == payload)
        #expect(seen.last == 1500 && seen == seen.sorted())
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path(percentEncoded: false)) == ["20261114211205_1.jpg"])
    }

    @Test func downloadRefusesToOverwrite() throws {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appending(path: "a.jpg")
        try Data([1]).write(to: target)
        let transport = ScriptedTransport([])
        #expect(throws: SessionError.destinationExists("a.jpg")) {
            try Session.openedForTesting(transport: transport).download(1, expectedSize: 1, to: target)
        }
        #expect(transport.written.isEmpty)
        #expect(try Data(contentsOf: target) == Data([1]))
    }

    @Test func failedDownloadLeavesNoFiles() throws {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let whole = Fixtures.data(.getObject, tid: 1, payload)
        let session = Session.openedForTesting(transport: ScriptedTransport([
            .expectWrite(nil), .read(whole.prefix(700)), .readError(.disconnected),
        ]))
        #expect(throws: SessionError.transport(.disconnected)) {
            try session.download(1, expectedSize: 1500, to: dir.appending(path: "v.mp4"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path(percentEncoded: false)).isEmpty)
        #expect(!session.isValid)
    }

    @Test func cancelledDownloadLeavesNoFilesAndInvalidates() throws {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var calls = 0
        let session = Session.openedForTesting(transport: ScriptedTransport(chunks(payload)))
        #expect(throws: SessionError.cancelled) {
            try session.download(1, expectedSize: 1500, to: dir.appending(path: "c.jpg"),
                                 isCancelled: { calls += 1; return calls > 1 })
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path(percentEncoded: false)).isEmpty)
        #expect(!session.isValid)
    }

    @Test func sizeMismatchRemovesThePartialFile() throws {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(throws: SessionError.sizeMismatch(expected: 2000, actual: 1500)) {
            try Session.openedForTesting(transport: ScriptedTransport(chunks(payload)))
                .download(1, expectedSize: 2000, to: dir.appending(path: "s.jpg"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path(percentEncoded: false)).isEmpty)
    }

    @Test func missingThumbnailIsAResponseError() {
        let transport = ScriptedTransport([.expectWrite(nil), .read(Fixtures.response(0x2010, tid: 1))])
        #expect(throws: SessionError.response(.noThumbnailPresent, operation: .getThumb)) {
            try Session.openedForTesting(transport: transport).thumbnail(1)
        }
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter SessionDownloadTests`
Expected: 컴파일 실패

- [ ] **Step 3: `thumbnail`과 `download`를 구현합니다**

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter SessionDownloadTests && make check`
Expected: 6개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "Session 내려받기와 썸네일 추가"
```

### Task 7: Session 열기와 복구

**Files:**
- Create: `Sources/PullshotKit/Session/Session+Open.swift`
- Test: `Tests/PullshotKitTests/SessionOpenTests.swift`

**Interfaces:**
- Consumes: `Session.transact`, `Transport.resetPTPDevice()`, `Transport.resetUSBDevice()`
- Produces: `func open() throws -> DeviceInfo`, `func close()` (CloseSession을 보내고 오류는 무시, `isOpen = false`)

열기 순서(설계 문서 3절의 실기기 사실에서 나온 규칙입니다):

```
1. 세션 없는 GetDeviceInfo(tid 0). OK와 데이터가 오면 info로 둡니다.
   OK가 아닌 응답이나 빈 데이터 단계면 info = nil로 두고 넘어갑니다. 전송 오류는 던집니다.
2. OpenSession(인자 1, tid 0).
   - OK: 3으로
   - sessionAlreadyOpen: CloseSession(tid 0)을 보냅니다. OK가 아니면 transport.resetPTPDevice()를 부릅니다.
     resetPTPDevice()가 던지면 transport.resetUSBDevice()를 부르고 needsUSBReset을 던집니다.
     그다음 OpenSession(tid 0)을 한 번만 다시 보내고, 또 실패하면 그 응답 오류를 던집니다.
   - 그 밖의 응답: response 오류를 던집니다.
3. info가 nil이면 세션 안에서 GetDeviceInfo(tid 1)를 받습니다.
4. isOpen = true, 다음 트랜잭션 ID를 맞추고 info를 돌려줍니다.
```

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct SessionOpenTests {
    let info = Fixtures.deviceInfo(model: "Nintendo Switch 2", serial: "TEST0001", version: "23.0.1",
                                   operations: Array(0x1001 ... 0x100A))
    func op(_ code: UInt16, _ tid: UInt32) -> ScriptedTransport.Step {
        .expectWrite(Container.command(PTP.Operation(rawValue: code), transactionID: tid,
                                       parameters: code == 0x1002 ? [1] : []).encoded())
    }

    @Test func sessionlessDeviceInfoThenOpen() throws {
        let transport = ScriptedTransport([
            op(0x1001, 0), .read(Fixtures.data(.getDeviceInfo, tid: 0, info)), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x2001, tid: 0)),
        ])
        let session = Session(transport: transport)
        #expect(try session.open().deviceVersion == "23.0.1")
        #expect(session.isOpen && transport.isFinished)
    }

    @Test func rejectedSessionlessDeviceInfoIsFetchedInsideTheSession() throws {
        let transport = ScriptedTransport([
            op(0x1001, 0), .read(Fixtures.data(.getDeviceInfo, tid: 0, Data())), .read(Fixtures.response(0x2004, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1001, 1), .read(Fixtures.data(.getDeviceInfo, tid: 1, info)), .read(Fixtures.response(0x2001, tid: 1)),
        ])
        #expect(try Session(transport: transport).open().model == "Nintendo Switch 2")
        #expect(transport.isFinished)
    }

    @Test func staleSessionIsClosedThenReopened() throws {
        let transport = ScriptedTransport([
            op(0x1001, 0), .read(Fixtures.data(.getDeviceInfo, tid: 0, info)), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x201E, tid: 0)),
            op(0x1003, 0), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x2001, tid: 0)),
        ])
        _ = try Session(transport: transport).open()
        #expect(transport.ptpResets == 0 && transport.isFinished)
    }

    @Test func rejectedCloseFallsBackToPTPDeviceReset() throws {
        let transport = ScriptedTransport([
            op(0x1001, 0), .read(Fixtures.data(.getDeviceInfo, tid: 0, info)), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x201E, tid: 0)),
            op(0x1003, 0), .read(Fixtures.response(0x2004, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x2001, tid: 0)),
        ])
        _ = try Session(transport: transport).open()
        #expect(transport.ptpResets == 1 && transport.usbResets == 0)
    }

    @Test func stalledPTPResetEscalatesToUSBReset() {
        let transport = ScriptedTransport([
            op(0x1001, 0), .read(Fixtures.data(.getDeviceInfo, tid: 0, info)), .read(Fixtures.response(0x2001, tid: 0)),
            op(0x1002, 0), .read(Fixtures.response(0x201E, tid: 0)),
            op(0x1003, 0), .read(Fixtures.response(0x2002, tid: 0)),
        ])
        transport.ptpResetError = .stalled
        #expect(throws: SessionError.needsUSBReset) { try Session(transport: transport).open() }
        #expect(transport.usbResets == 1)
    }

    @Test func closeSendsCloseSessionWithTheNextID() {
        let transport = ScriptedTransport([op(0x1003, 1), .read(Fixtures.response(0x2001, tid: 1))])
        let session = Session.openedForTesting(transport: transport)
        session.close()
        #expect(!session.isOpen && transport.isFinished)
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter SessionOpenTests`
Expected: 컴파일 실패

- [ ] **Step 3: `open()`과 `close()`를 위 순서대로 구현합니다**

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter SessionOpenTests && make check`
Expected: 6개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "Session 열기와 복구 추가"
```

### Task 8: AlbumScanner

**Files:**
- Create: `Sources/PullshotKit/Album/Capture.swift`, `AlbumScanner.swift`
- Create: `Tests/PullshotKitTests/Support/FakeAlbumSource.swift`
- Test: `Tests/PullshotKitTests/AlbumScannerTests.swift`

**Interfaces:**
- Consumes: `Session`(아래 프로토콜을 따르게 함), `ObjectInfo`, `DateTimeString`, `SessionError`
- Produces:
  - `public protocol AlbumSource: AnyObject { func storageIDs() throws -> [UInt32]; func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32]; func objectInfo(_ handle: UInt32) throws -> ObjectInfo }` (`extension Session: AlbumSource`)
  - `public struct Capture: Equatable, Sendable, Identifiable { handle: UInt32; storageID: UInt32; filename: String; size: UInt64?; capturedAt: Date?; kind: Kind; gameFolder: String?; var id: String { "\(gameFolder ?? "")/\(filename)" }; enum Kind: Sendable { case photo, video }; static func isSafeFilename(_ name: String) -> Bool }`
  - `public struct SkippedObject: Equatable, Sendable { handle: UInt32; reason: String }`
  - `public struct AlbumScan: Equatable, Sendable { captures: [Capture]; skipped: [SkippedObject] }`
  - `public struct AlbumScanner { init(source: AlbumSource, timeZone: TimeZone = .current); func scan(progress: (Int) -> Void = { _ in }) throws -> AlbumScan }`

훑기 규칙:
- 저장소마다 `objectHandles(storage:parent: PTP.rootParent)`에서 시작해 폴더(`isFolder`)를 따라 내려갑니다. 폴더 안 핸들은 `objectHandles(storage:parent: 폴더 핸들)`로 받습니다.
- 파일의 `gameFolder`는 바로 위 폴더 이름이고, 루트의 파일은 `nil`입니다.
- 종류는 확장자(`jpg`, `jpeg`, `png`는 사진, `mp4`, `mov`는 영상, 대소문자 무시)로 정하고, 확장자가 없으면 형식(`exifJPEG`, `png`는 사진, `mpeg`, `mp4Container`는 영상)으로 정합니다. 둘 다 아니면 `"not media"`로 건너뜁니다.
- `isSafeFilename`은 빈 문자열, `.`, `..`, `/`나 NUL이 든 이름을 거부합니다. 거부한 항목은 `"unsafe filename"`으로 건너뜁니다. 이 검사는 종류 판정보다 먼저 합니다.
- `size`는 `compressedSize`이고, `0xFFFF_FFFF`면 `nil`입니다.
- `capturedAt`은 `captureDate`를 `DateTimeString`으로 읽고, 안 되면 파일 이름 앞 14자리 숫자(`yyyyMMddHHmmss`)를 `timeZone`으로 읽고, 둘 다 안 되면 `nil`입니다.
- `objectInfo`나 폴더의 `objectHandles`가 `SessionError.response`를 던지면 그 항목만 `"response 0x2009"` 꼴로 건너뜁니다. 저장소의 루트 `objectHandles`가 `.storeNotAvailable`이면 그 저장소를 건너뜁니다. 그 밖의 오류(전송 오류, 무효 세션)는 그대로 던집니다.
- 결과는 `capturedAt` 내림차순(`nil`은 끝), 같으면 `filename` 오름차순입니다. `progress`에는 지금까지 본 객체 수를 넘깁니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

`FakeAlbumSource`는 `final class`이고, `static func tree(_ nodes: [Node], extraStorage: UInt32? = nil, extraStorageError: SessionError? = nil) -> FakeAlbumSource`로 만듭니다. `enum Node { case folder(UInt32, String, [Node]); case file(UInt32, String, format: PTP.ObjectFormat = .exifJPEG, size: UInt32 = 1000, captureDate: String = "") }`이고, 기본 저장소는 `0x0001_0001`입니다. `var objectInfoErrors: [UInt32: Error]`로 핸들별 오류를 넣고, 받은 `parent` 인자를 `requestedParents: [UInt32]`에 모읍니다.

```swift
@Suite struct AlbumScannerTests {
    let seoul = TimeZone(identifier: "Asia/Seoul") ?? .gmt

    @Test func groupsCapturesByParentFolder() throws {
        let source = FakeAlbumSource.tree([
            .folder(0x10, "젤다무쌍 봉인전기", [.file(0x11, "20261114211205_1.jpg"), .file(0x12, "20261114211800_1.mp4")]),
            .folder(0x20, "Mario Kart World", [.file(0x21, "20261105100000_1.jpg")]),
            .file(0x30, "20261101090000_1.jpg"),
        ])
        let scan = try AlbumScanner(source: source, timeZone: seoul).scan()
        #expect(scan.captures.map(\.handle) == [0x12, 0x11, 0x21, 0x30])
        #expect(scan.captures.first { $0.handle == 0x12 }?.kind == .video)
        #expect(scan.captures.first { $0.handle == 0x11 }?.gameFolder == "젤다무쌍 봉인전기")
        #expect(scan.captures.first { $0.handle == 0x30 }?.gameFolder == nil)
        #expect(!source.requestedParents.contains(0))
    }

    @Test func nestedFoldersUseTheImmediateParent() throws {
        let source = FakeAlbumSource.tree([.folder(0x10, "Album", [.folder(0x11, "Splatoon 3", [.file(0x12, "x.jpg")])])])
        #expect(try AlbumScanner(source: source).scan().captures.map(\.gameFolder) == ["Splatoon 3"])
    }

    @Test func objectInfoFailureIsSkipped() throws {
        let source = FakeAlbumSource.tree([.file(0x11, "a.jpg"), .file(0x12, "b.jpg")])
        source.objectInfoErrors[0x11] = SessionError.response(.invalidObjectHandle, operation: .getObjectInfo)
        let scan = try AlbumScanner(source: source).scan()
        #expect(scan.captures.map(\.handle) == [0x12])
        #expect(scan.skipped == [SkippedObject(handle: 0x11, reason: "response 0x2009")])
    }

    @Test func transportFailureAbortsTheScan() {
        let source = FakeAlbumSource.tree([.file(0x11, "a.jpg")])
        source.objectInfoErrors[0x11] = SessionError.transport(.disconnected)
        #expect(throws: SessionError.transport(.disconnected)) { try AlbumScanner(source: source).scan() }
    }

    @Test func unavailableStorageIsSkipped() throws {
        let source = FakeAlbumSource.tree([.file(0x11, "a.jpg")], extraStorage: 0x0002_0001,
                                          extraStorageError: .response(.storeNotAvailable, operation: .getObjectHandles))
        #expect(try AlbumScanner(source: source).scan().captures.count == 1)
    }

    @Test func unsafeFilenamesAreSkipped() throws {
        let names = ["", ".", "..", "a/b.jpg", "x\u{0}.jpg"]
        let source = FakeAlbumSource.tree(names.enumerated().map { .file(UInt32(0x40 + $0.offset), $0.element) })
        let scan = try AlbumScanner(source: source).scan()
        #expect(scan.captures.isEmpty)
        #expect(scan.skipped.allSatisfy { $0.reason == "unsafe filename" } && scan.skipped.count == 5)
    }

    @Test func nonMediaIsSkipped() throws {
        let source = FakeAlbumSource.tree([.file(0x11, "readme.txt", format: .undefined)])
        #expect(try AlbumScanner(source: source).scan().skipped == [SkippedObject(handle: 0x11, reason: "not media")])
    }

    @Test func capturedAtPrefersObjectInfoThenFilename() throws {
        let source = FakeAlbumSource.tree([
            .file(0x11, "20200101000000_1.jpg", captureDate: "20261114T211205"),
            .file(0x12, "20261113160500_1.jpg", captureDate: ""),
            .file(0x13, "screenshot.jpg", captureDate: ""),
        ])
        let byHandle = Dictionary(uniqueKeysWithValues: try AlbumScanner(source: source, timeZone: seoul).scan()
            .captures.map { ($0.handle, $0.capturedAt) })
        #expect(byHandle[0x11] == DateTimeString.parse("20261114T211205", timeZone: seoul))
        #expect(byHandle[0x12] == DateTimeString.parse("20261113T160500", timeZone: seoul))
        #expect(byHandle[0x13] == .some(nil))
    }

    @Test func unknownSizeIsNil() throws {
        let source = FakeAlbumSource.tree([.file(0x11, "a.jpg", size: 0xFFFF_FFFF)])
        #expect(try AlbumScanner(source: source).scan().captures.first?.size == nil)
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter AlbumScannerTests`
Expected: 컴파일 실패

- [ ] **Step 3: `Capture`, `AlbumScanner`, `FakeAlbumSource`를 구현합니다**

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter AlbumScannerTests && make check`
Expected: 9개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "AlbumScanner 추가"
```

### Task 9: 전송 기록과 재생

**Files:**
- Create: `Sources/PullshotKit/Session/TransferLog.swift`
- Test: `Tests/PullshotKitTests/TransferLogTests.swift`

**Interfaces:**
- Consumes: `Transport`, `TransportError`
- Produces:
  - `public final class RecordingTransport: Transport { init(wrapping: Transport, to url: URL) throws }`: 모든 호출을 감싼 전송에 넘기고, 한 줄에 하나씩 JSON으로 덧붙여 씁니다. `{"dir":"out","hex":"…"}`, `{"dir":"in","hex":"…"}`, `{"dir":"in-error","error":"timedOut"}`(`TransportError` 이름, `io`면 `"io:0xE0005000"`), `{"dir":"reset","kind":"ptp"}`, `{"dir":"reset","kind":"usb"}`
  - `public final class ReplayTransport: Transport { init(contentsOf url: URL) throws; var isFinished: Bool }`: `write`는 다음 기록이 같은 바이트의 `out`이어야 하고, 아니면 `ReplayError.unexpectedWrite(index:)`를 던집니다. `read`는 다음 `in`을 돌려주거나 `in-error`의 오류를 던집니다.
  - `public enum ReplayError: Error, Equatable { case unexpectedWrite(index: Int), unexpectedRead(index: Int), exhausted }`

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct TransferLogTests {
    @Test func recordedSessionReplaysToTheSameResult() throws {
        var ids = ByteWriter()
        ids.u32Array([0x0001_0001])
        let file = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).jsonl")
        let live = ScriptedTransport([
            .expectWrite(nil), .read(Fixtures.data(.getStorageIDs, tid: 1, ids.data)), .read(Fixtures.response(0x2001, tid: 1)),
        ])
        let recorded = try Session.openedForTesting(transport: RecordingTransport(wrapping: live, to: file)).storageIDs()
        let replay = try ReplayTransport(contentsOf: file)
        #expect(try Session.openedForTesting(transport: replay).storageIDs() == recorded)
        #expect(replay.isFinished)
    }

    @Test func divergentWriteIsReported() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).jsonl")
        try #"{"dir":"out","hex":"0c0000000100041001000000"}"#.write(to: file, atomically: true, encoding: .utf8)
        let replay = try ReplayTransport(contentsOf: file)
        #expect(throws: ReplayError.unexpectedWrite(index: 0)) {
            try replay.write(Container.command(.getObjectHandles, transactionID: 1).encoded(), timeout: 1)
        }
    }

    @Test func recordedErrorsReplayAsErrors() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).jsonl")
        let live = ScriptedTransport([.expectWrite(nil), .readError(.timedOut)])
        let recorder = try RecordingTransport(wrapping: live, to: file)
        try recorder.write(Data([1]), timeout: 1)
        #expect(throws: TransportError.timedOut) { try recorder.read(maxLength: 8, timeout: 1) }
        let replay = try ReplayTransport(contentsOf: file)
        try replay.write(Data([1]), timeout: 1)
        #expect(throws: TransportError.timedOut) { try replay.read(maxLength: 8, timeout: 1) }
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter TransferLogTests`
Expected: 컴파일 실패

- [ ] **Step 3: `RecordingTransport`, `ReplayTransport`를 구현합니다**

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter TransferLogTests && make check`
Expected: 3개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "전송 기록과 재생 추가"
```

### Task 10: ConsoleModel과 접근 오류

**Files:**
- Create: `Sources/PullshotKit/Console/ConsoleModel.swift`, `ConsoleAccessError.swift`
- Test: `Tests/PullshotKitTests/ConsoleTests.swift`

**Interfaces:**
- Produces:
  - `public struct ConsoleModel: Equatable, Sendable { vendorID: UInt16; productID: UInt16; name: String; isExperimental: Bool; static let switch2, switch1; static let all: [ConsoleModel]; static func matching(vendorID: UInt16, productID: UInt16) -> ConsoleModel? }`
  - `public enum ConsoleAccessError: Error, Equatable { case heldByAnotherApp(code: UInt32), noStillImageInterface, missingEndpoints, other(code: UInt32); init(ioReturn: Int) }` (사용자 문구는 Task 12의 `ErrorMessages`가 맡습니다)

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct ConsoleTests {
    @Test func modelsMatchKnownUSBIDs() {
        #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x2061) == .switch2)
        #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x201D)?.isExperimental == true)
        #expect(ConsoleModel.switch2.isExperimental == false)
        #expect(ConsoleModel.matching(vendorID: 0x057E, productID: 0x2000) == nil)
    }

    @Test func bothBusyCodesMeanHeldByAnotherApp() {
        for code: UInt32 in [0xE000_02C5, 0xE000_02C9] {
            #expect(ConsoleAccessError(ioReturn: Int(Int32(bitPattern: code))) == .heldByAnotherApp(code: code))
            #expect(ConsoleAccessError(ioReturn: Int(code)) == .heldByAnotherApp(code: code))
        }
    }

    @Test func otherCodesStayOther() {
        #expect(ConsoleAccessError(ioReturn: Int(Int32(bitPattern: 0xE000_02BC))) == .other(code: 0xE000_02BC))
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter ConsoleTests`
Expected: 컴파일 실패

- [ ] **Step 3: `ConsoleModel`, `ConsoleAccessError`를 구현합니다**

`init(ioReturn:)`은 `UInt32(truncatingIfNeeded:)`로 부호 확장된 값과 양수 값을 같은 코드로 맞춥니다.

- [ ] **Step 4: 통과를 확인합니다**

Run: `swift test --filter ConsoleTests && make check`
Expected: 3개 통과

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "ConsoleModel과 접근 오류 추가"
```

### Task 11: HostTransport와 ConsoleLocator

**Files:**
- Create: `Sources/PullshotKit/Console/EndpointSelection.swift`, `HostTransport.swift`, `ConsoleLocator.swift`
- Test: `Tests/PullshotKitTests/EndpointSelectionTests.swift`

**Interfaces:**
- Consumes: `Transport`, `TransportError`, `ConsoleModel`, `ConsoleAccessError`, `Log`
- Produces:
  - `public struct EndpointDescriptor: Equatable, Sendable { address: UInt8; transferType: TransferType; maxPacketSize: UInt16; enum TransferType { case control, isochronous, bulk, interrupt } }`
  - `public enum EndpointSelection { static func pick(_ endpoints: [EndpointDescriptor]) -> (bulkIn: UInt8, bulkOut: UInt8, interruptIn: UInt8?)? }` (방향은 주소의 `0x80` 비트)
  - `public struct AttachedConsole: Equatable, Sendable { model: ConsoleModel; registryID: UInt64; locationID: UInt32?; serialNumber: String? }`
  - `public enum ConsoleLocator { static func attached() -> [AttachedConsole] }`
  - `public final class HostTransport: Transport { init(console: AttachedConsole, trace: ((String) -> Void)? = nil) throws }`

구현 방식(실기기 없이는 단위 테스트할 수 없는 부분입니다):
- `ConsoleLocator`: `IOUSBHostDevice.createMatchingDictionary`에 vendor `0x057E`를 넣어 `IOServiceGetMatchingServices`로 찾고, `ConsoleModel.matching`으로 거릅니다. `USB Serial Number`, `locationID` 속성과 레지스트리 ID를 읽습니다.
- `HostTransport.init`: 그 기기 아래의 still image 인터페이스(class 6, subclass 1, protocol 1)를 `IOUSBHostInterface.createMatchingDictionary`로 찾고, 없으면 `noStillImageInterface`를 던집니다. `IOUSBHostInterface(__ioService:options:queue:interestHandler:)`가 던진 `NSError.code`는 `ConsoleAccessError(ioReturn:)`으로 바꿉니다.
- 엔드포인트는 `IOUSBGetNextEndpointDescriptor`로 훑어 `EndpointSelection.pick`에 넘기고, 없으면 `missingEndpoints`입니다. 훑기는 `nil`이 나오면 반드시 멈춥니다(처음부터 다시 돌지 않게).
- `write`, `read`: `copyPipe(withAddress:)`로 연 파이프의 `sendIORequest(with:bytesTransferred:completionTimeout:)`를 씁니다. 읽기 버퍼는 `NSMutableData(length: maxLength)`이고, 실제 받은 길이만큼 잘라 돌려줍니다.
- 오류 대응: 시간 초과는 `.timedOut`, 기기가 사라짐은 `.disconnected`, 파이프 멈춤(IOUSBHost의 pipe stalled 코드, 부호 확장 형태 포함)은 `clearStall()`을 부른 뒤 `.stalled`, 나머지는 `.io(code:)`입니다.
- `resetPTPDevice()`: 인터페이스에 class 요청 `bmRequestType 0x21, bRequest 0x66, wValue 0, wIndex 인터페이스 번호, wLength 0`을 보냅니다.
- `resetUSBDevice()`: 부모 `IOUSBHostDevice`를 열어 `reset()`합니다. 그 뒤 이 전송은 쓸 수 없습니다.
- `close()`: 파이프와 인터페이스를 `destroy()`합니다. 두 번 불러도 됩니다.
- `trace`에는 `"bulk-out 16B"`, `"bulk-in 524288 → 1500B"`, 오류 코드를 넘깁니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct EndpointSelectionTests {
    @Test func picksBulkPairAndInterrupt() {
        let picked = EndpointSelection.pick([
            .init(address: 0x81, transferType: .bulk, maxPacketSize: 512),
            .init(address: 0x02, transferType: .bulk, maxPacketSize: 512),
            .init(address: 0x83, transferType: .interrupt, maxPacketSize: 8),
        ])
        #expect(picked?.bulkIn == 0x81 && picked?.bulkOut == 0x02 && picked?.interruptIn == 0x83)
    }

    @Test func missingBulkOutIsNil() {
        #expect(EndpointSelection.pick([.init(address: 0x81, transferType: .bulk, maxPacketSize: 512)]) == nil)
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter EndpointSelectionTests`
Expected: 컴파일 실패

- [ ] **Step 3: `EndpointSelection`, `ConsoleLocator`, `HostTransport`를 구현합니다**

- [ ] **Step 4: 통과와 빌드를 확인합니다**

Run: `swift test --filter EndpointSelectionTests && make build && make check`
Expected: 2개 통과, 경고 없이 빌드

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "HostTransport와 ConsoleLocator 추가"
```

### Task 12: pullshot CLI

**Files:**
- Modify: `Package.swift` (의존성 `.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0")`, 제품 `.executable(name: "pullshot", targets: ["pullshot"])`, 타깃 `pullshot`)
- Create: `Sources/pullshot/Pullshot.swift`, `Connect.swift`, `Probe.swift`, `List.swift`, `Pull.swift`, `Dump.swift`, `ErrorMessages.swift`
- Modify: `Package.swift` (테스트 타깃 `PullshotCLITests`, 의존성 `pullshot`)
- Test: `Tests/PullshotCLITests/ErrorMessagesTests.swift`
- Create: `Sources/PullshotKit/Support/DestinationNamer.swift`, `ListFormatter.swift`
- Create: `THIRD_PARTY_LICENSES.md` (`.build/checkouts/swift-argument-parser/LICENSE.txt` 원문 그대로)
- Test: `Tests/PullshotKitTests/CLISupportTests.swift`

**Interfaces:**
- Consumes: `ConsoleLocator`, `HostTransport`, `RecordingTransport`, `Session.open/close/storageIDs/storageInfo/thumbnail/download`, `AlbumScanner`, `ConsoleAccessError.message`
- Produces:
  - `public enum DestinationNamer { enum Decision: Equatable { case write(URL), skip(URL) }; static func decide(filename: String, size: UInt64?, in folder: URL, fileManager: FileManager = .default) -> Decision }`: 같은 이름과 크기가 있으면 `skip`, 이름만 같거나 `size`가 `nil`이면 `"이름 2.확장자"`, `"이름 3.확장자"` 순으로 빈 이름에 `write`
  - `public enum ListFormatter { static func lines(_ scan: AlbumScan, timeZone: TimeZone) -> [String] }`
  - 2단계가 이 둘을 가져오기와 내보내기에 다시 씁니다.
  - CLI 안: `enum ErrorMessages { static func message(for error: Error) -> String }`. 문구는 이대로 씁니다.
    - `ConsoleAccessError.heldByAnotherApp`: "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 닫고 다시 시도해 주세요."
    - `.noStillImageInterface`, `.missingEndpoints`: "스위치의 사진 전송 기능을 찾지 못했습니다. 본체에서 PC로 복사 모드가 켜져 있는지 확인해 주세요."
    - `.other(code:)`: "스위치에 연결하지 못했습니다(오류 0x%08X)."
    - `SessionError.transport(.disconnected)`: "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요."
    - `SessionError.transport(.timedOut)`: "스위치가 응답하지 않습니다. PC로 복사 화면이 켜져 있는지 확인해 주세요."
    - `SessionError.destinationExists(이름)`: "이미 같은 이름의 파일이 있습니다: 이름"
    - 그 밖의 오류: "스위치와 통신하지 못했습니다: " 뒤에 `String(describing: error)`

CLI 동작:
- 공통 옵션 `--verbose`(세션과 전송의 trace를 표준 오류에 `HH:mm:ss.SSS` 시각과 함께 출력), `--record <파일>`(전송을 `RecordingTransport`로 감쌈)
- `Connect.swift`: 첫 콘솔을 찾아 `HostTransport`와 `Session`을 열고 `open()`합니다. 콘솔이 없으면 "연결된 스위치가 없습니다. 본체 아래쪽 USB-C 포트에 데이터 케이블로 연결하고, 본체에서 PC로 복사 모드를 켜 주세요."를 표준 오류에 쓰고 종료 코드 1입니다. `ConsoleAccessError`는 `message`를 씁니다. `needsUSBReset`이면 0.5초 간격으로 15초까지 `ConsoleLocator.attached()`를 다시 보고, 다시 나타나면 한 번만 다시 엽니다. Switch 1이면 "Nintendo Switch는 실험적 지원입니다. 문제가 있으면 --verbose 출력과 함께 알려 주세요."를 한 번 씁니다.
- `probe`: 모델, 펌웨어(`deviceVersion`), 일련번호, 지원 명령(16진수), 저장소별 설명과 용량("알 수 없음" 허용)을 출력합니다.
- `list [--game <이름>]`: `ListFormatter` 출력입니다.
- `pull (--all | <id>...) [--game <이름>] [--out <폴더>]`: 기본 폴더 `~/Pictures/Pullshot`, 그 아래 게임 폴더(`gameFolder ?? "기타"`)에 `DestinationNamer`대로 받습니다. 끝에 "저장 N개, 건너뜀 M개, 실패 K개"를 쓰고, 실패가 있으면 종료 코드 1입니다. Ctrl-C는 받던 파일을 지우고 요약을 쓴 뒤 종료 코드 130입니다.
- `dump --out <폴더>`: `<폴더>/transcript.jsonl`에 기록하며 열기, `probe` 내용, 전체 훑기, 앞 캡처 3개의 썸네일, 첫 사진 1개를 받고, `probe.txt`, `list.txt`, `files/`를 남깁니다. 끝에 "이 폴더에는 기기 일련번호와 캡처가 들어 있습니다. 공개 리포에 올리지 마세요."를 씁니다.
- 모든 명령은 끝날 때 `session.close()`와 `transport.close()`를 부릅니다.

`ListFormatter` 형식(게임 묶음은 가장 최근 캡처 순, 기타는 끝):

```
젤다무쌍 봉인전기 (2)
  20261114211800_1.mp4  영상  31.2 MB  2026-11-14 21:18
  20261114211205_1.jpg  사진   1.1 MB  2026-11-14 21:12
기타 (1)
  20261101090000_1.jpg  사진   0.4 MB  2026-11-01 09:00
```

크기는 `ByteCountFormatter`가 아니라 `%.1f MB`(1 MB = 1,000,000바이트)로 고정하고, 크기나 시각을 모르면 `-`입니다. 칸 사이는 공백 두 칸이고, 파일 이름은 목록 전체의 가장 긴 이름에 맞춰 왼쪽 정렬, 크기 숫자는 가장 긴 숫자에 맞춰 오른쪽 정렬합니다.

- [ ] **Step 1: 실패하는 테스트를 씁니다**

```swift
@Suite struct CLISupportTests {
    func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "n-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func uniqueDestinationWritesWhenFree() throws {
        let dir = try folder()
        #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: dir) == .write(dir.appending(path: "a.jpg")))
    }

    @Test func uniqueDestinationSkipsSameNameAndSize() throws {
        let dir = try folder()
        try Data([1, 2, 3]).write(to: dir.appending(path: "a.jpg"))
        #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: dir) == .skip(dir.appending(path: "a.jpg")))
    }

    @Test func uniqueDestinationNumbersADifferentFile() throws {
        let dir = try folder()
        try Data([1]).write(to: dir.appending(path: "a.jpg"))
        try Data([1]).write(to: dir.appending(path: "a 2.jpg"))
        #expect(DestinationNamer.decide(filename: "a.jpg", size: 3, in: dir) == .write(dir.appending(path: "a 3.jpg")))
    }

    @Test func listGroupsByGameNewestFirstWithOtherLast() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        func capture(_ h: UInt32, _ name: String, _ game: String?, _ size: UInt64, _ stamp: String, _ kind: Capture.Kind) -> Capture {
            Capture(handle: h, storageID: 1, filename: name, size: size,
                    capturedAt: DateTimeString.parse(stamp, timeZone: seoul), kind: kind, gameFolder: game)
        }
        let scan = AlbumScan(captures: [
            capture(1, "20261114211800_1.mp4", "젤다무쌍 봉인전기", 31_200_000, "20261114T211800", .video),
            capture(2, "20261114211205_1.jpg", "젤다무쌍 봉인전기", 1_100_000, "20261114T211205", .photo),
            capture(3, "20261101090000_1.jpg", nil, 400_000, "20261101T090000", .photo),
        ], skipped: [])
        #expect(ListFormatter.lines(scan, timeZone: seoul) == [
            "젤다무쌍 봉인전기 (2)",
            "  20261114211800_1.mp4  영상  31.2 MB  2026-11-14 21:18",
            "  20261114211205_1.jpg  사진   1.1 MB  2026-11-14 21:12",
            "기타 (1)",
            "  20261101090000_1.jpg  사진   0.4 MB  2026-11-01 09:00",
        ])
    }
}
```

`ErrorMessagesTests`(`@testable import pullshot`):

```swift
@Suite struct ErrorMessagesTests {
    @Test func busyConsoleNamesTheAppsToClose() {
        #expect(ErrorMessages.message(for: ConsoleAccessError.heldByAnotherApp(code: 0xE000_02C9))
            == "다른 앱이 스위치를 쓰고 있습니다. 미리보기, 이미지 캡처, 사진 앱을 닫고 다시 시도해 주세요.")
    }

    @Test func unknownAccessErrorShowsTheCode() {
        #expect(ErrorMessages.message(for: ConsoleAccessError.other(code: 0xE000_02BC))
            == "스위치에 연결하지 못했습니다(오류 0xE00002BC).")
    }

    @Test func unplugMidTransferSaysTheConnectionDropped() {
        #expect(ErrorMessages.message(for: SessionError.transport(.disconnected))
            == "스위치 연결이 끊겼습니다. 케이블을 확인하고 다시 시도해 주세요.")
    }
}
```

- [ ] **Step 2: 실패를 확인합니다**

Run: `swift test --filter CLISupportTests`
Expected: 컴파일 실패

- [ ] **Step 3: `DestinationNamer`, `ListFormatter`, CLI 명령, `THIRD_PARTY_LICENSES.md`를 구현합니다**

- [ ] **Step 4: 테스트와 기기 없는 실행을 확인합니다**

Run: `swift test && make check && swift run pullshot probe; echo "exit=$?"`
Expected: 모든 테스트 통과, 기기가 없으므로 "연결된 스위치가 없습니다. …"와 `exit=1`

- [ ] **Step 5: 커밋합니다**

```bash
git add -A && git commit -m "pullshot CLI 추가"
```

### Task 13: 실기기 검증 (사용자와 30분)

이 태스크는 사용자가 스위치 2를 들고 함께해야 합니다. 시작 전에 사용자에게 알리고, 본체에서 PC로 복사 모드를 켜 달라고 요청합니다.

**Files:**
- Create: `docs/hardware-notes.md`, `Tests/PullshotKitTests/LocalFixtureTests.swift`
- Create (커밋 안 함): `LocalFixtures/switch2-<펌웨어>/`

**Interfaces:**
- Consumes: CLI 전체, `ReplayTransport`, `AlbumScanner`
- Produces: `docs/hardware-notes.md`(2단계 계획의 입력), 실기기 덤프로 도는 재생 테스트

- [ ] **Step 1: 정상 경로를 기록합니다**

Run: `swift run pullshot probe --verbose 2> LocalFixtures/probe-verbose.txt && swift run pullshot dump --out LocalFixtures/switch2-23.0.1`
Expected: 모델 "Nintendo Switch 2", 펌웨어, 지원 명령 10개가 나오고, `list.txt`에 게임 폴더별 캡처가, `files/`에 썸네일 3개와 사진 1개가 남습니다.

- [ ] **Step 2: 영상과 바이트 일치를 확인합니다**

Run: `swift run pullshot pull --game "<영상이 있는 게임>" --out /tmp/pullshot-check` 뒤 `mdls -name kMDItemDurationSeconds`(영상)와 `sips -g pixelWidth`(사진)
Expected: 받은 파일 크기가 `list` 크기와 같고, 영상은 길이가, 사진은 너비가 나옵니다.

- [ ] **Step 3: 다른 앱이 잡은 상황을 재현합니다**

미리보기 앱을 켠 채로, 그다음 이미지 캡처 앱을 켠 채로 각각 `swift run pullshot probe`를 실행합니다.
Expected: 두 번 모두 "다른 앱이 스위치를 쓰고 있습니다. …"와 종료 코드 1. 실제 코드(`0xE00002C9`, `0xE00002C5`)를 `--verbose`로 확인해 적습니다.

- [ ] **Step 4: 끊김과 복구를 재현합니다**

- 큰 영상을 `pull`하는 중에 케이블을 뽑습니다. Expected: 받을 폴더에 파일과 `.pullshot-partial`이 남지 않음
- 본체에서 PC로 복사 모드를 껐다 켠 뒤 `probe`. Expected: 성공(세션 없는 GetDeviceInfo 거부를 넘어감)
- `swift run pullshot list &` 직후 `kill -9 $!`, 이어서 `probe`. Expected: 성공(남은 세션 복구)

- [ ] **Step 5: 2단계에 필요한 사실을 적습니다**

`probe`를 두 번 실행해 일련번호를 비교하고, `docs/hardware-notes.md`에 다음을 적습니다. 일련번호 자체는 적지 않습니다.
- 일련번호가 세션마다 같은지
- 파일 이름 형식(예시 이름 하나를 숫자만 바꿔서)
- 영상에 GetThumb가 되는지, CaptureDate가 채워지는지
- 한글 게임 폴더 이름이 제대로 오는지
- 앨범의 폴더 깊이(루트 바로 아래가 게임인지)
- 바쁨 오류의 실제 코드와 복구에 걸린 시간

- [ ] **Step 6: 실기기 덤프 재생 테스트를 더합니다**

`LocalFixtureTests`는 `LocalFixtures/switch2-23.0.1/transcript.jsonl`이 있을 때만 돌고(`.enabled(if:)`), 없으면 건너뜁니다. 재생으로 `open()`과 `AlbumScanner.scan()`을 돌려 캡처가 1개 이상이고, 모두 `Capture.isSafeFilename`을 통과하며, `skipped`가 비었는지 확인합니다.

Run: `swift test --filter LocalFixtureTests`
Expected: 통과

- [ ] **Step 7: 실기기에서 나온 버그를 고칩니다**

버그마다 재생 테스트나 단위 테스트를 먼저 실패하게 쓰고, 고친 뒤 따로 커밋합니다. 커밋 메시지는 `{대상} {액션}` 형식입니다(예: `Session 재연결 순서 수정`).

- [ ] **Step 8: 커밋합니다**

```bash
git status --short LocalFixtures   # 아무것도 나오지 않아야 합니다(.gitignore)
git add docs/hardware-notes.md Tests/PullshotKitTests/LocalFixtureTests.swift
git commit -m "실기기 검증 결과 추가"
```
