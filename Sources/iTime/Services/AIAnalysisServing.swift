import Foundation

public protocol AIAnalysisServing: Sendable {
    func analyze(
        request: AIAnalysisRequest,
        configuration: AIAnalysisConfiguration
    ) async throws -> AIAnalysisResult
}

public enum AIAnalysisServiceError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidResponse
    case unexpectedStatus(Int)
    case transportError(String)

    public var userMessage: String {
        switch self {
        case .invalidConfiguration:
            return "AI 服务配置不完整，请检查设置。"
        case .invalidResponse:
            return "AI 返回了无法解析的结果，请重试。"
        case .unexpectedStatus(let code):
            return "AI 服务请求失败（\(code)），请稍后重试。"
        case .transportError(let detail):
            let normalized = detail.lowercased()
            if normalized.contains("proxy") {
                return "AI 服务连接失败，请检查系统代理、网络或服务地址。"
            }
            return "AI 服务连接失败，请检查网络、系统代理或服务地址。"
        }
    }
}
