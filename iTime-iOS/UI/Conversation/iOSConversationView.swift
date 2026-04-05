import SwiftUI

struct iOSConversationView: View {
    @Bindable var model: AppModel
    @State private var reply = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        switch model.aiConversationState {
                        case .waitingForUser(let session), .responding(let session), .summarizing(let session):
                            ForEach(session.messages, id: \.id) { item in
                                messageBubble(item)
                            }
                        case .completed(let summary):
                            Text(summary.headline)
                                .font(.headline)
                            Text(summary.summary)
                                .foregroundStyle(.secondary)
                        case .failed(let message):
                            Text(message)
                                .foregroundStyle(.red)
                        case .unavailable(let availability):
                            Text(availability.message)
                                .foregroundStyle(.secondary)
                        case .idle:
                            Text("点击右上角“新建”开始复盘")
                                .foregroundStyle(.secondary)
                        case .asking:
                            ProgressView("AI 正在准备问题…")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if canReply {
                    HStack(spacing: 8) {
                        TextField("输入你的补充信息…", text: $reply, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)

                        Button("发送") {
                            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            Task {
                                let outgoing = trimmed
                                reply = ""
                                await model.sendAIConversationReply(outgoing)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSending)
                    }
                    .padding(.horizontal)

                    Button("结束并生成总结") {
                        Task { await model.finishAIConversation() }
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("新建复盘")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建") {
                        Task { await model.startAIConversation() }
                    }
                    .disabled(!canStart)
                }
            }
        }
    }

    private var canStart: Bool {
        switch model.aiConversationState {
        case .idle, .completed, .failed, .unavailable:
            return true
        case .asking, .responding, .waitingForUser, .summarizing:
            return false
        }
    }

    private var canReply: Bool {
        switch model.aiConversationState {
        case .waitingForUser, .responding:
            return true
        default:
            return false
        }
    }

    private var isSending: Bool {
        if case .responding = model.aiConversationState {
            return true
        }
        return false
    }

    @ViewBuilder
    private func messageBubble(_ message: AIConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(message.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(message.role == .assistant ? Color.secondary.opacity(0.12) : Color.accentColor.opacity(0.12))
                )
        }
    }
}

private extension AIConversationMessageRole {
    var displayTitle: String {
        switch self {
        case .assistant:
            return "AI"
        case .user:
            return "你"
        }
    }
}
