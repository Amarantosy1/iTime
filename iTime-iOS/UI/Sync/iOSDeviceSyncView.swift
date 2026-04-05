import SwiftUI

struct iOSDeviceSyncView: View {
    @Bindable var model: AppModel

    var body: some View {
        Section("设备互传") {
            Button("刷新设备") {
                Task { await model.startDeviceDiscovery() }
            }

            if model.discoveredPeers.isEmpty {
                Text("暂未发现可连接设备")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.discoveredPeers) { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(peer.displayName)
                            Spacer()
                            Button("立即同步") {
                                Task {
                                    try? await model.syncNow(with: peer.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSyncing)
                        }

                        Text(peer.state.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text(model.lastSyncStatus.displayText)
                .font(.footnote)
                .foregroundStyle(model.lastSyncStatus.isFailure ? .red : .secondary)
        }
    }

    private var isSyncing: Bool {
        if case .syncing = model.lastSyncStatus {
            return true
        }
        return false
    }
}

private extension DevicePeer.ConnectionState {
    var displayText: String {
        switch self {
        case .discovered:
            return "已发现"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .failed(let message):
            return "异常 · \(message)"
        }
    }
}

private extension AppModel.DeviceSyncStatus {
    var displayText: String {
        switch self {
        case .idle:
            return "空闲"
        case .syncing:
            return "同步中"
        case .succeeded:
            return "同步成功"
        case .failed(let message):
            return "同步失败 · \(message)"
        }
    }

    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
