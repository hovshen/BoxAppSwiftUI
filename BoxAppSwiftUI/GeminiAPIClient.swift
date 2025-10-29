import Foundation

enum GeminiAPIError: LocalizedError {
    case missingAPIKey
    case missingBundleIdentifier
    case requestEncodingFailed
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "無法找到 Gemini API 金鑰，請確認設定檔是否存在。"
        case .missingBundleIdentifier:
            return "無法取得應用程式識別碼。"
        case .requestEncodingFailed:
            return "建立 Gemini API 請求時發生錯誤。"
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Gemini API 回應格式不符合預期。"
        }
    }
}

struct GeminiAPIConfiguration {
    let url: URL
    let apiKey: String
    let bundleIdentifier: String

    static func makeDefault() throws -> GeminiAPIConfiguration {
        guard
            let filePath = Bundle.main.path(forResource: "GenerativeAI-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: filePath),
            let key = plist.object(forKey: "API_KEY") as? String,
            !key.isEmpty
        else {
            throw GeminiAPIError.missingAPIKey
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw GeminiAPIError.missingBundleIdentifier
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent")!
        return GeminiAPIConfiguration(url: url, apiKey: key, bundleIdentifier: bundleIdentifier)
    }
}

struct GeminiAPIClient {
    private let configuration: GeminiAPIConfiguration

    init(configuration: GeminiAPIConfiguration) {
        self.configuration = configuration
    }

    static func makeDefault() throws -> GeminiAPIClient {
        GeminiAPIClient(configuration: try .makeDefault())
    }

    func makeRequest(base64Image: String) throws -> URLRequest {
        var request = URLRequest(url: configuration.url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue(configuration.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        do {
            request.httpBody = try JSONEncoder().encode(GeminiRequestBody(base64Image: base64Image))
        } catch {
            throw GeminiAPIError.requestEncodingFailed
        }

        return request
    }

    func parseResponse(data: Data) throws -> String {
        let decoder = JSONDecoder()

        if let success = try? decoder.decode(GeminiSuccessResponse.self, from: data),
           let text = success.firstText {
            return text
        }

        if let errorResponse = try? decoder.decode(GeminiErrorResponse.self, from: data) {
            throw GeminiAPIError.apiError(errorResponse.error.message)
        }

        throw GeminiAPIError.invalidResponse
    }
}

private struct GeminiRequestBody: Encodable {
    struct Content: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String?
        let inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct InlineData: Encodable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    let contents: [Content]

    init(base64Image: String) {
        let prompt = "請辨識這張圖片中的電子零件，並用繁體中文、條列式的方式提供以下資訊，如果某項資訊不適用或無法辨識，請寫'N/A'：\n1. **零件名稱**: \n2. **規格**: (例如：阻值、電容值、型號)\n3. **適用功率**: \n4. **常見用途**: (用於哪種電路或應用)\n5. **主要功能**: "

        contents = [
            Content(parts: [
                Part(text: prompt, inlineData: nil),
                Part(text: nil, inlineData: InlineData(mimeType: "image/jpeg", data: base64Image))
            ])
        ]
    }
}

private struct GeminiSuccessResponse: Decodable {
    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
    }

    let candidates: [Candidate]

    var firstText: String? {
        candidates
            .flatMap { $0.content.parts }
            .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct GeminiErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
    }

    let error: ErrorDetail
}
