import SwiftUI

struct AIConversationComposerView: View {
    @Binding var replyDraft: String
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField(AIConversationWindowCopy.inputPlaceholder, text: $replyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4, reservesSpace: false)
                .focused($isFocused)

            HStack {
                Button(AIConversationWindowCopy.sendReplyAction, action: onSend)
                    .buttonStyle(.borderedProminent)
                    .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(AIConversationWindowCopy.finishConversationAction, action: onFinish)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(.regularMaterial)
        .onAppear {
            isFocused = true
        }
    }
}
