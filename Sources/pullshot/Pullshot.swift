import ArgumentParser

@main
struct Pullshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pullshot",
        abstract: "스위치의 캡처를 USB로 확인하고 받는 개발용 도구입니다.",
        subcommands: [Probe.self, List.self, Pull.self, Dump.self]
    )
}
