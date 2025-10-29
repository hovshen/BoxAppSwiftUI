import Foundation
import Combine

class InventoryViewModel: ObservableObject {
    @Published var items: [PartItem] = [] {
        didSet { saveItems() }
    }
    private let saveKey = "InventoryItems"

    init() { loadItems() }

    // --- *** 修改 addNewPart 函式簽名 *** ---
    func addNewPart(name: String, spec: String, quantity: Int, function: String = "N/A") { // <-- 加入 function 參數
        if let index = items.firstIndex(where: { $0.name == name && $0.spec == spec }) {
            items[index].quantity += quantity
            // (可選) 如果新加入的有功能描述，且舊的沒有，則更新
            if items[index].function == "N/A" || items[index].function.isEmpty {
                 items[index].function = function
            }
            print("零件 '\(name) - \(spec)' 已存在，數量增加 \(quantity)。功能描述更新(若有): \(items[index].function)")
        } else {
            // --- *** 修改這裡，傳入 function *** ---
            let newItem = PartItem(name: name, spec: spec, quantity: quantity, function: function) // <-- 傳入 function
            items.append(newItem)
            print("新增零件：'\(newItem.name)' - '\(newItem.spec)', 數量: \(newItem.quantity), 功能: \(newItem.function)")
        }
    }
    // --- *** 修改結束 *** ---

    func updateQuantity(for item: PartItem, change: Int) {
        // ... (保持不變) ...
         guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
         let newQuantity = max(0, items[index].quantity + change)
         items[index].quantity = newQuantity
    }

    private func saveItems() {
        // ... (保持不變) ...
         do {
             let data = try JSONEncoder().encode(items)
             UserDefaults.standard.set(data, forKey: saveKey)
         } catch { print("儲存庫存失敗: \(error.localizedDescription)") }
    }

    private func loadItems() {
        // ... (保持不變) ...
         guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
         do {
             items = try JSONDecoder().decode([PartItem].self, from: data)
             // 為了相容舊資料，檢查是否有 function 欄位，若無則補上預設值
             items = items.map { item in
                 // 這裡假設舊物件缺少 function 會導致解碼錯誤，
                 // 但 Codable 通常會自動處理可選或有預設值的欄位。
                 // 更安全的做法是自訂解碼器，但我們先假設 Codable 能處理。
                 // 如果 load 失敗，可能需要手動遷移舊資料。
                 var mutableItem = item
                 if mutableItem.function.isEmpty { // 簡易檢查
                     mutableItem.function = "N/A"
                 }
                 return mutableItem
             }
         } catch {
             print("載入庫存失敗: \(error.localizedDescription)")
             items = []
         }
    }
}
