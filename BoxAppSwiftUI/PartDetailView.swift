import SwiftUI

struct PartDetailView: View {
    // Receive ViewModel via environment
    @EnvironmentObject var viewModel: InventoryViewModel
    // Receive the ID of the item to display
    var itemId: UUID

    // Computed property to find the latest item data from the ViewModel
    private var currentItem: PartItem? {
        viewModel.items.first(where: { $0.id == itemId })
    }

    // State for potential local edits if needed, though direct VM calls are better
    // @State private var quantity: Int = 0 // Not needed if using Binding in Stepper

    var body: some View {
        // Use an outer container like VStack or Group
        VStack {
            // Safely unwrap the currentItem
            if let item = currentItem {
                VStack(spacing: 20) {
                    Text(item.name)
                        .font(.largeTitle)
                    Text(item.spec)
                        .font(.title2)
                        .foregroundColor(.gray)

                    Divider()

                    Text("目前數量: \(item.quantity)")
                        .font(.title)

                    // Stepper for quantity adjustment
                    // Use a Binding to directly read/write the quantity via the ViewModel
                    Stepper("調整數量", value: Binding(
                        get: { item.quantity }, // Read current quantity
                        set: { newQuantity in
                            // Calculate the change and update through ViewModel
                            let change = newQuantity - item.quantity
                            viewModel.updateQuantity(for: item, change: change)
                        }
                    ), in: 0...Int.max) // Allow quantity from 0 upwards
                        .padding(.horizontal)

                    // Optional quick adjustment buttons
                    HStack(spacing: 15) {
                        Button("-10") { viewModel.updateQuantity(for: item, change: -10) }
                            .buttonStyle(.bordered)
                            .disabled(item.quantity < 10)
                        Button("-1") { viewModel.updateQuantity(for: item, change: -1) }
                            .buttonStyle(.bordered)
                            .disabled(item.quantity < 1)
                        Button("+1") { viewModel.updateQuantity(for: item, change: 1) }
                            .buttonStyle(.borderedProminent)
                        Button("+10") { viewModel.updateQuantity(for: item, change: 10) }
                            .buttonStyle(.borderedProminent)
                    }

                    Spacer() // Push content to the top
                }
                .padding()

            } else {
                // Display if the item couldn't be found (shouldn't normally happen if navigation is correct)
                Text("找不到零件資料")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("零件詳細資料")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Preview Provider - Ensure it correctly sets up ViewModel and passes an ID
struct PartDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Setup inside a local closure to avoid top-level statements in the View builder
        let preview: some View = {
            let previewViewModel = InventoryViewModel()
            let sampleItem = PartItem(name: "預覽電阻", spec: "10KΩ", quantity: 25)
            previewViewModel.items.append(sampleItem)
            return NavigationView {
                PartDetailView(itemId: sampleItem.id)
                    .environmentObject(previewViewModel)
            }
        }()
        return preview
    }
}
