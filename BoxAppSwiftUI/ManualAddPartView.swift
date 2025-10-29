// In ManualAddPartView.swift

import SwiftUI

struct ManualAddPartView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: InventoryViewModel

    // 用於綁定輸入框的狀態變數
    @State private var name: String
    @State private var spec: String
    @State private var quantity: Int
    @State private var function: String

    // --- 新增：自訂初始化器 ---
    // 允許傳入初始值。如果沒有傳，就使用預設值（空白）
    init(initialName: String = "", initialSpec: String = "", initialFunction: String = "N/A", initialQuantity: Int = 1) {
        _name = State(initialValue: initialName)
        _spec = State(initialValue: initialSpec)
        _function = State(initialValue: initialFunction)
        _quantity = State(initialValue: initialQuantity)
    }
    // --- 新增結束 ---

    // 用於控制表單驗證
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0
    }

    var body: some View {
        NavigationView {
            Form {
                // 表單內容完全不需要改變
                TextField("零件名稱*", text: $name)
                TextField("規格", text: $spec)
                Stepper("數量: \(quantity)", value: $quantity, in: 1...Int.max)
                TextField("功能描述", text: $function) // "可選" 可以寫在 Section 標題
            }
            .navigationTitle("新增/編輯零件") // 標題改得更通用
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        viewModel.addNewPart(
                            name: name.trimmingCharacters(in: .whitespaces),
                            spec: spec.trimmingCharacters(in: .whitespaces),
                            quantity: quantity,
                            function: function.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : function.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
}

// Preview 也可以更新
struct ManualAddPartView_Previews: PreviewProvider {
    static var previews: some View {
        // 預覽1: 手動新增 (空白)
        ManualAddPartView()
            .environmentObject(InventoryViewModel())

        // 預覽2: 辨識後傳入 (帶有初始值)
        ManualAddPartView(
            initialName: "辨識出的電阻",
            initialSpec: "100KΩ",
            initialFunction: "限流"
        )
        .environmentObject(InventoryViewModel())
    }
}
