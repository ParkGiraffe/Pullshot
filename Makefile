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

VERSION ?= $(patsubst v%,%,$(shell git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null))
BUILD_NUMBER ?= $(shell git rev-list --count HEAD 2>/dev/null)

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
	$(if $(VERSION),/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" dist/Pullshot.app/Contents/Info.plist)
	$(if $(BUILD_NUMBER),/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" dist/Pullshot.app/Contents/Info.plist)
	cp -R App/*.lproj dist/Pullshot.app/Contents/Resources/
	cp $(APP_ICON_FILES) LICENSE dist/Pullshot.app/Contents/Resources/
	codesign --force --sign - dist/Pullshot.app

DMGBUILD = .build/dmgbuild/bin/dmgbuild

$(DMGBUILD): App/DMG/requirements.txt
	rm -rf .build/dmgbuild
	python3 -m venv .build/dmgbuild
	.build/dmgbuild/bin/pip install --quiet --require-hashes --only-binary :all: -r App/DMG/requirements.txt

dmg: app $(DMGBUILD)
	version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/Pullshot.app/Contents/Info.plist)" && \
	rm -f "dist/Pullshot-$$version.dmg" && \
	$(DMGBUILD) -s App/DMG/settings.json Pullshot "dist/Pullshot-$$version.dmg"

run-app: app
	open dist/Pullshot.app
