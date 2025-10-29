import SwiftUI

struct RecognitionView: View {
    @ObservedObject var manager: CameraManager
    var showsCloseButton: Bool = false

    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var showSaveSheet = false
    @State private var recognitionSummary: PartRecognitionSummary?

    var body: some View {
        VStack(spacing: 0) {
            cameraSection

            ScrollView {
                Text(manager.resultText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()

            actionSection
        }
        .navigationTitle("零件辨識")
        .toolbar { closeButton }
        .ignoresSafeArea(.all, edges: .top)
        .onAppear(perform: startRecognitionSession)
        .onDisappear(perform: stopRecognitionSession)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
        .alert(item: $manager.errorAlert, content: makeErrorAlert)
        .sheet(isPresented: $showSaveSheet, content: presentSaveSheet)
    }

    private var cameraSection: some View {
        ZStack {
            CameraPreviewView(manager: manager, currentZoomFactor: $currentZoomFactor)
                .frame(height: 400)
                .clipped()

            if manager.isLoading {
                ProgressView().scaleEffect(2)
            } else if !manager.isSessionRunning {
                Button(action: restartSession) {
                    Image(systemName: manager.resultText.count > 50 ? "arrow.clockwise.circle.fill" : "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(radius: 5)
                }
            }
        }
    }

    private var parsedSummary: PartRecognitionSummary? {
        parsePartResult(from: manager.resultText)
    }

    @ViewBuilder
    private var actionSection: some View {
        if manager.isSessionRunning && !manager.isLoading {
            Button("辨識零件", action: manager.capturePhoto)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding([.horizontal, .bottom])
                .background(capturePaddingOverlay)
        } else if let summary = parsedSummary, !manager.isLoading {
            Button("儲存至我的庫存") {
                recognitionSummary = summary
                showSaveSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding([.horizontal, .bottom])
            .background(capturePaddingOverlay)
        } else {
            Spacer()
                .frame(height: ButtonDefaults.capturedHeight ?? ButtonDefaults.minHeight)
                .padding([.horizontal, .bottom])
        }
    }

    private var capturePaddingOverlay: some View {
        GeometryReader { geometry in
            ButtonDefaults.capturePadding(height: geometry.size.height)
        }
    }

    @ToolbarContentBuilder
    private var closeButton: some ToolbarContent {
        if showsCloseButton {
            ToolbarItem(placement: .cancellationAction) {
                Button("關閉", action: dismiss.callAsFunction)
            }
        }
    }

    private func startRecognitionSession() {
        manager.resetScanState()
        manager.startSession()
    }

    private func stopRecognitionSession() {
        manager.stopSession()
    }

    private func restartSession() {
        manager.startSession()
        manager.resetScanState()
    }

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        if oldPhase == .active && (newPhase == .inactive || newPhase == .background) {
            manager.stopSession()
        } else if newPhase == .active && !manager.isSessionRunning {
            manager.startSession()
        }
    }

    private func makeErrorAlert(from alertInfo: ErrorAlert) -> Alert {
        Alert(
            title: Text(alertInfo.title),
            message: Text(alertInfo.message),
            dismissButton: .default(Text("好"))
        )
    }

    private func presentSaveSheet() -> some View {
        let summary = recognitionSummary ?? PartRecognitionSummary(name: "", spec: "", function: "")
        return SavePartSheetView(
            name: summary.name,
            spec: summary.spec,
            function: summary.function
        ) { name, spec, quantity, function in
            inventoryViewModel.addNewPart(name: name, spec: spec, quantity: quantity, function: function)
        }
    }
}

private struct ButtonDefaults {
    fileprivate static var capturedHeight: CGFloat? = nil
    static let minHeight: CGFloat = 44

    static func capturePadding(height: CGFloat) -> some View {
        DispatchQueue.main.async {
            if capturedHeight != height {
                capturedHeight = height
            }
        }
        return EmptyView()
    }
}

#Preview {
    RecognitionView(manager: CameraManager())
        .environmentObject(InventoryViewModel())
}
