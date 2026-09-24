//
//  fauxtoApp.swift
//  fauxto
//
//  Created by Matt Comeione on 9/23/26.
//

import os
import SwiftUI

@main
struct fauxtoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // A single window: there is one camera session to show.
        Window("fauxto", id: "main") {
            ContentView(model: appDelegate.model)
        }
        .defaultSize(width: 960, height: 720)
        .commands { FauxtoCommands(model: appDelegate.model) }

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owned here rather than by the App so quitting can shut the camera down.
    let model = AppModel()

    /// Upper bound on waiting for the camera, so a stuck device can't stop the app from quitting.
    private static let shutdownTimeout: Duration = .seconds(2)

    /// Like Photo Booth, closing the window quits, which also releases the camera.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Stops the capture session before the process exits, rather than leaving it running while
    /// the process tears down. The steps are logged so a stalled quit shows where it stopped:
    /// `log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxto"'`
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = model
        Log.lifecycle.notice("Quit requested; stopping camera")
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await model.stop()
                    Log.lifecycle.notice("Camera stopped")
                }
                group.addTask {
                    try? await Task.sleep(for: Self.shutdownTimeout)
                    if !Task.isCancelled { Log.lifecycle.error("Camera did not stop in time; quitting anyway") }
                }
                await group.next()
                group.cancelAll()
            }
            Log.lifecycle.notice("Terminating")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
