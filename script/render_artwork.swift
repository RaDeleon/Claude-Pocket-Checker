import AppKit
let input=CommandLine.arguments[1],output=CommandLine.arguments[2]
guard let image=NSImage(contentsOfFile:input) else {fatalError("Cannot read SVG")}
let width=1280,height=640
let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
image.draw(in:NSRect(x:0,y:0,width:width,height:height),from:.zero,operation:.copy,fraction:1)
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
