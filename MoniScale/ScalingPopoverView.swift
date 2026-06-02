//
//  ScalingPopoverView.swift
//  MoniScale
//
//  Created by Will Frost on 2026/05/31.
//

import SwiftUI

struct ScalingPopoverView: View {
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "display")
                    .foregroundStyle(.secondary)
                Text("MoniScale")
                    .font(.headline)
            }
            .padding([.top, .horizontal], 14)
            .padding(.bottom, 10)

            Divider()

            if displayManager.monitors.isEmpty {
                Text("No external displays connected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(displayManager.monitors) { monitor in
                    MonitorSliderRow(monitor: monitor, onSetMode: { displayManager.setMode(displayID: monitor.id, arrayIndex: $0) })
                    if monitor.id != displayManager.monitors.last?.id {
                        Divider()
                    }
                }
            }

            Divider()

            HStack {
                Button("Refresh") {
                    displayManager.detectDisplays()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            .padding([.bottom, .horizontal], 12)
            .padding(.top, 8)
        }
        .frame(width: 280)
    }
}

private struct MonitorSliderRow: View {
    let monitor: MonitorInfo
    let onSetMode: (Int) -> Void
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.name.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            HStack {
                Text("Larger")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Slider(
                    value: $sliderValue,
                    in: 0...Double(max(monitor.modes.count - 1, 1)),
                    onEditingChanged: { isEditing in
                        guard !isEditing else { return }  // apply only on release, not during drag
                        let idx = Int(sliderValue.rounded())
                        guard idx < monitor.modes.count else { return }
                        sliderValue = Double(idx)  // snap thumb to integer position
                        onSetMode(idx)
                    }
                )
                Text("Smaller")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(resolutionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear { sliderValue = Double(monitor.currentModeIndex) }
        .onChange(of: monitor.currentModeIndex) { _, newIdx in
            sliderValue = Double(newIdx)
        }
    }

    private var resolutionLabel: String {
        let idx = Int(sliderValue.rounded())
        guard idx < monitor.modes.count else { return "" }
        let mode = monitor.modes[idx]
        var label = "\(mode.width)×\(mode.height)"
        if mode.isHiDPI { label += " (HiDPI)" }
        if mode.isVirtual { label += " (Scaled)" }
        return label
    }
}
