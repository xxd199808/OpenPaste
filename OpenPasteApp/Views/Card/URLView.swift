import SwiftUI

/// URL content view for displaying URL clipboard items
struct URLView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                Text(content)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    URLView(content: "https://example.com/article")
        .frame(width: 300)
        .padding()
        .background(Color.white)
}
