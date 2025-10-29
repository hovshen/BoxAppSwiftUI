import Foundation
import AVFoundation
import UIKit // 需要 UIKit 來取得 Base64 影像
import Combine

// 繼承 NSObject 以便遵從 AVCapturePhotoCaptureDelegate
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {

    static let defaultResultText = "將電子零件放置於下方框內，然後點擊「辨識零件」按鈕。"
    static let processingResultText = "辨識中，請稍候..."

    // MARK: - AVFoundation 屬性
    @Published var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    @Published var previewLayer: AVCaptureVideoPreviewLayer!
    @Published var device: AVCaptureDevice? // 用於縮放

    // MARK: - Gemini API 屬性
    private let apiClient: GeminiAPIClient?
    private let apiSetupErrorMessage: String?

    // MARK: - @Published 狀態 (用於驅動 SwiftUI 更新)
    @Published var isLoading: Bool = false
    @Published var resultText: String = CameraManager.defaultResultText
    @Published var errorAlert: ErrorAlert? // 用於彈出式錯誤
    // --- *** 新增：加入 isSessionRunning 狀態 *** ---
    @Published var isSessionRunning: Bool = false // 追蹤相機預覽是否運作
    // --- *** 新增結束 *** ---


    // MARK: - 初始化
    override init() {
        let clientResult = Result { try GeminiAPIClient.makeDefault() }
        switch clientResult {
        case .success(let client):
            apiClient = client
            apiSetupErrorMessage = nil
        case .failure(let error):
            apiClient = nil
            if let geminiError = error as? GeminiAPIError {
                apiSetupErrorMessage = geminiError.errorDescription
            } else {
                apiSetupErrorMessage = error.localizedDescription
            }
        }

        super.init()
        setupCamera()
        if let message = apiSetupErrorMessage {
            errorAlert = ErrorAlert(title: "設定錯誤", message: message)
        }
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
            self.resultText = CameraManager.processingResultText
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
        guard let apiClient else {
            DispatchQueue.main.async {
                self.isLoading = false
                let message = self.apiSetupErrorMessage ?? "Gemini API 尚未正確初始化。"
                self.errorAlert = ErrorAlert(title: "設定錯誤", message: message)
            }
            return
        }

        let request: URLRequest
        do {
            request = try apiClient.makeRequest(base64Image: base64Image)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                let message = (error as? GeminiAPIError)?.errorDescription ?? error.localizedDescription
                self.errorAlert = ErrorAlert(title: "API 請求建立失敗", message: message)
            }
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(title: "API 請求失敗", message: error.localizedDescription)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(title: "API 錯誤", message: "未收到 API 回應資料。")
                }
                return
            }

            do {
                let text = try apiClient.parseResponse(data: data)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.resultText = text
                }
            } catch {
                let message = (error as? GeminiAPIError)?.errorDescription ?? error.localizedDescription
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorAlert = ErrorAlert(title: "API 回應解析錯誤", message: message)
                }
            }
        }
        task.resume()
    }

}

func parsePartResult(from text: String) -> PartRecognitionSummary? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let placeholders: Set<String> = [
        CameraManager.defaultResultText,
        CameraManager.processingResultText
    ]

    if placeholders.contains(trimmed) || trimmed.hasPrefix("模擬模式：") {
        return nil
    }

    let normalizedText = trimmed.replacingOccurrences(of: "：", with: ":")

    guard let rawName = extractField(named: "**零件名稱**:", in: normalizedText),
          !rawName.isEmpty,
          rawName != "N/A" else {
        print("解析失敗：找不到有效的零件名稱。原始資料：\(trimmed)")
        return nil
    }

    let rawSpec = extractField(named: "**規格**:", in: normalizedText) ?? ""
    let rawFunction = extractField(named: "**主要功能**:", in: normalizedText) ?? ""

    let finalSpec = rawSpec == "N/A" ? "" : rawSpec
    let finalFunction = (rawFunction.isEmpty || rawFunction == "N/A") ? "N/A" : rawFunction

    print("解析成功：Name: '\(rawName)', Spec: '\(finalSpec)', Function: '\(finalFunction)'")
    return PartRecognitionSummary(name: rawName, spec: finalSpec, function: finalFunction)
}

private func extractField(named prefix: String, in text: String) -> String? {
    guard let range = text.range(of: prefix) else { return nil }
    let start = range.upperBound
    let substring = text[start...]
    let end = substring.firstIndex(of: "\n") ?? text.endIndex
    let value = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}
