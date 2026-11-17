import PullshotKit

enum ConsoleChoice {
    static func next(current: AttachedConsole?, attached: [AttachedConsole]) -> AttachedConsole? {
        attached.first { $0.registryID == current?.registryID } ?? attached.first
    }
}
