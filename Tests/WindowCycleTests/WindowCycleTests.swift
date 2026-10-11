import Testing
@testable import WindowCycle

@Test(arguments: [[], ["A"], ["A", "A"]])
func zeroOrOneWindowDoesNothing(windows: [String]) {
    var cycle = WindowCycle<String>()
    #expect(cycle.next(owner: 1, windows: windows, focused: "A", backwards: false) == nil)
}

@Test func visitsEveryWindowEvenWhenAccessibilityOrderChanges() {
    var cycle = WindowCycle<String>()
    #expect(cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: false) == "B")
    #expect(cycle.next(owner: 1, windows: ["B", "A", "C"], focused: "B", backwards: false) == "C")
    #expect(cycle.next(owner: 1, windows: ["C", "B", "A"], focused: "C", backwards: false) == "A")
}

@Test func reversingDirectionAndWrapping() {
    var cycle = WindowCycle<String>()
    #expect(cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: true) == "C")
    #expect(cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "C", backwards: false) == "A")
}

@Test func ignoresDelayedFocusReportsWithinGesture() {
    var cycle = WindowCycle<String>()
    #expect(cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: false) == "B")
    #expect(cycle.next(owner: 1, windows: ["B", "A", "C"], focused: "A", backwards: false) == "C")
}

@Test func releasingOptionStartsFromActualFocus() {
    var cycle = WindowCycle<String>()
    _ = cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: false)
    cycle.reset()
    #expect(cycle.next(owner: 1, windows: ["C", "A", "B"], focused: "C", backwards: false) == "A")
}

@Test func appChangeCannotReuseAnotherAppsWindows() {
    var cycle = WindowCycle<String>()
    _ = cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: false)
    #expect(cycle.next(owner: 2, windows: ["X", "Y"], focused: "X", backwards: false) == "Y")
}

@Test func reconcilesClosedAndNewWindows() {
    var cycle = WindowCycle<String>()
    _ = cycle.next(owner: 1, windows: ["A", "B", "C"], focused: "A", backwards: false)
    #expect(cycle.next(owner: 1, windows: ["A", "C", "D"], focused: "A", backwards: false) == "C")
    #expect(cycle.next(owner: 1, windows: ["C", "A", "D"], focused: "C", backwards: false) == "D")
}

@Test func missingFocusStillSelectsAValidWindow() {
    var cycle = WindowCycle<String>()
    #expect(cycle.next(owner: 1, windows: ["A", "B"], focused: nil, backwards: false) == "A")
}
