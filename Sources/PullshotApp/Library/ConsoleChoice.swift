import PullshotKit

/// 꽂힌 스위치 가운데 열어 둘 기기를 고릅니다.
enum ConsoleChoice {
    /// 연 기기가 그대로 꽂혀 있으면 그 기기, 아니면 처음 찾은 기기입니다. 같은 기기인지는 `registryID`로 봅니다.
    /// 다시 꽂으면 `registryID`가 바뀌므로 새 기기로 봅니다.
    static func next(current: AttachedConsole?, attached: [AttachedConsole]) -> AttachedConsole? {
        attached.first { $0.registryID == current?.registryID } ?? attached.first
    }
}
