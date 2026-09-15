import AppKit
// Storyline tile: macOS rounded square in Storyline's magenta with the "sl" wordmark.
let out = CommandLine.arguments[1]
let size = 1024.0, inset = 100.0, radius = 185.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
NSColor.clear.set(); NSRect(x: 0, y: 0, width: size, height: size).fill()
let tile = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
NSColor(calibratedRed: 0xC0/255.0, green: 0x5A/255.0, blue: 0xA6/255.0, alpha: 1).set()
NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()
let font = NSFont(name: "Futura-Medium", size: 460) ?? NSFont.systemFont(ofSize: 460, weight: .medium)
let s = NSAttributedString(string: "sl", attributes: [.font: font, .foregroundColor: NSColor.white])
let sz = s.size()
s.draw(at: NSPoint(x: (size - sz.width)/2, y: (size - sz.height)/2 - 20))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
