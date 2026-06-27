import SwiftUI

public struct RibbonShell<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SenovativeTheme.chromeBackground)
        .overlay(alignment: .bottom) {
            SenovativeTheme.divider.frame(height: 1)
        }
    }
}

public struct RibbonIconButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help(Text(title))
    }
}
