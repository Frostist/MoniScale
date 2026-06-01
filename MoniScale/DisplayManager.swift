//
//  DisplayManager.swift
//  MoniScale
//
//  Created by Will Frost on 2026/05/31.
//

import Foundation
import CoreGraphics
import Combine

struct DisplayMode {
    let index: Int32
    let width: UInt32
    let height: UInt32
    let refreshRate: UInt16
    let isHiDPI: Bool
    var isVirtual: Bool { index == -1 }
}

struct MonitorInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let modes: [DisplayMode]
    var currentModeIndex: Int
}

@MainActor
class DisplayManager: ObservableObject {
    @Published var monitors: [MonitorInfo] = []

    // Keyed by physical display ID; kept alive to preserve the virtual display
    private var virtualDisplays: [CGDirectDisplayID: CGVirtualDisplay] = [:]
    // Tracks which array index in modes[] is currently active via virtual display
    private var activeVirtualModeIndices: [CGDirectDisplayID: Int] = [:]
    // Mirrors to set up once the virtual display appears in the online list (virtualID -> physicalID)
    private var pendingMirrors: [CGDirectDisplayID: CGDirectDisplayID] = [:]
    // Debounce rapid hardware reconfiguration events
    private var detectWorkItem: DispatchWorkItem?

    // MARK: - Public API

    // Debounced version for hardware reconfiguration callbacks — coalesces rapid events
    func scheduleDetect() {
        detectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.detectDisplays() }
        detectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    func detectDisplays() {
        var onlineIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &onlineIDs, &count) == .success else { return }
        let onlineSet = Set(onlineIDs.prefix(Int(count)))

        // Apply any mirrors that were deferred until the virtual display became online
        for (virtualID, physicalID) in pendingMirrors where onlineSet.contains(virtualID) {
            pendingMirrors.removeValue(forKey: virtualID)
            setupMirror(physicalID: physicalID, virtualID: virtualID)
        }

        let ourVirtualIDs = Set(virtualDisplays.values.map { CGDirectDisplayID($0.displayID) })

        var result: [MonitorInfo] = []
        for id in onlineSet {
            guard CGDisplayIsBuiltin(id) == 0 else { continue }
            guard !ourVirtualIDs.contains(id) else { continue }

            let name = Self.displayName(for: id)
            let nativeModes = Self.enumerateModes(for: id)
            guard !nativeModes.isEmpty else { continue }

            let nativeRes = nativeModes.max(by: { $0.width * $0.height < $1.width * $1.height })!
            let virtualModes = Self.virtualModesAbove(nativeWidth: nativeRes.width, nativeHeight: nativeRes.height)
            let allModes = nativeModes + virtualModes

            let currentModeIndex: Int
            if let virtualIdx = activeVirtualModeIndices[id] {
                currentModeIndex = virtualIdx
            } else {
                let (curW, curH) = Self.currentLogicalSize(for: id)
                currentModeIndex = allModes.firstIndex { $0.width == curW && $0.height == curH } ?? 0
            }

            result.append(MonitorInfo(id: id, name: name, modes: allModes, currentModeIndex: currentModeIndex))
        }
        self.monitors = result.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // arrayIndex: index into MonitorInfo.modes[]
    func setMode(displayID: CGDirectDisplayID, arrayIndex: Int) {
        guard let monitor = monitors.first(where: { $0.id == displayID }),
              arrayIndex < monitor.modes.count else { return }
        let mode = monitor.modes[arrayIndex]
        if mode.isVirtual {
            activateVirtualMode(displayID: displayID, mode: mode, arrayIndex: arrayIndex)
        } else {
            clearVirtualMode(for: displayID)
            setNativeMode(displayID: displayID, cgsIndex: mode.index)
        }
    }

    // Remove all virtual displays — call before app termination
    func teardownAllVirtualDisplays() {
        for displayID in virtualDisplays.keys {
            removeMirror(for: displayID)
        }
        virtualDisplays = [:]
        activeVirtualModeIndices = [:]
        pendingMirrors = [:]
    }

