.PHONY: build test lint format check setup-hooks app run-app

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

run-app: app
	open dist/Pullshot.app
