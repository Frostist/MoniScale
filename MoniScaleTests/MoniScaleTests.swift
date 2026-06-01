import Testing
@testable import MoniScale

struct DisplayManagerTests {

    // deduplicateAndSort should keep HiDPI variant when both exist for same resolution
    @Test func keepHiDPIOverStandard() {
        let raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = [
            (0, 1920, 1080, 1.0, 60),  // standard
            (1, 1920, 1080, 2.0, 60),  // HiDPI — should win
            (2, 2560, 1440, 1.0, 60),
        ]
        let modes = DisplayManager.deduplicateAndSort(raw)
        #expect(modes.count == 2)
        let fhd = modes.first { $0.width == 1920 }
        #expect(fhd?.isHiDPI == true)
        #expect(fhd?.index == 1)
    }

    // deduplicateAndSort should sort ascending by pixel count (smallest = index 0)
    @Test func sortAscendingByPixelCount() {
        let raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = [
            (0, 3840, 2160, 1.0, 60),
            (1, 1920, 1080, 2.0, 60),
            (2, 2560, 1440, 2.0, 60),
        ]
        let modes = DisplayManager.deduplicateAndSort(raw)
        #expect(modes.count == 3)
        #expect(modes[0].width == 1920)
        #expect(modes[1].width == 2560)
        #expect(modes[2].width == 3840)
    }

    // A single mode should pass through unchanged
    @Test func singleModePassThrough() {
        let raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = [
            (3, 2560, 1440, 2.0, 144),
        ]
        let modes = DisplayManager.deduplicateAndSort(raw)
        #expect(modes.count == 1)
        #expect(modes[0].index == 3)
        #expect(modes[0].refreshRate == 144)
        #expect(modes[0].isHiDPI == true)
    }

    // Empty input should produce empty output
    @Test func emptyInput() {
        let raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = []
        let modes = DisplayManager.deduplicateAndSort(raw)
        #expect(modes.isEmpty)
    }

    // When same resolution and density, keep highest refresh rate
    @Test func keepHighestRefreshRateAtSameDensity() {
        let raw: [(index: Int32, width: UInt32, height: UInt32, density: Float, freq: UInt16)] = [
            (0, 1920, 1080, 1.0, 60),   // lower refresh — should lose
            (1, 1920, 1080, 1.0, 120),  // higher refresh — should win
        ]
        let modes = DisplayManager.deduplicateAndSort(raw)
        #expect(modes.count == 1)
        #expect(modes[0].refreshRate == 120)
        #expect(modes[0].index == 1)
    }

    // virtualModesAbove should offer modes strictly larger than native
    @Test func virtualModesAbove1080p() {
        let modes = DisplayManager.virtualModesAbove(nativeWidth: 1920, nativeHeight: 1080)
        #expect(!modes.isEmpty)
        #expect(modes.allSatisfy { $0.isVirtual })
        #expect(modes.allSatisfy { $0.width * $0.height > 1920 * 1080 })
        #expect(modes.contains { $0.width == 2560 && $0.height == 1440 })
    }

    // virtualModesAbove should return nothing for a 4K display (already at or above all candidates)
    @Test func virtualModesAbove4K() {
        let modes = DisplayManager.virtualModesAbove(nativeWidth: 3840, nativeHeight: 2160)
        #expect(modes.isEmpty)
    }

    // virtualModesAbove should include 2K, 3K-range, and 4K for a 1080p display
    @Test func virtualModesAbove1080pRange() {
        let modes = DisplayManager.virtualModesAbove(nativeWidth: 1920, nativeHeight: 1080)
        let widths = modes.map { $0.width }
        #expect(widths.contains(2560))  // 2K
        #expect(widths.contains(3840))  // 4K
    }

    // DisplayMode.isVirtual reflects index == -1
    @Test func isVirtualFlag() {
        let native = DisplayMode(index: 5, width: 1920, height: 1080, refreshRate: 60, isHiDPI: false)
        let virtual = DisplayMode(index: -1, width: 2560, height: 1440, refreshRate: 60, isHiDPI: false)
        #expect(!native.isVirtual)
        #expect(virtual.isVirtual)
    }
}
