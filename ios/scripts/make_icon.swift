import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Export the approved Android 24-unit SIGNAL logo into an opaque app icon. No font assets.
let output = URL(fileURLWithPath:CommandLine.arguments[1])
try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
let space = CGColorSpaceCreateDeviceRGB()
let canvas = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:0,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
canvas.setFillColor(CGColor(red:9/255.0,green:13/255.0,blue:11/255.0,alpha:1))
canvas.fill(CGRect(x:0,y:0,width:1024,height:1024))
canvas.translateBy(x:176,y:848); canvas.scaleBy(x:28,y:-28)
let accent = CGColor(red:193/255.0,green:247/255.0,blue:107/255.0,alpha:1)
canvas.setStrokeColor(accent); canvas.setFillColor(accent)
canvas.setLineWidth(1.5); canvas.setLineCap(.round); canvas.setLineJoin(.round)
for points in [[CGPoint(x:4,y:20),CGPoint(x:12,y:4),CGPoint(x:20,y:20)],
               [CGPoint(x:8,y:13),CGPoint(x:16,y:13)],
               [CGPoint(x:9,y:20),CGPoint(x:15,y:20)]] {
    canvas.addLines(between:points); canvas.strokePath()
}
canvas.fillEllipse(in:CGRect(x:17.9,y:2.9,width:2.2,height:2.2))
let image = canvas.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,image,nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to export app icon") }
print("SIGNAL app icon generated")
