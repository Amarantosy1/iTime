import SwiftUI

struct AIConversationMessagesView: View {
    let messages: [AIConversationMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages, id: \.id) { message in
                        HStack(alignment: .bottom, spacing: 0) {
                            if message.role == .assistant {
                                messageBubble(for: message)
                                Spacer(minLength: 96)
                            } else {
                                Spacer(minLength: 96)
                                messageBubble(for: message)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.secondary.opacity(0.03))
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

    private func messageBubble(for message: AIConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .assistant ? "AI" : "你")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(backgroundColor(for: message.role))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func backgroundColor(for role: AIConversationMessageRole) -> Color {
        switch role {
        case .assistant:
            return Color.secondary.opacity(0.08)
        case .user:
            return Color.accentColor.opacity(0.15)
        }
    }
}
