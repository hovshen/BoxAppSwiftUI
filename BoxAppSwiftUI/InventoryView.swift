import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var viewModel: InventoryViewModel
    @Binding var selectedTab: Tab

    @State private var showingAIScanner = false
    @State private var presentedSheet: InventorySheet?

    @StateObject private var aiCameraManager = CameraManager()

    var body: some View {
        NavigationStack {
            listContent
                .animation(.easeInOut, value: showingAIScanner)
                .listStyle(.insetGrouped)
                .navigationTitle("我的庫存")
                .toolbar { toolbarContent }
                .sheet(item: $presentedSheet) { destination in
                    destinationView(for: destination)
                }
        }
        .onChange(of: presentedSheet) { newValue in
            guard showingAIScanner else { return }
            if newValue == nil {
                aiCameraManager.startSession()
            }
        }
    }

    private func toggleAIScanner() {
        if showingAIScanner {
            closeAIScanner()
        } else {
            aiCameraManager.resetScanState()
            withAnimation {
                showingAIScanner = true
            }
        }
    }

    private func closeAIScanner() {
        aiCameraManager.stopSession()
        aiCameraManager.resetScanState()
        withAnimation {
            showingAIScanner = false
        }
    }

    private func presentSaveDraft(_ draft: InventoryDraft) {
        aiCameraManager.stopSession()
        presentedSheet = .aiDraft(draft)
    }

    private func deleteItems(at offsets: IndexSet) {
        viewModel.items.remove(atOffsets: offsets)
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            if showingAIScanner {
                aiScannerSection
            }

            if viewModel.items.isEmpty {
                emptyStateSection
            } else {
                inventorySection
            }
        }
    }

    @ViewBuilder
    private var aiScannerSection: some View {
        Section {
            InventoryAIScanInlineView(
                manager: aiCameraManager,
                onClose: closeAIScanner,
                onOpenAddSheet: presentSaveDraft
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
    }

    @ViewBuilder
    private var emptyStateSection: some View {
        Section {
            InventoryEmptyStateView(action: openManualSheet)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
    }

    @ViewBuilder
    private var inventorySection: some View {
        Section {
            ForEach(viewModel.items) { item in
                NavigationLink(destination: PartDetailView(itemId: item.id)) {
                    InventoryRowView(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            EditButton()
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    openManualSheet()
                } label: {
                    Label("手動輸入", systemImage: "pencil.line")
                }

                Button {
                    toggleAIScanner()
                } label: {
                    Label("AI 掃描輸入", systemImage: "camera.viewfinder")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: InventorySheet) -> some View {
        switch destination {
        case .manual:
            ManualAddPartView()
                .environmentObject(viewModel)
        case .aiDraft(let draft):
            SavePartSheetView(
                name: draft.name,
                spec: draft.spec,
                function: draft.function,
                initialQuantity: draft.quantity
            ) { name, spec, quantity, function in
                viewModel.addNewPart(
                    name: name,
                    spec: spec,
                    quantity: quantity,
                    function: function
                )
            }
        }
    }

    private func openManualSheet() {
        if showingAIScanner {
            closeAIScanner()
        }
        presentedSheet = .manual
    }
}

private enum InventorySheet: Identifiable, Equatable {
    case manual
    case aiDraft(InventoryDraft)

    var id: String {
        switch self {
        case .manual:
            return "manual"
        case .aiDraft(let draft):
            return "ai-\(draft.id)"
        }
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

struct InventoryDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var spec: String
    var function: String
    var quantity: Int
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
