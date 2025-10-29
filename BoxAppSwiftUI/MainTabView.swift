import SwiftUI

// --- *** 新增：定義 Tab 的列舉 *** ---
enum Tab {
    case partsBox, recognition, inventory
}
// --- *** 新增結束 *** ---

struct MainTabView: View {

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var inventoryViewModel = InventoryViewModel()
    // --- *** 新增：用於 TabView selection 的狀態 *** ---
    @State private var selectedTab: Tab = .partsBox // 預設選中第一個 Tab

    var body: some View {
        // --- *** 修改：加入 selection 綁定 *** ---
        TabView(selection: $selectedTab) {
            // Tab 1：零件盒
            PartsBoxView()
                .tabItem { Label("零件盒", systemImage: "tray.full") }
                .tag(Tab.partsBox) // <-- *** 加入 Tag ***

            // Tab 2：零件辨識
            RecognitionView(manager: cameraManager)
                .environmentObject(inventoryViewModel)
                .tabItem { Label("零件辨識", systemImage: "camera.viewfinder") }
                .tag(Tab.recognition) // <-- *** 加入 Tag ***

            // Tab 3：我的庫存
            // --- *** 修改：傳入 selectedTab 綁定 *** ---
            InventoryView(selectedTab: $selectedTab) // <-- *** 傳入綁定 ***
                .environmentObject(inventoryViewModel)
                .tabItem { Label("我的庫存", systemImage: "archivebox.fill") }
                .tag(Tab.inventory) // <-- *** 加入 Tag ***
            // --- *** 修改結束 *** ---
        }
    }
}

#Preview {
    MainTabView()
}
