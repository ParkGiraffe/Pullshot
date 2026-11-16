// 사용법: render <입력.svg> <출력.png> [크기=1024]
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: render in.svg out.png [size]"); exit(2) }
let size = args.count > 3 ? Int(args[3])! : 1024
guard let img = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else { print("load fail \(args[1])"); exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high
ctx.shouldAntialias = true
NSColor.clear.set()
NSRect(x: 0, y: 0, width: size, height: size).fill()
img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
let srgb = rep.converting(to: .sRGB, renderingIntent: .default) ?? rep
try! srgb.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
