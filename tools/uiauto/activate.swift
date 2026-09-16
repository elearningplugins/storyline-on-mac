import AppKit
let pid = Int32(CommandLine.arguments[1])!
if let app = NSRunningApplication(processIdentifier: pid) { app.activate(options: [.activateIgnoringOtherApps]); print("activated \(app.localizedName ?? "?")") } else { print("no such pid") }
