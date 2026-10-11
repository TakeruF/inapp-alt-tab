/// A stable ring for one Option-key gesture. Window enumeration can reorder after every raise.
public struct WindowCycle<Window: Equatable> {
    private var owner: Int32?
    private var order: [Window] = []
    private var selected: Window?

    public init() {}

    public mutating func reset() {
        owner = nil
        order = []
        selected = nil
    }

    public mutating func next(owner: Int32, windows: [Window], focused: Window?, backwards: Bool) -> Window? {
        var available: [Window] = []
        for window in windows where !available.contains(window) {
            available.append(window)
        }
        guard available.count > 1 else {
            reset()
            return nil
        }
        if self.owner != owner {
            reset()
            self.owner = owner
        }
        order.removeAll { !available.contains($0) }
        for window in available where !order.contains(window) {
            order.append(window)
        }
        let current = selected.flatMap { order.firstIndex(of: $0) }
            ?? focused.flatMap { order.firstIndex(of: $0) }
        let index: Int
        if let current {
            index = (current + (backwards ? -1 : 1) + order.count) % order.count
        } else {
            index = backwards ? order.count - 1 : 0
        }
        let target = order[index]
        selected = target
        return target
    }
}
