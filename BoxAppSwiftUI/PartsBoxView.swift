import SwiftUI

struct PartsBoxView: View {
    // 使用 @StateObject 建立並持有 ViewModel 實例
    @StateObject private var viewModel = BluetoothViewModel()
    
    // 用於 Picker 的狀態
    @State private var selectedCategory: String = "電阻"
    
    // --- 新增這一行 ---
    // 建立一個 @State 變數來綁定 TextField，這將是我們唯一的指令來源
    @State private var partToSend: String = ""
    
    // 根據選擇的分類顯示對應的零件 (維持不變)
    private var currentComponents: [String] {
        return viewModel.componentData[selectedCategory] ?? []
    }

    var body: some View {
        NavigationView { // 使用 NavigationView 來放置標題
            VStack(spacing: 20) {
                
                // 狀態標籤 (維持不變)
                Text(viewModel.statusMessage)
                    .font(.headline)
                    .foregroundColor(viewModel.isConnected ? .green : .gray)
                
                // 連接按鈕 (維持不變)
                Button(viewModel.isConnected ? "斷開連線" : "連接智慧零件盒") {
                    viewModel.connectButtonTapped()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(viewModel.isConnected ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                // --- 這是新的 UI 區塊 ---
                VStack(spacing: 10) {
                    // 1. 文字輸入框 (TextField)
                    // 綁定 $partToSend，使用者可以在這裡自定義型號
                    TextField("自定義型號或從下方選擇", text: $partToSend)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none) // 關閉自動大寫
                        .disableAutocorrection(true) // 關閉自動修正

                    // 2. 統一的「傳送指令」按鈕
                    Button(action: {
                        // 無論是自定義還是選擇的，都從 partToSend 發送
                        viewModel.send(command: partToSend)
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("傳送指令")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        // 當文字框是空的或藍牙未連線時，按鈕會變灰色
                        .background(partToSend.isEmpty || !viewModel.isConnected ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    // 3. 設定按鈕的禁用條件
                    .disabled(partToSend.isEmpty || !viewModel.isConnected)
                }
                // --- 新 UI 區塊結束 ---
                
                // 分段控制器 (Segmented Control)
                Picker("零件類別", selection: $selectedCategory) {
                    ForEach(viewModel.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                // (可選功能): 當切換分類時，自動清空文字框
                .onChange(of: selectedCategory) {
                    partToSend = ""
                }
                
                // 零件列表 (List) - (已修改)
                List(currentComponents, id: \.self) { component in
                    HStack {
                        // 列表項目只顯示文字
                        Text(component)
                        Spacer()
                        // (可選 UI): 如果這個項目被選中，顯示一個小圖示
                        if partToSend == component {
                            Image(systemName: "arrow.up.left.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle()) // 讓整行都可以點擊
                    .onTapGesture {
                        // --- 核心修改 ---
                        // 點擊列表項目時，不再是 "直接發送"
                        // 而是 "更新文字框的內容"
                        partToSend = component
                    }
                }
                .listStyle(.insetGrouped) // 讓列表樣式好看一點
                
            }
            .padding()
            .navigationTitle("智慧零件盒")
            // 錯誤提示窗 (維持不變)
            .alert(item: $viewModel.errorAlert) { alertInfo in
                Alert(
                    title: Text(alertInfo.title),
                    message: Text(alertInfo.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }
}

#Preview {
    PartsBoxView()
}