    // MARK: - Virtual mode management

    private func activateVirtualMode(displayID: CGDirectDisplayID, mode: DisplayMode, arrayIndex: Int) {
        if let old = virtualDisplays[displayID] {
            pendingMirrors.removeValue(forKey: CGDirectDisplayID(old.displayID))
            removeMirror(for: displayID)
            virtualDisplays[displayID] = nil
        }

        guard let vd = Self.makeVirtualDisplay(width: mode.width, height: mode.height) else { return }
        let virtualID = CGDirectDisplayID(vd.displayID)
        guard virtualID != 0 else { return }

        virtualDisplays[displayID] = vd
        activeVirtualModeIndices[displayID] = arrayIndex

        // Fix unintended side-effects of virtual display creation before setting up intended mirror.
        // The virtual display can steal "main display" status or trigger auto-mirroring.
        var fixConfig: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&fixConfig) == .success {
            var changed = false
            if CGMainDisplayID() == virtualID {
                CGConfigureDisplayOrigin(fixConfig, displayID, 0, 0)
                changed = true
            }
            if CGDisplayMirrorsDisplay(displayID) == virtualID {
                CGConfigureDisplayMirrorOfDisplay(fixConfig, displayID, CGDirectDisplayID(0))
                changed = true
            }
            if changed {
                if CGCompleteDisplayConfiguration(fixConfig, CGConfigureOption(rawValue: 0)) != .success {
                    CGCancelDisplayConfiguration(fixConfig)
                }
            } else {
                CGCancelDisplayConfiguration(fixConfig)
            }
        }

