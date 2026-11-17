import ArgumentParser

@main
struct Pullshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pullshot",
        abstract: "USB로 스위치의 캡처를 확인하고 가져오는 개발용 도구입니다.",
        subcommands: [Probe.self, List.self, Pull.self, Ledger.self, Dump.self]
    )
}
