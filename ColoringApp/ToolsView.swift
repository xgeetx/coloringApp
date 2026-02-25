import SwiftUI

// MARK: - Brushes Flyout Content

struct BrushesFlyoutView: View {
    @ObservedObject var state: DrawingState
    @State private var showingBuilder    = false
    @State private var showingPoolPicker = false
    @State private var targetSlot: Int   = 0

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

                // ── My Brushes (Quick Slots) ──
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

                Spacer()
            }
            .padding(10)
        }
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

// MARK: - Size Flyout Content

struct SizeFlyoutView: View {
    @ObservedObject var state: DrawingState

    var body: some View {
        VStack(spacing: 20) {
            Text("Brush Size")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Live preview dot
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(state.selectedColor)
                    .frame(
                        width: min(state.brushSize * 0.85, 74),
                        height: min(state.brushSize * 0.85, 74)
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state.brushSize)
            }

            Text("\(Int(state.brushSize))pt")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            // Vertical slider (rotated)
            Slider(value: $state.brushSize, in: 6...80, step: 1)
                .tint(.purple)
                .rotationEffect(.degrees(-90))
                .frame(width: 200)
                .frame(height: 220)

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Opacity Flyout Content

struct OpacityFlyoutView: View {
    @ObservedObject var state: DrawingState

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Opacity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(state.brushOpacity * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Live preview swatch
            RoundedRectangle(cornerRadius: 12)
                .fill(state.selectedColor.opacity(state.brushOpacity))
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .animation(.easeOut(duration: 0.15), value: state.brushOpacity)

            Slider(value: $state.brushOpacity, in: 0.1...1.0, step: 0.05)
                .tint(.purple)
                .onChange(of: state.brushOpacity) { _ in state.persist() }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
