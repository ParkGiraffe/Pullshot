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

APP_ICONS = icon-red-gamepad icon-purple-gamepad icon-shutter
APP_ICON_FILES = $(APP_ICONS:%=.build/app-icons/%.icns)

.build/app-icons/%.icns: App/Icons/%.png App/Icons/%-small.png Scripts/make-icns.sh
	Scripts/make-icns.sh $< $@ App/Icons/$*-small.png

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
