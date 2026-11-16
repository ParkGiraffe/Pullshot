# 용어

| 용어 | 뜻 | 코드 |
|---|---|---|
| 기기 | 캡처를 보내 주는 Nintendo Switch 2 또는 Nintendo Switch입니다. | `ConsoleModel`, `AttachedConsole` |
| PC로 복사 모드 | 기기가 USB로 캡처를 보내는 상태입니다. 본체 설정의 데이터 관리 메뉴에서 켭니다. | |
| 전송 | 기기와 바이트를 주고받는 통로입니다. 실제 USB, 테스트용 가짜, 기록과 재생이 있습니다. | `Transport` |
| 세션 | 기기와 연 PTP 세션입니다. 핸들과 저장소 ID는 세션 안에서만 뜻이 있습니다. | `Session` |
| 앨범 | 기기에 저장된 캡처 전체입니다. | `AlbumScan` |
| 캡처 | 기기가 찍은 사진 한 장이나 영상 하나입니다. | `Capture` |
| 게임 | 캡처가 든 앨범 폴더입니다. 폴더 이름이 게임 이름입니다. | `Game`, `Capture.gameName` |
| 기타 | 게임 폴더 밖에 있거나 스위치의 "기타" 폴더에 든 캡처의 묶음입니다. 기록의 열쇠에는 원래 폴더 값을 그대로 둡니다. | `Game.isOther`, `Game.otherFolderName` |
| 옮김 | 가져오기나 내보내기로 캡처를 Mac에 저장한 일입니다. | `TransferLedger`, `TransferKind` |
| 새 항목 | 아직 한 번도 옮기지 않은 캡처입니다. | `LedgerIndex.newCaptures` |
