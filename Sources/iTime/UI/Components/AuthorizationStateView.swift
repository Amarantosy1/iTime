import SwiftUI

struct AuthorizationStateView: View {
    let state: CalendarAuthorizationState
    let requestAccess: () -> Void

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calendar access")
                    .font(.headline)

                Text(message)
                    .foregroundStyle(.secondary)

                if state == .notDetermined {
                    Button("Allow Calendar Access", action: requestAccess)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var message: String {
        switch state {
        case .notDetermined:
            "Grant calendar access so iTime can analyze how your scheduled time is distributed."
        case .restricted:
            "Calendar access is restricted by system policy."
        case .denied:
            "Calendar access is denied. Enable it again in System Settings."
        case .authorized:
            ""
        }
    }
}
