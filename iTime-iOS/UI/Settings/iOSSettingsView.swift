import SwiftUI

struct iOSSettingsView: View {
    @Bindable var model: AppModel
    @State private var apiKeys: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section("AI 服务") {
                    ForEach(model.availableAIServices) { service in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(
                                service.displayName,
                                isOn: Binding(
                                    get: { service.isEnabled },
                                    set: { enabled in
                                        model.updateAIService(service.updating(isEnabled: enabled))
                                    }
                                )
                            )

                            if service.isEnabled {
                                SecureField(
                                    "API Key",
                                    text: Binding(
                                        get: { apiKeys[service.id] ?? "" },
                                        set: { newValue in
                                            apiKeys[service.id] = newValue
                                            model.updateAIAPIKey(newValue, for: service.id)
                                        }
                                    )
                                )
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                iOSDeviceSyncView(model: model)
            }
            .navigationTitle("设置")
            .onAppear { loadAPIKeys() }
            .onChange(of: model.availableAIServices.map(\.id)) { _, _ in
                loadAPIKeys()
            }
        }
    }

    private func loadAPIKeys() {
        for service in model.availableAIServices {
            apiKeys[service.id] = model.loadAIAPIKey(for: service.id)
        }
    }
}