        // Apply mirror once the virtual display is in the online list
        var onlineIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var onlineCount: UInt32 = 0
        if CGGetOnlineDisplayList(16, &onlineIDs, &onlineCount) == .success,
           onlineIDs.prefix(Int(onlineCount)).contains(virtualID) {
            setupMirror(physicalID: displayID, virtualID: virtualID)
        } else {
            pendingMirrors[virtualID] = displayID
        }
        detectDisplays()
    }

    private func clearVirtualMode(for displayID: CGDirectDisplayID) {
        guard virtualDisplays[displayID] != nil else { return }
        removeMirror(for: displayID)
        virtualDisplays[displayID] = nil
        activeVirtualModeIndices.removeValue(forKey: displayID)
    }

    private func setupMirror(physicalID: CGDirectDisplayID, virtualID: CGDirectDisplayID) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayMirrorOfDisplay(config, physicalID, virtualID)
        if CGCompleteDisplayConfiguration(config, CGConfigureOption(rawValue: 0)) != .success {
            CGCancelDisplayConfiguration(config)
        }
    }

    private func removeMirror(for displayID: CGDirectDisplayID) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayMirrorOfDisplay(config, displayID, CGDirectDisplayID(0))
        if CGCompleteDisplayConfiguration(config, CGConfigureOption(rawValue: 0)) != .success {
            CGCancelDisplayConfiguration(config)
        }
    }

    private func setNativeMode(displayID: CGDirectDisplayID, cgsIndex: Int32) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGSConfigureDisplayMode(config, displayID, cgsIndex)
        if CGCompleteDisplayConfiguration(config, CGConfigureOption(rawValue: 0)) != .success {
            CGCancelDisplayConfiguration(config)
        }
        // The reconfiguration callback triggers detectDisplays(); no need to call it here
    }

    // MARK: - Static helpers

    nonisolated static func deduplicateAndSort(
        _ raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)]
    ) -> [DisplayMode] {
        var best: [String: (index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = [:]
        for entry in raw {
            let key = "\(entry.width)x\(entry.height)"
            if let existing = best[key] {
                if entry.density > existing.density ||
                   (entry.density == existing.density && entry.freq > existing.freq) {
                    best[key] = entry
                }
            } else {
                best[key] = entry
            }
        }
        return best.values
            .sorted { $0.width * $0.height < $1.width * $1.height }
            .map { entry in
                DisplayMode(
                    index: entry.index,
                    width: entry.width,
                    height: entry.height,
                    refreshRate: entry.freq,
                    isHiDPI: entry.density > 1.0
                )
            }
    }

    // Predefined above-native virtual resolutions (non-HiDPI scaled modes), 1080p → 4K
    nonisolated static func virtualModesAbove(nativeWidth: UInt32, nativeHeight: UInt32) -> [DisplayMode] {
        let nativePixels = nativeWidth * nativeHeight
        let candidates: [(UInt32, UInt32)] = [
            (1920, 1200),  // 16:10 step
            (2048, 1152),
            (2560, 1440),  // 2K
            (2560, 1600),  // 16:10 2K
            (3008, 1692),
            (3200, 1800),
            (3840, 2160),  // 4K
        ]
        return candidates.compactMap { (w, h) in
            guard w * h > nativePixels else { return nil }
            return DisplayMode(index: -1, width: w, height: h, refreshRate: 60, isHiDPI: false)
        }
    }

    private static func makeVirtualDisplay(width: UInt32, height: UInt32) -> CGVirtualDisplay? {
        guard let descriptor = CGVirtualDisplayDescriptor() else { return nil }
        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        descriptor.name = "MoniScale Scaler"
        descriptor.maxPixelsWide = width
        descriptor.maxPixelsHigh = height
        let diagonal = sqrt(Double(width * width + height * height))
        let scale = (24.0 * 25.4) / diagonal  // simulate a 24-inch display
        descriptor.sizeInMillimeters = CGSize(width: Double(width) * scale, height: Double(height) * scale)
        descriptor.serialNum = UInt32.random(in: 1...UInt32.max)
        descriptor.productID = 0x5C41
        descriptor.vendorID = 0xF0F0
        descriptor.whitePoint = CGPoint(x: 0.950, y: 1.000)
        descriptor.redPrimary = CGPoint(x: 0.454, y: 0.242)
        descriptor.greenPrimary = CGPoint(x: 0.353, y: 0.674)
        descriptor.bluePrimary = CGPoint(x: 0.157, y: 0.084)

        guard let display = CGVirtualDisplay(descriptor: descriptor),
              let settings = CGVirtualDisplaySettings(),
              let mode = CGVirtualDisplayMode(width: width, height: height, refreshRate: 60.0) else {
            return nil
        }
        settings.hiDPI = 0  // non-HiDPI: logical pixels = physical pixels, downsampled to native
        settings.modes = [mode]
        guard display.applySettings(settings) else { return nil }
        return display
    }

    private static func displayName(for id: CGDirectDisplayID) -> String {
        if let dict = CoreDisplay_DisplayCreateInfoDictionary(id)?.takeRetainedValue() as NSDictionary?,
           let names = dict["DisplayProductName"] as? [String: String],
           let name = names["en_US"] ?? names.sorted(by: { $0.key < $1.key }).first?.value {
            return name
        }
        return "Display \(id)"
    }

    private static func enumerateModes(for id: CGDirectDisplayID) -> [DisplayMode] {
        var count: Int32 = 0
        CGSGetNumberOfDisplayModes(id, &count)
        guard count > 0 else { return [] }

        var modeDesc = CGSDisplayMode()
        let modeSize = Int32(MemoryLayout<CGSDisplayMode>.size)

        var raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = []
        for i in 0..<count {
            CGSGetDisplayModeDescriptionOfLength(id, i, &modeDesc, modeSize)
            raw.append((index: i, width: modeDesc.width, height: modeDesc.height,
                        density: modeDesc.density, freq: modeDesc.freq))
        }
        return deduplicateAndSort(raw)
    }

    private static func currentLogicalSize(for id: CGDirectDisplayID) -> (width: UInt32, height: UInt32) {
        var current: Int32 = 0
        var modeDesc = CGSDisplayMode()
        let modeSize = Int32(MemoryLayout<CGSDisplayMode>.size)
        CGSGetCurrentDisplayMode(id, &current)
        CGSGetDisplayModeDescriptionOfLength(id, current, &modeDesc, modeSize)
        return (modeDesc.width, modeDesc.height)
    }
}
