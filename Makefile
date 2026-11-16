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

app:
	swift build -c release --product PullshotApp
	rm -rf dist/Pullshot.app
	mkdir -p dist/Pullshot.app/Contents/MacOS dist/Pullshot.app/Contents/Resources
	cp "$$(swift build -c release --show-bin-path)/PullshotApp" dist/Pullshot.app/Contents/MacOS/Pullshot
	cp App/Info.plist dist/Pullshot.app/Contents/
	cp -R App/*.lproj dist/Pullshot.app/Contents/Resources/
	codesign --force --sign - dist/Pullshot.app

dmg: app
	rm -rf dist/dmg-staging
	mkdir -p dist/dmg-staging
	cp -R dist/Pullshot.app dist/dmg-staging/
	ln -s /Applications dist/dmg-staging/Applications
	version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)" && \
	rm -f "dist/Pullshot-$$version.dmg" && \
	hdiutil create -volname Pullshot -srcfolder dist/dmg-staging -format UDZO "dist/Pullshot-$$version.dmg"
	rm -rf dist/dmg-staging

run-app: app
	open dist/Pullshot.app
