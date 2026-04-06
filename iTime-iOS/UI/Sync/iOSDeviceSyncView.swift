import SwiftUI

struct iOSDeviceSyncView: View {
    @Bindable var model: AppModel

    var body: some View {
        Section("设备互传") {
            HStack(alignment: .center, spacing: 10) {
                Button("开始发现设备") {
                    Task { await model.startDeviceDiscovery() }
                }
                .buttonStyle(.borderedProminent)

                Button("停止发现") {
                    Task { await model.stopDeviceDiscovery() }
                }
                .buttonStyle(.bordered)
            }

            if model.discoveredPeers.isEmpty {
                Text("暂未发现可连接设备")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.discoveredPeers) { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(peer.displayName)
                                .font(.body.weight(.medium))
                            Spacer()
                            Button("立即同步") {
                                Task {
                                    try? await model.syncNow(with: peer.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSyncing)
                        }

                        TagChip(
                            icon: peer.state.iconName,
                            text: peer.state.displayText,
                            theme: model.preferences.interfaceTheme
                        )
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(spacing: 8) {
                if case .syncing = model.lastSyncStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(model.lastSyncStatus.displayText)
                    .font(.footnote)
                    .foregroundStyle(model.lastSyncStatus.color)
            }
        }
    }

    private var isSyncing: Bool {
        if case .syncing = model.lastSyncStatus { return true }
        return false
    }
}

private extension DevicePeer.ConnectionState {
    var displayText: String {
        switch self {
        case .discovered: return "已发现"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .failed(let message): return "异常 · \(message)"
        }
    }

    var iconName: String {
        switch self {
        case .discovered: return "dot.radiowaves.left.and.right"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

private extension AppModel.DeviceSyncStatus {
    var displayText: String {
        switch self {
        case .idle: return "空闲"
        case .syncing: return "同步中"
        case .succeeded: return "同步成功"
        case .failed(let message): return "同步失败 · \(message)"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var color: Color {
        switch self {
        case .idle, .syncing:
            .secondary
        case .succeeded:
            .green
        case .failed:
            .red
        }
    }
}
