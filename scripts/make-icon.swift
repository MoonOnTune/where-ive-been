import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "where-ive-been-1024.png"
let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
context.setAllowsAntialiasing(true)

let outer = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(red: 0.18, green: 0.16, blue: 0.92, alpha: 1),
    NSColor(red: 0.48, green: 0.20, blue: 0.86, alpha: 1),
    NSColor(red: 0.08, green: 0.76, blue: 0.82, alpha: 1)
])!
gradient.draw(in: outer, angle: -42)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 42, color: NSColor.black.withAlphaComponent(0.30).cgColor)
let route = NSBezierPath()
route.move(to: NSPoint(x: 255, y: 290))
route.curve(to: NSPoint(x: 760, y: 690), controlPoint1: NSPoint(x: 570, y: 250), controlPoint2: NSPoint(x: 420, y: 720))
route.lineWidth = 42
route.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.92).setStroke()
route.stroke()
context.restoreGState()

for (point, diameter, color) in [
    (NSPoint(x: 255, y: 290), CGFloat(92), NSColor.white),
    (NSPoint(x: 760, y: 690), CGFloat(126), NSColor(red: 1, green: 0.72, blue: 0.25, alpha: 1))
] {
    let circle = NSBezierPath(ovalIn: NSRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))
    color.setFill()
    circle.fill()
}

let compass = NSBezierPath()
compass.move(to: NSPoint(x: 760, y: 742))
compass.line(to: NSPoint(x: 715, y: 650))
compass.line(to: NSPoint(x: 760, y: 674))
compass.line(to: NSPoint(x: 805, y: 650))
compass.close()
NSColor(red: 0.22, green: 0.19, blue: 0.72, alpha: 1).setFill()
compass.fill()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode icon") }
try png.write(to: URL(fileURLWithPath: output))
