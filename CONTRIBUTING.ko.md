# 기여 안내

[English](CONTRIBUTING.md) | 한국어 <!-- write-exempt -->

Pullshot에 관심을 가져 주셔서 감사합니다. 이슈와 PR은 한국어나 영어로 작성하시면 됩니다.

## 이슈

- 버그는 "버그 알리기" 양식으로 알려 주세요. 재현할 수 있다면 설정에서 "자세한 로그 남기기"를 켜고 한 번 더 시도한 뒤, 도움말 메뉴의 "로그 파일 보기"로 찾은 로그 파일을 첨부해 주세요. 로그에는 파일 이름, 게임 이름, 경로, 일련번호가 기록되지 않습니다.
- Nintendo Switch는 실제 본체로 테스트하지 못해 실험적으로 지원합니다. Nintendo Switch에서 잘 되는지, 안 되는지 알려 주시면 사소한 내용이라도 큰 도움이 됩니다.
- 기능 제안은 "기능 제안" 양식으로 남겨 주세요. 큰 변경은 PR을 열기 전에 이슈에서 먼저 이야기해 주세요.

## 개발 환경

```bash
brew bundle        # SwiftLint, SwiftFormat 설치
make setup-hooks   # 커밋 전 린트와 포맷 검사 설정
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
make app           # dist/Pullshot.app 빌드
```

- 코드 작성 규칙은 [docs/conventions.ko.md](docs/conventions.ko.md)를 따르며, 코드에는 주석을 작성하지 않습니다.
- 용어와 코드 이름은 [docs/glossary.ko.md](docs/glossary.ko.md)에 정리되어 있습니다.
- 실기기에서 확인한 사실은 날짜와 본체 시스템 버전을 함께 [docs/hardware-notes.ko.md](docs/hardware-notes.ko.md)에 작성합니다. 기기 일련번호, 경로, 사진과 동영상 파일은 올리지 않습니다.
- 앱 화면 문구를 추가하거나 변경하면 `App/ko.lproj`와 `App/en.lproj`의 `Localizable.strings` 두 파일에 같은 키로 넣습니다.

## PR

- `main`에서 브랜치를 만들어 PR을 엽니다. PR 템플릿의 Purpose, Summary of changes, Review points, Verification 절을 채워 주세요.
- 커밋 제목은 `{대상} {액션}` 형태의 한국어 명사형입니다(예: `PTP 컨테이너 추가`). 자세한 규칙은 [docs/conventions.ko.md](docs/conventions.ko.md)의 커밋 절을 참고해 주세요.
- `make test`와 `make check`가 통과해야 하며, PR을 열면 CI가 자동으로 확인합니다. 스위치와 통신하는 코드를 변경했다면 실기기에서 확인한 결과를 작성해 주세요.

## 릴리스

릴리스는 저장소 관리자가 Actions 탭에서 Release 워크플로를 실행해 만듭니다. 버전에서 올릴 자리를 선택하거나 버전을 직접 입력하면, 유니버설 DMG를 빌드해 첨부한 릴리스 초안이 만들어집니다. 초안을 공개하면 `v<버전>` 태그가 생깁니다. 직접 빌드한 앱의 버전은 마지막 `v*` 태그를 따릅니다.
