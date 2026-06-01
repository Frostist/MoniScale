//
//  MoniScaleApp.swift
//  MoniScale
//
//  Created by Will Frost on 2026/05/31.
//

import SwiftUI

@main
struct MoniScaleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
