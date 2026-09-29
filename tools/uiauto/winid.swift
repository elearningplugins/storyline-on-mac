// Prints "<window-id> <x> <y> <w> <h>" for each on-screen window of a pid, largest first; bounds and ids need no Screen Recording permission.
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
var rows: [(Int, CGRect)] = []
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
    guard let id = w[kCGWindowNumber as String] as? Int, let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
    rows.append((id, CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)))
}
for (id, r) in rows.sorted(by: { $0.1.width * $0.1.height > $1.1.width * $1.1.height }) {
    print("\(id) \(Int(r.minX)) \(Int(r.minY)) \(Int(r.width)) \(Int(r.height))")
}
