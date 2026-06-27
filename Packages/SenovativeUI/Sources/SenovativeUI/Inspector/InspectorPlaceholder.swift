import SwiftUI

public struct InspectorPlaceholder: View {
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey = "Inspector") {
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Divider()
            Text("No selection")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
        .background(SenovativeTheme.chromeBackground)
    }
}
