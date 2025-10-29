import Combine
import Foundation

final class AIScanFormState: ObservableObject {
    @Published var nameInput: String = ""
    @Published var specInput: String = ""
    @Published var functionInput: String = ""
    @Published var quantityInput: Int = 1
    @Published var quantityText: String = "1"
    @Published var latestSummary: PartRecognitionSummary?

    var trimmedName: String { nameInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSpec: String { specInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedFunction: String { functionInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    func makeDraft() -> InventoryDraft {
        InventoryDraft(
            name: trimmedName,
            spec: trimmedSpec,
            function: trimmedFunction,
            quantity: quantityInput
        )
    }

    func updateQuantityText(for newValue: Int) {
        let newText = String(newValue)
        if quantityText != newText {
            quantityText = newText
        }
    }

    func updateQuantityInput(for newText: String) {
        let filtered = newText.filter { $0.isNumber }
        guard filtered == newText else {
            quantityText = filtered
            return
        }

        guard let value = Int(filtered), value > 0 else {
            quantityText = String(max(1, quantityInput))
            return
        }

        if quantityInput != value {
            quantityInput = value
        }
    }

    func applyRecognitionResult(_ summary: PartRecognitionSummary?) {
        latestSummary = summary
        guard let summary else { return }

        nameInput = summary.name
        if !summary.spec.isEmpty {
            specInput = summary.spec
        }
        if summary.function != "N/A" {
            functionInput = summary.function
        }
    }

    func reset() {
        nameInput = ""
        specInput = ""
        functionInput = ""
        quantityInput = 1
        quantityText = "1"
        latestSummary = nil
    }
}
