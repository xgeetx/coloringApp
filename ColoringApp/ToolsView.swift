import SwiftUI

// MARK: - Left Panel: Brush Tools + Size

struct BrushToolsView: View {
    @ObservedObject var state: DrawingState
    @State private var showingBuilder    = false
    @State private var showingPoolPicker = false
    @State private var targetSlot: Int   = 0

    private let sizes: [(String, CGFloat)] = [
        ("S", 10), ("M", 22), ("L", 40), ("XL", 60)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🎨")
                    .font(.system(size: 28))
                    .padding(.top, 4)

                Divider()

                // ── System Brushes ──
                VStack(spacing: 10) {
                    ForEach(BrushDescriptor.systemBrushes) { brush in
                        BrushDescriptorButton(
                            icon: brush.icon,
                            label: brush.name,
                            isSelected: !state.isStampMode && !state.isEraserMode
                                        && state.selectedBrush.id == brush.id,
                            onTap: {
                                state.selectedBrush = brush
                                state.isStampMode   = false
                                state.isEraserMode  = false
                            }
                        )
                    }

                }

                Divider()

                // ── My Brushes ──
                VStack(spacing: 8) {
                    Text("My Brushes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(0..<3, id: \.self) { slot in
                        SlotButton(
                            brush: brushForSlot(slot),
                            isSelected: isSlotSelected(slot),
                            onTap:      { selectSlot(slot) },
                            onLongPress: {
                                targetSlot        = slot
                                showingPoolPicker = true
                            }
                        )
                    }

                    Button(action: { showingBuilder = true }) {
                        Label("Build Brush", systemImage: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // ── Size Picker ──
                VStack(spacing: 8) {
                    Text("Size")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(sizes, id: \.0) { label, size in
                        SizeButton(
                            label: label,
                            size: size,
                            isSelected: state.brushSize == size,
                            onTap: { state.brushSize = size }
                        )
                    }
                }

                Spacer()
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.12), radius: 6)
        )
        .fullScreenCover(isPresented: $showingBuilder) {
            BrushBuilderView(state: state)
        }
        .sheet(isPresented: $showingPoolPicker) {
            PoolPickerView(state: state, slot: targetSlot)
        }
    }

    // MARK: - Helpers

    private func brushForSlot(_ slot: Int) -> BrushDescriptor? {
        guard let id = state.slotAssignments[slot] else { return nil }
        return state.brushPool.first { $0.id == id }
    }

    private func isSlotSelected(_ slot: Int) -> Bool {
        guard !state.isStampMode && !state.isEraserMode,
              let brush = brushForSlot(slot) else { return false }
        return state.selectedBrush.id == brush.id
    }

    private func selectSlot(_ slot: Int) {
        guard let brush = brushForSlot(slot) else { return }
        state.selectedBrush = brush
        state.isStampMode   = false
        state.isEraserMode  = false
    }
}

// MARK: - BrushDescriptorButton

struct BrushDescriptorButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 26))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - SlotButton

struct SlotButton: View {
    let brush: BrushDescriptor?
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        let filled = brush != nil
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(brush?.icon ?? "＋")
                    .font(.system(size: filled ? 22 : 18))
                    .foregroundStyle(filled ? Color.primary : Color.secondary)
                Text(brush?.name ?? "Empty")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(filled ? (isSelected ? Color.white : Color.primary) : Color.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor
                          : (filled ? Color.gray.opacity(0.12) : Color.gray.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(filled ? Color.clear : Color.gray.opacity(0.25),
                                          style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

// MARK: - PoolPickerView

struct PoolPickerView: View {
    @ObservedObject var state: DrawingState
    let slot: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("System Brushes") {
                    ForEach(state.brushPool.filter { $0.isSystem }) { brush in
                        poolRow(brush)
                    }
                }
                if state.brushPool.contains(where: { !$0.isSystem }) {
                    Section("My Brushes") {
                        ForEach(state.brushPool.filter { !$0.isSystem }) { brush in
                            poolRow(brush)
                        }
                        .onDelete { indexSet in
                            let userBrushes = state.brushPool.filter { !$0.isSystem }
                            for i in indexSet {
                                state.deleteBrush(id: userBrushes[i].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Slot \(slot + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func poolRow(_ brush: BrushDescriptor) -> some View {
        Button(action: {
            state.assignBrush(id: brush.id, toSlot: slot)
            dismiss()
        }) {
            HStack {
                Text(brush.icon).font(.title2)
                Text(brush.name)
                Spacer()
                if state.slotAssignments[slot] == brush.id {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - SizeButton

struct SizeButton: View {
    let label: String
    let size: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: min(size * 0.5, 26), height: min(size * 0.5, 26))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
