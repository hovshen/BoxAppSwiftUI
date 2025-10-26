import SwiftUI

@main
struct BoxAppSwiftUIApp: App {
    
    // --- 新增這一行 ---
    // 1. 建立一個狀態來追蹤動畫是否已完成
    @State private var isLaunchAnimationDone = false

    var body: some Scene {
        WindowGroup {
            
            // 2. 使用 ZStack 將主畫面和動畫疊在一起
            ZStack {
                // 你的 App 主畫面 (它會在最底層)
                MainTabView()

                // 3. 條件式地顯示動畫 (它會在最上層)
                if !isLaunchAnimationDone {
                    LaunchAnimationView()
                        .transition(.opacity) // 讓它消失時有淡出效果
                }
            }
            .onAppear {
                // 4. 設定一個計時器
                // 讓動畫 (1.5秒) + 額外顯示 (1.0秒) = 總共 2.5 秒
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    // 5. 時間到了，使用動畫來隱藏 LaunchAnimationView
                    withAnimation(.easeOut(duration: 0.5)) {
                        isLaunchAnimationDone = true
                    }
                }
            }
        }
    }
}
