import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var viewModel: InventoryViewModel
    @Binding var selectedTab: Tab
    @State private var showingAddSheet = false
    @State private var showingAISheet = false
    @StateObject private var aiCameraManager = CameraManager()

    var body: some View {
        NavigationView {
            List {
                if viewModel.items.isEmpty {
                    InventoryEmptyStateView(action: { showingAddSheet = true })
                        .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(viewModel.items) { item in
                            NavigationLink(destination: PartDetailView(itemId: item.id)) {
                                InventoryRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的庫存")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("手動輸入", systemImage: "pencil.line")
                        }
                        Button {
                            aiCameraManager.resetScanState()
                            showingAISheet = true
                        } label: {
                            Label("AI 掃描輸入", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ManualAddPartView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingAISheet) {
                InventoryAIScanSheetView(manager: aiCameraManager)
                    .environmentObject(viewModel)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        viewModel.items.remove(atOffsets: offsets)
    }
}

private struct InventoryRowView: View {
    let item: PartItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.headline)
            Text("數量：\(item.quantity)")
                .font(.subheadline)
            if !item.spec.isEmpty {
                Text("規格：\(item.spec)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            if !item.function.isEmpty && item.function != "N/A" {
                Text("功能：\(item.function)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct InventoryEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("您的庫存目前是空的")
                .font(.headline)
            Text("點擊右上角的新增按鈕可手動輸入，或使用 AI 掃描輔助填寫資料。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Label("新增庫存項目", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        let previewViewModel = InventoryViewModel()
        previewViewModel.addNewPart(name: "電阻", spec: "1KΩ ±5%", quantity: 10, function: "限流")
        previewViewModel.addNewPart(name: "電晶體", spec: "BC547", quantity: 5, function: "NPN 放大/開關")

        return InventoryView(selectedTab: .constant(.inventory))
            .environmentObject(previewViewModel)
    }
}
