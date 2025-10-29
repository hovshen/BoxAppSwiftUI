import SwiftUI

struct SavePartSheetView: View {
    @Environment(\.dismiss) var dismiss
    // 不再需要 ViewModel，因為儲存操作由 RecognitionView 處理

    // 傳入的辨識結果
    let initialName: String
    let initialSpec: String
    let initialFunction: String // <-- 新增：接收解析出的功能
    let onSave: (String, String, Int, String) -> Void // <-- 修改回呼函式簽名

    // 用於編輯的狀態變數
    @State private var name: String
    @State private var spec: String
    @State private var quantity: Int
    @State private var function: String // <-- 新增狀態

    // 表單驗證
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0
    }

     // 初始化器，用於將傳入值設定給 @State 變數
     init(name: String, spec: String, function: String, initialQuantity: Int = 1, onSave: @escaping (String, String, Int, String) -> Void) {
         self.initialName = name
         self.initialSpec = spec
         self.initialFunction = function
         self.onSave = onSave
         // 將傳入值設定為 @State 變數的初始值
         _name = State(initialValue: name)
         _spec = State(initialValue: spec)
         _function = State(initialValue: function)
         _quantity = State(initialValue: max(1, initialQuantity))
     }


    var body: some View {
        NavigationView {
            Form {
                Section("辨識結果 (可編輯)") {
                    TextField("零件名稱*", text: $name)
                    TextField("規格", text: $spec)
                    TextField("功能", text: $function) // <-- 新增：功能輸入框
                }
                Section("庫存數量") {
                     Stepper("數量: \(quantity)", value: $quantity, in: 1...Int.max)
                }
            }
            .navigationTitle("新增庫存項目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        // 使用 @State 中的值呼叫回呼
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            spec.trimmingCharacters(in: .whitespaces),
                            quantity,
                            function.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : function.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
}

// Preview
struct SavePartSheetView_Previews: PreviewProvider {
    static var previews: some View {
        SavePartSheetView(name: "預覽電阻", spec: "1KΩ ±5%", function: "限流", onSave: { name, spec, quantity, function in
            print("預覽：儲存 \(name), \(spec), \(quantity), \(function)")
        })
    }
}
