import Foundation
import AVFoundation
import UIKit // 需要 UIKit 來取得 Base64 影像
import Combine

// 繼承 NSObject 以便遵從 AVCapturePhotoCaptureDelegate
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    static let defaultResultText = "將電子零件放置於下方框內，然後點擊「辨識零件」按鈕。"

    // MARK: - AVFoundation 屬性
    @Published var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    @Published var previewLayer: AVCaptureVideoPreviewLayer!
    @Published var device: AVCaptureDevice? // 用於縮放

    // MARK: - Gemini API 屬性
    // (讀取 GenerativeAI-Info.plist)
    private var geminiAPIKey: String {
        guard let filePath = Bundle.main.path(forResource: "GenerativeAI-Info", ofType: "plist"), //
              let plist = NSDictionary(contentsOfFile: filePath),
              let key = plist.object(forKey: "API_KEY") as? String, !key.isEmpty else {
            fatalError("無法在 GenerativeAI-Info.plist 中找到 'API_KEY'。")
        }
        return key
    }
    private let geminiURL = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent")!

    // MARK: - @Published 狀態 (用於驅動 SwiftUI 更新)
    @Published var isLoading: Bool = false
    @Published var resultText: String = CameraManager.defaultResultText
    @Published var errorAlert: ErrorAlert? // 用於彈出式錯誤
    // --- *** 新增：加入 isSessionRunning 狀態 *** ---
    @Published var isSessionRunning: Bool = false // 追蹤相機預覽是否運作
    // --- *** 新增結束 *** ---


    // MARK: - 初始化
    override init() {
        super.init()
        setupCamera()
    }

    // MARK: - 相機設定
    private func setupCamera() {
        session.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            let message = "無法啟用後置鏡頭，請檢查 App 權限或重啟 App。"
            print(message)
            self.errorAlert = ErrorAlert(title: "相機錯誤", message: message)
            return
        }
        self.device = backCamera // 保存 device 實例

        do {
            // --- 對焦邏輯 ---
            try backCamera.lockForConfiguration()
            if backCamera.isFocusPointOfInterestSupported {
                backCamera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if backCamera.isFocusModeSupported(.continuousAutoFocus) {
                backCamera.focusMode = .continuousAutoFocus
            }
            if backCamera.isSmoothAutoFocusSupported {
                backCamera.isSmoothAutoFocusEnabled = true
            }
            backCamera.unlockForConfiguration()
            // --- 對焦邏輯結束 ---

            let input = try AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

        } catch {
            let message = "設定相機輸入時發生錯誤: \(error.localizedDescription)"
            print(message)
            self.errorAlert = ErrorAlert(title: "相機設定失敗", message: message)
            return
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // 建立 previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
    }

    // MARK: - Session 控制
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                 // *** 更新 isSessionRunning 狀態 ***
                 DispatchQueue.main.async {
                    self.isSessionRunning = true
                 }
            }
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
             // *** 更新 isSessionRunning 狀態 ***
             DispatchQueue.main.async {
                self.isSessionRunning = false
             }
        }
    }

    func resetScanState() {
        DispatchQueue.main.async {
            self.resultText = CameraManager.defaultResultText
            self.errorAlert = nil
            self.isLoading = false
        }
    }

    // MARK: - 拍照
    func capturePhoto() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.resultText = "辨識中，請稍候..."
            self.errorAlert = nil // 清除舊錯誤
        }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // --- 省電模式修改點 (可選) ---
        // 如果你想啟用省電模式（拍完即停），在這裡呼叫 self.stopSession()
        // self.stopSession() // <--- 如果要省電，取消註解這行
        // --- 修改點結束 ---

        if let error = error {
            print("拍照失敗: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorAlert = ErrorAlert(title: "拍照失敗", message: error.localizedDescription)
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorAlert = ErrorAlert(title: "拍照失敗", message: "無法處理拍攝的影像資料。")
            }
            return
        }

        let base64Image = imageData.base64EncodedString()
        callGeminiAPI(with: base64Image)
    }

    // MARK: - 縮放
    func zoom(with factor: CGFloat) {
        guard let device = self.device else { return }
        let newScaleFactor = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = newScaleFactor
        } catch {
            print("Error locking device for configuration: \(error)")
        }
    }

    // MARK: - 手動對焦
    func focus(at point: CGPoint) {
        guard let device = self.device else { return }
        let focusPoint = CGPoint(
            x: max(0.0, min(1.0, point.x)),
            y: max(0.0, min(1.0, point.y))
        )
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            print("鎖定裝置以設定對焦時失敗: \(error)")
        }
    }


    // MARK: - Gemini API 呼叫
    private func callGeminiAPI(with base64Image: String) {
        var request = URLRequest(url: geminiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue(Bundle.main.bundleIdentifier!, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        let jsonBody: [String: Any] = [ /* ... JSON Body ... */
            "contents": [
                [
                    "parts": [
                        [ "text": "請辨識這張圖片中的電子零件，並用繁體中文、條列式的方式提供以下資訊，如果某項資訊不適用或無法辨識，請寫'N/A'：\n1. **零件名稱**: \n2. **規格**: (例如：阻值、電容值、型號)\n3. **適用功率**: \n4. **常見用途**: (用於哪種電路或應用)\n5. **主要功能**: " ],
                        [ "inline_data": [ "mime_type": "image/jpeg", "data": base64Image ] ]
                    ]
                ]
            ]
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonBody)
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false // 無論成功失敗，isLoading 都結束
            }

            if let error = error { /* ... 錯誤處理 ... */
                DispatchQueue.main.async { self.errorAlert = ErrorAlert(title: "API 請求失敗", message: error.localizedDescription) }
                return
            }
            guard let data = data else { /* ... 錯誤處理 ... */
                 DispatchQueue.main.async { self.errorAlert = ErrorAlert(title: "API 錯誤", message: "未收到 API 回應資料。") }
                return
            }

            do { /* ... JSON 解析 ... */
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let candidates = jsonResponse["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    DispatchQueue.main.async {
                        self.resultText = text
                    }
                } else if let errorResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let errorDetails = errorResponse["error"] as? [String: Any],
                          let errorMessage = errorDetails["message"] as? String {
                     DispatchQueue.main.async { self.errorAlert = ErrorAlert(title: "Gemini API 錯誤", message: errorMessage) }
                } else {
                     DispatchQueue.main.async { self.errorAlert = ErrorAlert(title: "API 回應解析失敗", message: "收到的回應格式不符預期。") }
                }
            } catch { /* ... 錯誤處理 ... */
                 DispatchQueue.main.async { self.errorAlert = ErrorAlert(title: "API 回應解析錯誤", message: error.localizedDescription) }
            }
        }
        task.resume()
    }

} // <-- Class 結束的 }


