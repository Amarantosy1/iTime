import SwiftUI

struct AIConversationMessagesView: View {
    let messages: [AIConversationMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.role == .assistant ? "AI" : "你")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(message.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(backgroundColor(for: message.role))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .id(message.id)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private func backgroundColor(for role: AIConversationMessageRole) -> Color {
        switch role {
        case .assistant:
            return Color.secondary.opacity(0.08)
        case .user:
            return Color.accentColor.opacity(0.12)
        }
    }
}
