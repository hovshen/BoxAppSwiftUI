import SwiftUI
import Combine

struct InventoryAIScanSheetView: View {
    @ObservedObject var manager: CameraManager
    @EnvironmentObject private var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var name: String = ""
    @State private var spec: String = ""
    @State private var quantity: Int = 1
    @State private var function: String = ""

    @State private var latestParsedResult: (name: String, spec: String, function: String)? = nil

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    cameraPreview
                    captureControls
                } footer: {
                    Text("對準零件並點擊「辨識零件」。必要欄位可在下方自行編輯。")
                }

                if !manager.resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("AI 辨識內容") {
                        Text(manager.resultText)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    }
                }

                if let parsed = latestParsedResult {
                    Section {
                        Button {
                            applyParsedValues(parsed, overrideExisting: true)
                        } label: {
                            Label("套用辨識資料", systemImage: "sparkles")
                        }
                    } footer: {
                        Text("已從辨識結果擷取欄位，點擊按鈕可覆寫目前輸入。")
                    }
                }

                Section("零件資訊") {
                    TextField("零件名稱*", text: $name)
                    TextField("規格", text: $spec)
                    Stepper("數量: \(quantity)", value: $quantity, in: 1...Int.max)
                    TextField("功能描述", text: $function)
                }
            }
            .navigationTitle("AI 掃描輸入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入庫存") {
                        saveCurrentPart()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            resetState()
            manager.startSession()
        }
        .onDisappear {
            manager.stopSession()
        }
        .onReceive(manager.$resultText.removeDuplicates()) { newValue in
            guard newValue != CameraManager.defaultResultText else { return }
            guard newValue.contains("零件名稱") else { return }
            guard let parsed = parsePartResult(from: newValue) else { return }
            latestParsedResult = parsed
            applyParsedValues(parsed, overrideExisting: false)
        }
        .alert(item: $manager.errorAlert) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var cameraPreview: some View {
        ZStack {
            CameraPreviewView(manager: manager, currentZoomFactor: $currentZoomFactor)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            if manager.isLoading {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else if !manager.isSessionRunning {
                Color.black.opacity(0.45)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button {
                    manager.startSession()
                } label: {
                    Label("啟動相機", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
    }

    private var captureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                manager.capturePhoto()
            } label: {
                Label("辨識零件", systemImage: "sparkles.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!manager.isSessionRunning || manager.isLoading)

            Button(role: .cancel) {
                manager.resetScanState()
                latestParsedResult = nil
            } label: {
                Label("清除辨識結果", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(manager.resultText == CameraManager.defaultResultText && latestParsedResult == nil)
        }
    }

    private func resetState() {
        currentZoomFactor = 1.0
        latestParsedResult = nil
        name = ""
        spec = ""
        function = ""
        quantity = 1
        manager.resetScanState()
    }

    private func applyParsedValues(_ parsed: (name: String, spec: String, function: String), overrideExisting: Bool) {
        if overrideExisting || name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = parsed.name
        }
        if overrideExisting || spec.trimmingCharacters(in: .whitespaces).isEmpty {
            spec = parsed.spec
        }
        let parsedFunction = parsed.function == "N/A" ? "" : parsed.function
        if overrideExisting || function.trimmingCharacters(in: .whitespaces).isEmpty {
            function = parsedFunction
        }
    }

    private func saveCurrentPart() {
        viewModel.addNewPart(
            name: name.trimmingCharacters(in: .whitespaces),
            spec: spec.trimmingCharacters(in: .whitespaces),
            quantity: quantity,
            function: function.trimmingCharacters(in: .whitespaces).isEmpty ? "N/A" : function.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }
}

#Preview {
    InventoryAIScanSheetView(manager: CameraManager())
        .environmentObject(InventoryViewModel())
}
