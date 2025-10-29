import SwiftUI

struct RecognitionView: View {

    @ObservedObject var manager: CameraManager
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var showSaveSheet = false
    @State private var recognizedName = ""
    @State private var recognizedSpec = ""
    @State private var recognizedFunction = ""


    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                CameraPreviewView(manager: manager, currentZoomFactor: $currentZoomFactor)
                    .frame(height: 400)
                    .clipped()

                // --- 疊加按鈕邏輯 ---
                if manager.isLoading {
                    ProgressView().scaleEffect(2)
                } else if !manager.isSessionRunning { // <-- 確認無 $
                    Button(action: {
                        manager.startSession()
                        manager.resultText = "將電子零件放置於下方框內，然後點擊「辨識零件」按鈕。"
                    }) {
                        Image(systemName: manager.resultText.count > 50 ? "arrow.clockwise.circle.fill" : "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 5)
                    }
                }
                // --- 疊加按鈕邏輯結束 ---
            } // End of ZStack

            ScrollView {
                Text(manager.resultText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()

             // --- 條件式底部按鈕 ---
             if manager.isSessionRunning && !manager.isLoading { // <-- 確認無 $
                 Button("辨識零件") {
                     manager.capturePhoto()
                 }
                 .buttonStyle(.borderedProminent).tint(.blue)
                 .padding([.horizontal, .bottom])
                 .background(GeometryReader { geometry in
                     // *** 確認呼叫 ButtonDefaults.capturePadding ***
                     ButtonDefaults.capturePadding(height: geometry.size.height)
                 })

             } else if !manager.isLoading && !manager.resultText.isEmpty && manager.resultText.count > 50 { // <-- 確認無 $
                 Button("儲存至我的庫存") {
                     if let parsed = parsePartResult(from: manager.resultText) {
                         recognizedName = parsed.name
                         recognizedSpec = parsed.spec
                         recognizedFunction = parsed.function
                         showSaveSheet = true
                     } else {
                         manager.errorAlert = ErrorAlert(title: "解析失敗", message: "無法從辨識結果中提取有效的零件名稱和規格。")
                     }
                 }
                 .buttonStyle(.borderedProminent).tint(.green)
                 .padding([.horizontal, .bottom])
                 .background(GeometryReader { geometry in
                      // *** 確認呼叫 ButtonDefaults.capturePadding ***
                     ButtonDefaults.capturePadding(height: geometry.size.height)
                 })

             } else {
                 Spacer()
                     .frame(height: ButtonDefaults.capturedHeight ?? ButtonDefaults.minHeight)
                     .padding([.horizontal, .bottom])
             }
             // --- 條件式底部按鈕結束 ---

        } // End of VStack
        .navigationTitle("零件辨識")
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            // 維持高耗能模式
             manager.startSession()
        }
        .onDisappear {
            manager.stopSession()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .active && (newPhase == .inactive || newPhase == .background) {
                 manager.stopSession()
            } else if newPhase == .active && !manager.isSessionRunning { // <-- 確認無 $
                // 維持高耗能模式
                 manager.startSession()
            }
        }
        // --- *** 修正 .alert 閉包 *** ---
        .alert(item: $manager.errorAlert) { alertInfo in // <-- 確保有 'alertInfo in'
             // 確保閉包直接回傳 Alert 物件
             Alert(
                 title: Text(alertInfo.title),
                 message: Text(alertInfo.message),
                 dismissButton: .default(Text("好"))
             )
        } // --- *** 修正結束 *** ---
         .sheet(isPresented: $showSaveSheet) {
             SavePartSheetView(name: recognizedName, spec: recognizedSpec, function: recognizedFunction) { name, spec, quantity, function in
                 inventoryViewModel.addNewPart(name: name, spec: spec, quantity: quantity, function: function)
             }
         }
    } // End of body
} // End of struct RecognitionView

// --- *** 確保 ButtonDefaults 結構完整存在 *** ---
private struct ButtonDefaults {
    fileprivate static var capturedHeight: CGFloat? = nil
    static let minHeight: CGFloat = 44

    // 這個函式必須存在
    static func capturePadding(height: CGFloat) -> some View {
        DispatchQueue.main.async {
            if capturedHeight == nil || capturedHeight != height {
               capturedHeight = height
            }
        }
        return EmptyView()
    }
}
// --- *** 結構結束 *** ---


#Preview {
    RecognitionView(manager: CameraManager())
        .environmentObject(InventoryViewModel())
}

// 字串解析函式 (如果定義在這裡，確保只有一份)
// func parsePartResult(from text: String) -> (name: String, spec: String, function: String)? { ... }
