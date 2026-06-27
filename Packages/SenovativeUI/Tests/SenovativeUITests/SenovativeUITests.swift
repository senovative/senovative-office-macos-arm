import Testing
@testable import SenovativeUI

@Test func themeAccentExists() {
    _ = SenovativeTheme.accent
    #expect(Bool(true))
}
