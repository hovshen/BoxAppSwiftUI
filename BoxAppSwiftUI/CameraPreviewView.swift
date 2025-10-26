import SwiftUI
import AVFoundation

/// 一個自訂的 UIView，專門用來顯示 AVCaptureVideoPreviewLayer
/// 它會自動確保 previewLayer 填滿 View 的邊界
class VideoPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer
    
    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        self.layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }
}


// MARK: - SwiftUI 橋接
struct CameraPreviewView: UIViewRepresentable {
    // 綁定 CameraManager
    @ObservedObject var manager: CameraManager
    // 綁定縮放手勢
    @Binding var currentZoomFactor: CGFloat
    
    func makeUIView(context: Context) -> VideoPreviewUIView {
        
        let view = VideoPreviewUIView(previewLayer: manager.previewLayer)
        
        // --- 加入縮放手G (已存在) ---
        let pinchRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinchToZoom(_:)))
        view.addGestureRecognizer(pinchRecognizer)
        
        // ---
        // --- ↓↓↓ 這就是我們新增的「點擊手勢」 ↓↓↓
        // ---
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapToFocus(_:)))
        view.addGestureRecognizer(tapRecognizer)
        // ---
        // --- ↑↑↑ 新增手勢結束 ↑↑↑
        // ---
        
        return view
    }

    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        // 當 currentZoomFactor 改變時，呼叫 manager 的 zoom
        manager.zoom(with: currentZoomFactor)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator 負責處理來自 UIKit 的 delegate 和 target-action
    class Coordinator: NSObject {
        var parent: CameraPreviewView
        private var initialZoomFactor: CGFloat = 1.0

        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        // 處理縮放手勢 (已存在)
        @objc func handlePinchToZoom(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                initialZoomFactor = parent.manager.device?.videoZoomFactor ?? 1.0
            case .changed:
                parent.currentZoomFactor = recognizer.scale * initialZoomFactor
            default:
                break
            }
        }
        
        // ---
        // --- ↓↓↓ 這就是我們新增的「點擊處理函式」 ↓↓↓
        // ---
        @objc func handleTapToFocus(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            
            // 1. 取得點擊在 UIView 上的位置
            let tapPoint = recognizer.location(in: view)
            
            // 2. 將 UIView 的座標轉換為相機硬體需要的「標準化座標」
            let convertedPoint = parent.manager.previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
            
            // 3. 呼叫 manager 的 focus 函式
            parent.manager.focus(at: convertedPoint)
        }
        // ---
        // --- ↑↑↑ 新增函式結束 ↑↑↑
        // ---
    }
}   
