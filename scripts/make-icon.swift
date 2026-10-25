import AppKit

// Tekent een eenvoudig app-icoon: een donker vlak met een zwart 'eiland' en een gloed.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 100, dy: 100)
let bg = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.32, alpha: 1),
                    NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.25, alpha: 1)])!
    .draw(in: bg, angle: -90)

let island = NSRect(x: size / 2 - 230, y: size / 2 + 60, width: 460, height: 130)
NSColor.black.setFill()
NSBezierPath(roundedRect: island, xRadius: 65, yRadius: 65).fill()

NSColor.systemGreen.setFill()
NSBezierPath(ovalIn: NSRect(x: island.maxX - 100, y: island.midY - 22, width: 44, height: 44)).fill()
NSColor(white: 1, alpha: 0.9).setFill()
NSBezierPath(roundedRect: NSRect(x: island.minX + 50, y: island.midY - 30, width: 60, height: 60), xRadius: 14, yRadius: 14).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
