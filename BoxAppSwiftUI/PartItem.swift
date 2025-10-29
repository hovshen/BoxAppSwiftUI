import Foundation

struct PartItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var spec: String
    var quantity: Int
    var function: String // <-- 新增：功能描述

    // 更新初始化器
    init(id: UUID = UUID(), name: String, spec: String, quantity: Int, function: String = "N/A") { // <-- 加入 function，給予預設值
        self.id = id
        self.name = name
        self.spec = spec
        self.quantity = quantity
        self.function = function // <-- 設定 function
    }
}
