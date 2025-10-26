import SwiftUI

struct LaunchAnimationView: View {
    // 動畫狀態
    @State private var scale = 0.7
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            // 背景色 (你可以改成你想要的顏色)
            // 這裡使用 UIColor.systemBackground，它會自動適應深色/淺色模式
            Color(UIColor.systemBackground)
                .ignoresSafeArea() // 填滿整個螢幕
            
            // 使用你 Assets 中的 "Image" 圖片
            Image("Image")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250) // 調整到你喜歡的大小
                .scaleEffect(scale) // 應用縮放
                .opacity(opacity)   // 應用透明度
        }
        .onAppear {
            // 當 View 出現時，立即執行動畫
            // 1.5 秒內，將 scale 放大到 1.0，透明度變為 1.0
            withAnimation(.easeInOut(duration: 1.5)) {
                self.scale = 1.0
                self.opacity = 1.0
            }
        }
    }
}

#Preview {
    LaunchAnimationView()
}
