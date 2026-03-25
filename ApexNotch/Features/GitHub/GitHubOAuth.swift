import Foundation
import AppKit

// MARK: - OAuth Config
// Register at: https://github.com/settings/applications/new
// Authorization callback URL: apexnotch://oauth  (任意即可，device flow 不用)

enum GitHubOAuthConfig {
    static let clientID     = GitHubSecrets.clientID
    static let clientSecret = GitHubSecrets.clientSecret
    static let scopes       = "repo,read:user"
}

// MARK: - Device Flow Response

struct DeviceCodeResponse: Sendable {
    let deviceCode: String
    let userCode: String          // 显示给用户的码，如 "XXXX-XXXX"
    let verificationURI: String   // "https://github.com/login/device"
    let expiresIn: Int            // seconds
    let interval: Int             // polling interval seconds
}

// MARK: - GitHubDeviceFlow

actor GitHubDeviceFlow {

    enum FlowState: Sendable {
        case idle
        case awaitingUserCode(DeviceCodeResponse)   // 等待用户在浏览器授权
        case polling                                 // 正在轮询
        case success(String)                         // 获得 token
        case expired
        case error(String)
    }

    private(set) var state: FlowState = .idle
    private var stateCallback: (@Sendable (FlowState) -> Void)?
    private var pollTask: Task<Void, Never>?

    func setStateCallback(_ cb: @escaping @Sendable (FlowState) -> Void) {
        stateCallback = cb
    }

    // MARK: - Start flow

    func start() async {
        guard let response = await requestDeviceCode() else {
            // requestDeviceCode 内部已经调用了 transition(.error(...))
            return
        }
        transition(.awaitingUserCode(response))

        // 自动打开浏览器
        if let url = URL(string: response.verificationURI) {
            await MainActor.run { NSWorkspace.shared.open(url) }
        }

        // 开始轮询
        pollTask = Task { [weak self, response] in
            await self?.pollForToken(response)
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        transition(.idle)
    }

    // MARK: - Private

    private func requestDeviceCode() async -> DeviceCodeResponse? {
        // 检查是否配置了真实的 client_id
        if GitHubOAuthConfig.clientID.contains("xxx") {
            transition(.error("请先在 GitHub 注册 OAuth App 并填入 client_id / client_secret"))
            return nil
        }

        guard let url = URL(string: "https://github.com/login/device/code") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ApexNotch/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10
        let body: [String: String] = [
            "client_id": GitHubOAuthConfig.clientID,
            "scope": GitHubOAuthConfig.scopes
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            // GitHub 返回错误（如 client_id 无效）
            if let errDesc = json["error_description"] as? String {
                transition(.error(errDesc))
                return nil
            }
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                transition(.error("GitHub 返回 \(httpResp.statusCode)，请检查 client_id 是否正确"))
                return nil
            }

            guard let deviceCode = json["device_code"] as? String,
                  let userCode = json["user_code"] as? String,
                  let verificationURI = json["verification_uri"] as? String else {
                transition(.error("GitHub 返回数据格式异常"))
                return nil
            }

            return DeviceCodeResponse(
                deviceCode: deviceCode,
                userCode: userCode,
                verificationURI: verificationURI,
                expiresIn: json["expires_in"] as? Int ?? 900,
                interval: json["interval"] as? Int ?? 5
            )
        } catch {
            transition(.error("无法连接到 GitHub：\(error.localizedDescription)"))
            return nil
        }
    }

    private func pollForToken(_ response: DeviceCodeResponse) async {
        transition(.polling)
        let deadline = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let interval = max(response.interval, 5)

        while !Task.isCancelled, Date() < deadline {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }

            if let token = await exchangeDeviceCode(response.deviceCode) {
                transition(.success(token))
                return
            }
        }
        transition(.expired)
    }

    private func exchangeDeviceCode(_ deviceCode: String) async -> String? {
        guard let url = URL(string: "https://github.com/login/oauth/access_token") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ApexNotch/1.0", forHTTPHeaderField: "User-Agent")
        let body: [String: String] = [
            "client_id":     GitHubOAuthConfig.clientID,
            "client_secret": GitHubOAuthConfig.clientSecret,
            "device_code":   deviceCode,
            "grant_type":    "urn:ietf:params:oauth:grant-type:device_code"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // "authorization_pending" / "slow_down" / access_token
        if let error = json["error"] as? String {
            if error == "slow_down" { try? await Task.sleep(for: .seconds(5)) }
            return nil  // still waiting
        }
        return json["access_token"] as? String
    }

    private func transition(_ newState: FlowState) {
        state = newState
        stateCallback?(newState)
    }
}
