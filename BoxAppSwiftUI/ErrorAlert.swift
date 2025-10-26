import Foundation

/// 一個可用於 SwiftUI Alert 的、可識別的錯誤物件
struct ErrorAlert: Identifiable {
    /// 讓 SwiftUI 知道每個 Alert 都是獨一無二的
    let id = UUID()
    /// Alert 的標題
    var title: String = "錯誤"
    /// Alert 的詳細訊息
    var message: String
}