// 字串解析函式 (保持在 Class 外部)
// 字串解析函式 (修改後)
func parsePartResult(from text: String) -> (name: String, spec: String, function: String)? {
    let normalizedText = text.replacingOccurrences(of: "：", with: ":")

    guard let rawName = extractField(named: "**零件名稱**:", in: normalizedText),
          !rawName.isEmpty,
          rawName != "N/A" else {
        print("解析失敗：找不到有效的零件名稱。原始資料：\(text)")
        return nil
    }

    let rawSpec = extractField(named: "**規格**:", in: normalizedText) ?? ""
    let rawFunction = extractField(named: "**主要功能**:", in: normalizedText) ?? ""

    let finalSpec = rawSpec == "N/A" ? "" : rawSpec
    let finalFunction = (rawFunction.isEmpty || rawFunction == "N/A") ? "N/A" : rawFunction

    print("解析成功：Name: '\(rawName)', Spec: '\(finalSpec)', Function: '\(finalFunction)'")
    return (rawName, finalSpec, finalFunction)
}

private func extractField(named prefix: String, in text: String) -> String? {
    guard let range = text.range(of: prefix) else { return nil }
    let start = range.upperBound
    let substring = text[start...]
    let end = substring.firstIndex(of: "\n") ?? text.endIndex
    let value = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}
