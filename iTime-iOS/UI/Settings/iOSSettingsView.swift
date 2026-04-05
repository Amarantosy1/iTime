import SwiftUI

struct iOSSettingsView: View {
    @Bindable var model: AppModel
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            List {
                Section("AI 服务") {
                    if !model.availableAIServices.isEmpty {
                        Picker(
                            "当前服务",
                            selection: Binding(
                                get: { model.selectedConversationServiceID ?? model.availableAIServices[0].id },
                                set: { model.selectConversationService(id: $0) }
                            )
                        ) {
                            ForEach(model.availableAIServices) { service in
                                Text(service.displayName).tag(service.id)
                            }
                        }
                    }

                    if let selectedService {
                        SecureField("API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, value in
                                model.updateAIAPIKey(value, for: selectedService.id)
                            }
                    }
                }

                iOSDeviceSyncView(model: model)
            }
            .navigationTitle("设置")
            .onAppear {
                reloadAPIKey()
            }
            .onChange(of: model.selectedConversationServiceID) { _, _ in
                reloadAPIKey()
            }
        }
    }

    private var selectedService: AIServiceEndpoint? {
        if let selectedID = model.selectedConversationServiceID {
            return model.availableAIServices.first(where: { $0.id == selectedID })
        }
        return model.availableAIServices.first
    }

    private func reloadAPIKey() {
        guard let selectedService else {
            apiKey = ""
            return
        }
        apiKey = model.loadAIAPIKey(for: selectedService.id)
    }
}
