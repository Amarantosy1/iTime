import AppKit
import SwiftUI

enum AIConversationComposerKeyBehavior {
    static func shouldSendOnReturn(modifiers: NSEvent.ModifierFlags) -> Bool {
        modifiers.intersection([.shift, .option, .command, .control]).isEmpty
    }
}

struct AIConversationComposerView: View {
    @Binding var replyDraft: String
    @FocusState.Binding var isFocused: Bool
    let isSending: Bool
    let statusText: String?
    let onSend: () -> Void
    let onFinish: () -> Void

    private var canSend: Bool {
        !replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let statusText {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(AIConversationWindowCopy.inputPlaceholder)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    AIConversationComposerTextView(
                        text: $replyDraft,
                        isFocused: isFocused,
                        isDisabled: isSending,
                        onSend: {
                            if canSend {
                                onSend()
                            }
                        }
                    )
                    .frame(minHeight: 104, maxHeight: 164)
                }
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                )

                HStack(alignment: .center, spacing: 12) {
                    Text(AIConversationWindowCopy.composerHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(AIConversationWindowCopy.finishConversationAction, action: onFinish)
                        .buttonStyle(.bordered)
                        .disabled(isSending)

                    Button(action: onSend) {
                        Label(AIConversationWindowCopy.sendReplyAction, systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(height: 1)
        }
        .onAppear {
            if !isSending {
                isFocused = true
            }
        }
    }
}

private struct AIConversationComposerTextView: NSViewRepresentable {
    @Binding var text: String
    let isFocused: Bool
    let isDisabled: Bool
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = ComposerTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        textView.onSend = onSend
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.onSend = onSend
        textView.isEditable = !isDisabled

        if isFocused, textView.window?.firstResponder !== textView, !isDisabled {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class ComposerTextView: NSTextView {
    var onSend: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        if isReturnKey, AIConversationComposerKeyBehavior.shouldSendOnReturn(modifiers: event.modifierFlags) {
            onSend?()
            return
        }

        super.keyDown(with: event)
    }
}
