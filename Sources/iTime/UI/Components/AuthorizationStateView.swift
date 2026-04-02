import SwiftUI

struct AuthorizationStateView: View {
    let state: CalendarAuthorizationState
    let requestAccess: () -> Void

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("日历权限")
                    .font(.headline)

                Text(message)
                    .foregroundStyle(.secondary)

                if state == .notDetermined {
                    Button("允许访问日历", action: requestAccess)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var message: String {
        switch state {
        case .notDetermined:
            "请授予日历访问权限，以便 iTime 统计你的时间分布。"
        case .restricted:
            "系统策略限制了日历访问。"
        case .denied:
            "日历访问已被拒绝，请到系统设置中重新开启。"
        case .authorized:
            ""
        }
    }
}
