import PullshotKit

enum ConsoleChoice {
    static func preferring(_ current: AttachedConsole?, among attached: [AttachedConsole]) -> AttachedConsole? {
        attached.first { $0.registryID == current?.registryID } ?? attached.first
    }
}
