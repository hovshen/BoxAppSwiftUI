import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var viewModel: InventoryViewModel
    @Binding var selectedTab: Tab // <-- *** 接收 selectedTab 綁定 ***
    @State private var showingAddSheet = false // 控制手動新增表單

    var body: some View {
        NavigationView {
            List {
                if viewModel.items.isEmpty {
                    Text("您的庫存目前是空的。\n請點擊右上角的 '+' 新增零件，\n或前往「零件辨識」分頁掃描。")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(viewModel.items) { item in
                        NavigationLink(destination: PartDetailView(itemId: item.id)) {
                            // --- *** 修改列表顯示格式 *** ---
                            VStack(alignment: .leading, spacing: 5) {
                                Text("1. 零件名稱: \(item.name)").font(.headline)
                                Text("2. 數量: \(item.quantity)")
                                Text("3. 規格: \(item.spec)").font(.subheadline).foregroundColor(.gray)
                                Text("4. 功能: \(item.function)").font(.caption).foregroundColor(.secondary) // 使用小字體顯示功能
                            }
                            .padding(.vertical, 5) // 增加垂直間距
                            // --- *** 修改結束 *** ---
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("我的庫存")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton() // 保留編輯按鈕用於刪除
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                     // --- *** 新增 "+" 按鈕 *** ---
                     Menu { // 使用 Menu 提供選項
                         Button {
                             showingAddSheet = true // 打開手動輸入表單
                         } label: {
                             Label("手動輸入", systemImage: "pencil.line")
                         }
                         Button {
                             selectedTab = .recognition // 切換到辨識分頁
                         } label: {
                             Label("AI 掃描輸入", systemImage: "camera.viewfinder")
                         }
                     } label: {
                         Image(systemName: "plus.circle.fill") // 使用 + 圖示
                     }
                     // --- *** 新增結束 *** ---
                 }
            }
             // --- *** 加入 .sheet 修飾符 *** ---
             .sheet(isPresented: $showingAddSheet) {
                 ManualAddPartView()
                     // ManualAddPartView 也需要 ViewModel 來儲存
                     .environmentObject(viewModel)
             }
             // --- *** 加入結束 *** ---
        }
    }

     func deleteItems(at offsets: IndexSet) {
         // ... (保持不變) ...
         viewModel.items.remove(atOffsets: offsets)
     }
}

// Preview
struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        // 建立假的 ViewModel
        let previewViewModel = InventoryViewModel()
        previewViewModel.addNewPart(name: "電阻", spec: "1KΩ ±5%", quantity: 10, function: "限流")
        previewViewModel.addNewPart(name: "電晶體", spec: "BC547", quantity: 5, function: "NPN 放大/開關")

        // 預覽需要一個 @State 綁定，我們用 .constant 創建一個假的
        return InventoryView(selectedTab: .constant(.inventory))
            .environmentObject(previewViewModel)
    }
}
