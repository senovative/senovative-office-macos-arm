import SwiftUI

public struct StatusPill: View {
    private let text: LocalizedStringKey

    public init(_ text: LocalizedStringKey) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(.secondary)
    }
}
