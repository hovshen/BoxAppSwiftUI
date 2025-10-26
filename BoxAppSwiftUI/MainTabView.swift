import SwiftUI

struct MainTabView: View {
    
    // --- 1. 在這裡建立 CameraManager ---
    // 由於 MainTabView 始終存在，這個 manager 也會始終存在
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        TabView {
            // 第一個 Tab：零件盒 (不變)
            PartsBoxView()
                .tabItem {
                    Label("零件盒", systemImage: "tray.full")
                }
            
            // 第二個 Tab：零件辨識
            // --- 2. 將 manager "傳遞" 下去 ---
            RecognitionView(manager: cameraManager) // <-- 傳入 manager
                .tabItem {
                    Label("零件辨識", systemImage: "camera.viewfinder")
                }
        }
    }
}

#Preview {
    MainTabView()
}
