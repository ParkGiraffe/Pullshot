# Contributing

English | [한국어](CONTRIBUTING.ko.md)

Thank you for your interest in Pullshot. You can write issues and pull requests in English or Korean.

## Issues

- Report bugs with the "Bug report" form. If you can reproduce the problem, turn on "Detailed logging" in Settings, try again, and attach the log file you find with Help > Show Log File. Logs don't include file names, game names, paths, or serial numbers.
- Nintendo Switch support is experimental because it hasn't been tested on a real console. Any report on whether it works on Nintendo Switch, however small, is a big help.
- Suggest features with the "Feature request" form. For large changes, please discuss them in an issue before opening a pull request.

## Development environment

```bash
brew bundle        # Installs SwiftLint and SwiftFormat
make setup-hooks   # Runs lint and format checks before each commit
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
make app           # Builds dist/Pullshot.app
```

- Follow the coding conventions in [docs/conventions.md](docs/conventions.md). Don't write comments in code.
- Terms and code names are listed in [docs/glossary.md](docs/glossary.md).
- Record facts you verified on a real console in [docs/hardware-notes.md](docs/hardware-notes.md), together with the date and the console's system version. Don't upload device serial numbers, paths, or photo and video files.
- When you add or change text shown in the app, add it with the same key to both `Localizable.strings` files, in `App/ko.lproj` and `App/en.lproj`.

## Pull requests

- Create a branch from `main` and open a pull request. Fill in the Purpose, Summary of changes, Review points, and Verification sections of the template.
- Commit titles are Korean noun phrases in the `{대상} {액션}` (target, action) form, for example `PTP 컨테이너 추가` (add PTP container). See the commits section of [docs/conventions.md](docs/conventions.md) for details.
- `make test` and `make check` must pass, and CI runs them automatically on every pull request. If you changed code that communicates with the Switch, include the results you verified on a real console.

## Releases

Maintainers make a release by running the Release workflow from the Actions tab. Choose which part of the version to increase, or enter an exact version, and the workflow builds a universal DMG and creates a draft release with it attached. Publishing the draft creates the `v<version>` tag. Apps you build yourself take their version from the latest `v*` tag.
