import SwiftUI
import Combine

struct InventoryAIScanInlineView: View {
    @ObservedObject var manager: CameraManager
    var onClose: () -> Void
    var onOpenAddSheet: (InventoryDraft) -> Void

    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var nameInput: String = ""
    @State private var specInput: String = ""
    @State private var functionInput: String = ""
    @State private var quantityInput: Int = 1
    @State private var latestParsedSummary: (name: String, spec: String, function: String)? = nil

    private var trimmedName: String { nameInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSpec: String { specInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedFunction: String { functionInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            cameraPreview

            controlButtons

            recognitionSummary

            if shouldShowRawText {
                rawTextSection
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("可先調整要加入的資料：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("零件名稱*", text: $nameInput)
                    .textFieldStyle(.roundedBorder)

                TextField("規格", text: $specInput)
                    .textFieldStyle(.roundedBorder)

                TextField("功能描述", text: $functionInput)
                    .textFieldStyle(.roundedBorder)

                Stepper(value: $quantityInput, in: 1...Int.max) {
                    Text("數量：\(quantityInput)")
                        .font(.body)
                }
            }

            Button {
                let draft = InventoryDraft(
                    name: trimmedName,
                    spec: trimmedSpec,
                    function: trimmedFunction,
                    quantity: quantityInput
                )
                onOpenAddSheet(draft)
            } label: {
                Label("開啟加入視窗", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedName.isEmpty)

            Button(role: .cancel) {
                endScanning()
                onClose()
            } label: {
                Label("關閉 AI 掃描", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .onAppear {
            resetInputs()
            manager.startSession()
        }
        .onDisappear {
            manager.stopSession()
        }
        .onReceive(manager.$resultText.removeDuplicates()) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard trimmed != CameraManager.defaultResultText else { return }

            if let parsed = parsePartResult(from: trimmed) {
                latestParsedSummary = parsed
                nameInput = parsed.name
                specInput = parsed.spec
                functionInput = parsed.function == "N/A" ? "" : parsed.function
            } else {
                latestParsedSummary = nil
            }
        }
        .alert(item: $manager.errorAlert) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var shouldShowRawText: Bool {
        let trimmed = manager.resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != CameraManager.defaultResultText
    }

    private var header: some View {
        HStack {
            Label("AI 掃描輸入", systemImage: "sparkles.viewfinder")
                .font(.headline)
            Spacer()
        }
    }

    private var cameraPreview: some View {
        ZStack {
            CameraPreviewView(manager: manager, currentZoomFactor: $currentZoomFactor)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            if manager.isLoading {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else if !manager.isSessionRunning {
                Color.black.opacity(0.45)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var controlButtons: some View {
        HStack {
            Button {
                manager.capturePhoto()
            } label: {
                Label("辨識零件", systemImage: "sparkles.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!manager.isSessionRunning || manager.isLoading)

            Button {
                resetInputs()
            } label: {
                Label("清除", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var recognitionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = latestParsedSummary {
                Text("辨識摘要")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(title: "名稱", value: summary.name)
                    summaryRow(title: "規格", value: summary.spec)
                    if summary.function != "N/A" {
                        summaryRow(title: "功能", value: summary.function)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            } else {
                Text("尚未擷取到可用的欄位，您可以直接輸入或再次掃描。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("辨識原文")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ScrollView {
                Text(manager.resultText)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetInputs() {
        currentZoomFactor = 1.0
        nameInput = ""
        specInput = ""
        functionInput = ""
        quantityInput = 1
        latestParsedSummary = nil
        manager.resetScanState()
    }

    private func endScanning() {
        manager.stopSession()
        manager.resetScanState()
    }
}

#Preview {
    InventoryAIScanInlineView(
        manager: CameraManager(),
        onClose: {},
        onOpenAddSheet: { _ in }
    )
}
