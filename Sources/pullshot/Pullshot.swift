import ArgumentParser

@main
struct Pullshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pullshot",
        abstract: "스위치의 캡처를 USB로 확인하고 받고 내보내는 개발용 도구입니다.",
        subcommands: [Probe.self, List.self, Pull.self, Export.self, Ledger.self, Dump.self]
    )
}
