# 기여 안내

Pullshot에 관심을 가져 주셔서 고맙습니다. 이슈와 PR은 한국어나 영어로 써 주시면 됩니다.

## 이슈

- 버그는 "버그 알리기" 양식으로 알려 주세요. 다시 겪을 수 있다면 설정에서 "자세한 로그 남기기"를 켜고 한 번 더 해 본 뒤, 도움말 메뉴의 로그 파일 보기로 찾은 로그 파일을 붙여 주세요. 로그에는 파일 이름, 게임 이름, 경로, 일련번호가 남지 않습니다.
- Nintendo Switch는 실제 본체로 시험하지 못해 실험적으로 지원합니다. Nintendo Switch에서 된다거나 안 된다는 소식은 작은 것이라도 큰 도움이 됩니다.
- 기능 제안은 "기능 제안" 양식으로 남겨 주세요. 큰 변경은 PR보다 이슈로 먼저 이야기해 주시면 서로 수고를 덜 수 있습니다.

## 개발 환경

```bash
brew bundle        # SwiftLint, SwiftFormat 설치
make setup-hooks   # 커밋 전 린트와 포맷 검사 설정
make test
make check
make app           # dist/Pullshot.app
```

- 코딩 규칙은 [docs/conventions.md](docs/conventions.md)에 있습니다. 코드에는 주석을 두지 않습니다.
- 용어와 코드 이름의 짝은 [docs/glossary.md](docs/glossary.md)에 있습니다.
- 실기기에서 확인한 사실은 날짜와 본체 시스템 버전을 붙여 [docs/hardware-notes.md](docs/hardware-notes.md)에 적습니다. 기기 일련번호, 경로, 캡처 파일은 올리지 않습니다.
- 앱 화면 문구를 더하거나 바꾸면 `App/ko.lproj`와 `App/en.lproj`의 `Localizable.strings` 두 표에 같은 키로 넣습니다.

## PR

- `main`을 기준으로 브랜치를 만들어 PR을 엽니다. PR 템플릿의 목적, 변경 요약, 리뷰 포인트, 검증 내용을 채워 주세요.
- 커밋 제목은 `{대상} {액션}` 꼴의 한국어 명사형입니다(예: `PTP 컨테이너 추가`). 자세한 규칙은 [docs/conventions.md](docs/conventions.md)의 커밋 절에 있습니다.
- `make test`와 `make check`가 통과해야 합니다. 스위치와 주고받는 부분을 바꿨다면 실기기로 확인한 결과를 적어 주세요.
