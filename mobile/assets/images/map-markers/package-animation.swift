import Foundation
import ImageIO
import UniformTypeIdentifiers

// Mechanical sprite extraction and APNG packaging; artwork is generated separately.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let source = CGImageSourceCreateWithURL(root.appendingPathComponent("nudaeng-blink-wave-sheet.png") as CFURL, nil)!
let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil)!
precondition(sheet.width % 3 == 0 && sheet.height % 2 == 0)
let w = sheet.width / 3, h = sheet.height / 2
var frames: [CGImage] = []
for i in 0..<6 {
    let rect = CGRect(x: (i % 3) * w, y: (i / 3) * h, width: w, height: h)
    let frame = sheet.cropping(to: rect)!
    frames.append(frame)
    let url = root.appendingPathComponent(String(format: "nudaeng-frame-%02d.png", i + 1))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, frame, nil)
    precondition(CGImageDestinationFinalize(dest))
}
let order = [0, 1, 0, 2, 3, 4, 3, 4, 2, 5]
let durations = [0.35, 0.10, 0.15, 0.10, 0.13, 0.13, 0.13, 0.13, 0.10, 0.48]
let output = root.appendingPathComponent("nudaeng-blink-wave.apng")
let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, order.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 1]] as CFDictionary)
for (i, frameIndex) in order.enumerated() {
    CGImageDestinationAddImage(dest, frames[frameIndex], [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: durations[i], kCGImagePropertyAPNGUnclampedDelayTime: durations[i]]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(dest))
let check = CGImageSourceCreateWithURL(output as CFURL, nil)!
precondition(CGImageSourceGetCount(check) == order.count)
print("Verified APNG: \(order.count) frames, \(w)x\(h), \(durations.reduce(0,+)) seconds; six source PNG frames.")
