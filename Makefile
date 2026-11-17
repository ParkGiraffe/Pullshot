.PHONY: build test lint format check setup-hooks app dmg run-app

build:
	swift build

test:
	swift test

lint:
	swiftlint

format:
	swiftformat .

check:
	swiftlint --strict
	swiftformat --lint .

setup-hooks:
	git config core.hooksPath Scripts/git-hooks

# 설정에서 고르는 앱 아이콘(`AppIcon`) 세 가지입니다. 빨강이 Info.plist의 번들 기본 아이콘입니다.
APP_ICONS = icon-red-gamepad icon-purple-gamepad icon-shutter
APP_ICON_FILES = $(APP_ICONS:%=.build/app-icons/%.icns)

.build/app-icons/%.icns: App/Icons/%.png App/Icons/%-small.png Scripts/make-icns.sh
	Scripts/make-icns.sh $< $@ App/Icons/$*-small.png

# Apple 실리콘과 Intel Mac에서 모두 열리도록 아키텍처마다 따로 빌드해 합칩니다.
# Command Line Tools에는 `swift build --arch`를 여럿 받는 xcbuild가 없습니다(2026-11-16 확인).
app: $(APP_ICON_FILES)
	swift build -c release --product PullshotApp --triple arm64-apple-macosx
	swift build -c release --product PullshotApp --triple x86_64-apple-macosx
	rm -rf dist/Pullshot.app
	mkdir -p dist/Pullshot.app/Contents/MacOS dist/Pullshot.app/Contents/Resources
	lipo -create -output dist/Pullshot.app/Contents/MacOS/Pullshot \
		"$$(swift build -c release --triple arm64-apple-macosx --show-bin-path)/PullshotApp" \
		"$$(swift build -c release --triple x86_64-apple-macosx --show-bin-path)/PullshotApp"
	cp App/Info.plist dist/Pullshot.app/Contents/
	cp -R App/*.lproj dist/Pullshot.app/Contents/Resources/
	cp $(APP_ICON_FILES) dist/Pullshot.app/Contents/Resources/
	codesign --force --sign - dist/Pullshot.app

dmg: app
	rm -rf dist/dmg-staging
	mkdir -p dist/dmg-staging
	cp -R dist/Pullshot.app LICENSE dist/dmg-staging/
	ln -s /Applications dist/dmg-staging/Applications
	version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)" && \
	rm -f "dist/Pullshot-$$version.dmg" && \
	hdiutil create -volname Pullshot -srcfolder dist/dmg-staging -format UDZO "dist/Pullshot-$$version.dmg"
	rm -rf dist/dmg-staging

run-app: app
	open dist/Pullshot.app
