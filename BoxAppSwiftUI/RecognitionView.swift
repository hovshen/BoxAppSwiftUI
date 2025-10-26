import SwiftUI

struct RecognitionView: View {
    
    // --- 核心修改點 ---
    // 1. 將 @StateObject 改為 @ObservedObject
    //    這代表 View 正在「觀察」一個從外部傳入的物件
    @ObservedObject var manager: CameraManager
    
    // 用於手勢的狀態
    @State private var currentZoomFactor: CGFloat = 1.0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            
            // 相機預覽區域
            ZStack {
                // 這裡會使用從 MainTabView 傳入的 "同一個" manager
                CameraPreviewView(manager: manager, currentZoomFactor: $currentZoomFactor)
                    .frame(height: 400)
                    .clipped()
                
                if manager.isLoading {
                    ProgressView().scaleEffect(2)
                }
            }
            
            // 結果顯示區域
            ScrollView {
                Text(manager.resultText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()

            // 辨識按鈕
            Button("辨識零件") {
                manager.capturePhoto()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding([.horizontal, .bottom])
            .disabled(manager.isLoading)
        }
        .navigationTitle("零件辨識")
        .ignoresSafeArea(.all, edges: .top)
        
        // --- 2. 核心修改點：使用 onAppear 和 onDisappear ---
        
        // 當 View 出現 (切換到此分頁) 時，啟動相機
        .onAppear {
            manager.startSession()
        }
        // 當 View 消失 (切換到別的分頁) 時，停止相機
        .onDisappear {
            manager.stopSession()
        }
        // 處理 App 退至背景
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                manager.startSession()
            } else if oldPhase == .active && (newPhase == .inactive || newPhase == .background) {
                manager.stopSession()
            }
        }
        // 錯誤提示窗
        .alert(item: $manager.errorAlert) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                dismissButton: .default(Text("好"))
            )
        }
    }
}

#Preview {
    // --- 3. 核心修改點：修復 Preview ---
    // 傳入一個新的 CameraManager 實例，僅供預覽使用
    RecognitionView(manager: CameraManager())
}
