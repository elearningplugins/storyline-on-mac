import AppKit
// Vector Dock icon: macOS rounded tile in Articulate blue with the "ā" wordmark drawn from a font.
let out = CommandLine.arguments[1]
let size = 1024.0, inset = 100.0, radius = 185.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
NSColor.clear.set(); NSRect(x: 0, y: 0, width: size, height: size).fill()
let tile = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
NSColor(calibratedRed: 0x18/255.0, green: 0xB6/255.0, blue: 0xE2/255.0, alpha: 1).set()
NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()
let font = NSFont(name: "Futura-Medium", size: 640) ?? NSFont.systemFont(ofSize: 640, weight: .medium)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
let s = NSAttributedString(string: "a", attributes: attrs)
let sz = s.size()
let ax = (size - sz.width)/2, ay = (size - sz.height)/2 - 30
s.draw(at: NSPoint(x: ax, y: ay))
// macron bar above the glyph
let barW = sz.width * 0.92, barH = 58.0
NSColor.white.set()
NSRect(x: (size - barW)/2, y: ay + sz.height*0.74, width: barW, height: barH).fill()
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
