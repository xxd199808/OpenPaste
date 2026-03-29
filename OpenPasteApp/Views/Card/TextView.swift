import SwiftUI

/// Text content view for displaying plain text clipboard items
struct TextView: View {
    let content: String

    var body: some View {
        Text(content.isEmpty ? "[Empty content]" : content)
            .font(.system(size: 13))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            .lineLimit(6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    TextView(content: "Example clipboard text content that spans multiple lines and should be displayed properly")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
