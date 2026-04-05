import SwiftUI

struct DeviceSyncSettingsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("设备互传")
                    .font(.headline)
                Text("在同一局域网或近场连接下，手动触发与其他设备互传复盘与设置数据。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("开始发现设备") {
                        Task { await model.startDeviceDiscovery() }
                    }
                    .buttonStyle(.bordered)

                    Button("停止发现") {
                        Task { await model.stopDeviceDiscovery() }
                    }
                    .buttonStyle(.bordered)
                }

                if model.discoveredPeers.isEmpty {
                    Text("尚未发现设备。")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.discoveredPeers) { peer in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peer.displayName)
                                    Text(peerStateText(peer.state))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("立即同步") {
                                    Task { try? await model.syncNow(with: peer.id) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                Text(syncStatusText(model.lastSyncStatus))
                    .foregroundStyle(syncStatusColor(model.lastSyncStatus))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func peerStateText(_ state: DevicePeer.ConnectionState) -> String {
        switch state {
        case .discovered:
            return "已发现"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .failed(let message):
            return "失败：\(message)"
        }
    }

    private func syncStatusText(_ status: AppModel.DeviceSyncStatus) -> String {
        switch status {
        case .idle:
            return "状态：空闲"
        case .syncing:
            return "状态：同步中…"
        case .succeeded:
            return "状态：同步成功"
        case .failed(let message):
            return "状态：\(message)"
        }
    }

    private func syncStatusColor(_ status: AppModel.DeviceSyncStatus) -> Color {
        switch status {
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .idle, .syncing:
            return .secondary
        }
    }
}
