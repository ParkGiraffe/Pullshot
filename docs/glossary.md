# Glossary

English | [한국어](glossary.ko.md)

| Term | Meaning | Code |
|---|---|---|
| Console (기기) | A console is the Nintendo Switch 2 or Nintendo Switch that sends photos and videos. | `ConsoleModel`, `AttachedConsole` |
| Copy to PC mode (PC로 복사 모드) | Copy to PC mode is the state in which the console sends photos and videos over USB. You turn it on in the Data Management menu of the console's System Settings. A console that is connected with the mode off is called idle. | `LibraryModel.Connection.notInTransferMode`, `ConsoleLocator.idle()` |
| Transport (전송) | A transport is the channel that exchanges bytes with the console. There are real USB, test mock, and record and replay transports. | `Transport` |
| Session (세션) | A session is the PTP session opened with the console. Handles and storage IDs are valid only within a session. | `Session` |
| Album (앨범) | The album is all the photos and videos stored on the console. | `AlbumScan` |
| Capture (캡처) | A capture is one photo or one video taken on the console. It is a name used only in code. The app UI and docs say "photos and videos", "photo", or "video". | `Capture` |
| Items (항목) | Items is the name the on-screen lists and labels (All Items, New, Selection) use for photos and videos. | |
| Game (게임) | A game is an album folder that holds photos and videos, and the folder name is the game name. The app sidebar calls it a folder. | `Game`, `Capture.gameName`, `LibraryModel.gameSearch` |
| Other (기타) | Other is the group of photos and videos that are outside any game folder or are in the Switch's "Other" folder. The import history key stores the original folder name as is. | `Game.isOther`, `Game.otherFolderName` |
| Save Location (저장 위치) | The save location is the base folder where the app saves imported photos and videos. The default is `~/Pictures/Pullshot`. | `AppSettings.importFolder` |
| Import (가져오기) | Importing copies photos and videos to the Mac and adds them to the import history, using the app's import buttons, dragging to Finder, or the CLI's `pull`. In the app, Import New and Import All save to the game-name folder in the save location with the original names. When you import the selection, you can choose whether to save in game folders and whether to number the files. Dragging to Finder saves where you drop. Dragging one item saves one file, dragging several creates a game-name folder and saves them inside it, and dragging items from several games creates a Pullshot folder and saves them there. | `Transfer`, `ImportTarget`, `CaptureDrag`, `TransferKind.imported` |
| Export (내보내기) | Export is a record kind in the import history that is kept separate from a regular import. It is not used in the app UI or CLI commands. In the app, importing the selection or dragging to Finder is always recorded as an export, regardless of the game folder and file name settings. The CLI `pull` records an export only when you pass `--numbered` or `--no-game-folder`. | `TransferKind.exported`, `ExportOptions` |
| Import history (가져온 기록) | The import history is a file that stores the photos and videos that were imported, found in a folder, or marked as all imported, together with the console serial number and the record kind. It is how New items are determined. | `TransferLedger`, `TransferKind`, `CaptureKey` |
| New (새 항목) | New items are photos and videos that are not in the import history. | `LedgerIndex.newCaptures` |
