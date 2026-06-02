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
                    MonitorSliderRow(
                        monitor: monitor,
                        onSetMode: { displayManager.setMode(displayID: monitor.id, arrayIndex: $0) },
                        onSetRate: { displayManager.setRefreshRate(displayID: monitor.id, rate: $0) }
                    )
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
    let onSetRate: (UInt16) -> Void
    @State private var sliderValue: Double = 0
    @State private var rateIndex: Int = 0

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
                        guard !isEditing else { return }
                        let idx = Int(sliderValue.rounded())
                        guard idx < monitor.modes.count else { return }
                        sliderValue = Double(idx)
                        rateIndex = monitor.modes[idx].availableRates.count - 1
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

            if currentAvailableRates.count > 1 {
                HStack {
                    Text("Refresh")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(currentAvailableRates[rateIndex].rate) Hz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("", value: $rateIndex, in: 0...(currentAvailableRates.count - 1))
                        .labelsHidden()
                        .onChange(of: rateIndex) { _, idx in
                            onSetRate(currentAvailableRates[idx].rate)
                        }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            sliderValue = Double(monitor.currentModeIndex)
            rateIndex = rateIndexFor(monitor.currentRefreshRate)
        }
        .onChange(of: monitor.currentModeIndex) { _, newIdx in
            sliderValue = Double(newIdx)
        }
        .onChange(of: monitor.currentRefreshRate) { _, newRate in
            rateIndex = rateIndexFor(newRate)
        }
    }

    private var currentResolutionIndex: Int { Int(sliderValue.rounded()) }

    private var currentAvailableRates: [(rate: UInt16, cgsIndex: Int32)] {
        guard currentResolutionIndex < monitor.modes.count else { return [] }
        return monitor.modes[currentResolutionIndex].availableRates
    }

    private func rateIndexFor(_ rate: UInt16) -> Int {
        currentAvailableRates.firstIndex(where: { $0.rate == rate }) ?? (currentAvailableRates.count - 1)
    }

    private var resolutionLabel: String {
        guard currentResolutionIndex < monitor.modes.count else { return "" }
        let mode = monitor.modes[currentResolutionIndex]
        var label = "\(mode.width)×\(mode.height)"
        if mode.isHiDPI { label += " (HiDPI)" }
        if mode.isVirtual { label += " (Scaled)" }
        return label
    }
}
