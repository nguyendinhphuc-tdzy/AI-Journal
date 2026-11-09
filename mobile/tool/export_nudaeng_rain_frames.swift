// Run from the repository root on macOS:
// swift -module-cache-path /tmp/nudaeng-swift-cache mobile/tool/export_nudaeng_rain_frames.swift
// Packs the imagegen wardrobe edit into app frames; original ride assets stay intact.
import Foundation
import CoreGraphics
import ImageIO

let assets = "mobile/assets/images/"
let review = "docs/design/nudaeng-street/rain/"
let frameWidth = 480, frameHeight = 574
let roadY = 556.0 // Original 516 baseline, plus 40 px hood clearance.
let cs = CGColorSpaceCreateDeviceRGB()

func read(_ path: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
              bytesPerRow: w * 4, space: cs,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func raster(_ image: CGImage) -> CGContext {
    let c = context(image.width, image.height)
    c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return c
}
func png(_ image: CGImage, _ path: String) {
    let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                             "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, image, nil)
    precondition(CGImageDestinationFinalize(dst), "Cannot save \(path)")
}
struct Hub { let x: Double; let y: Double; let area: Int }
func hubs(_ image: CGImage) -> [Hub] {
    let w = image.width, h = image.height, c = raster(image)
    let p = c.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var candidates = [Bool](repeating: false, count: w * h)
    for y in Int(Double(h) * 0.65)..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let r = Int(p[i]), g = Int(p[i + 1]), b = Int(p[i + 2])
            candidates[y * w + x] = p[i + 3] > 200 && r > 140 && r < 235
                && b - r > 12 && g - r > 5 && b > 170
        }
    }
    var visited = [Bool](repeating: false, count: w * h)
    var found = [Hub]()
    for seed in 0..<w*h where candidates[seed] && !visited[seed] {
        var q = [seed], head = 0; visited[seed] = true
        var sx = 0, sy = 0
        while head < q.count {
            let v = q[head]; head += 1
            let x = v % w, y = v / w; sx += x; sy += y
            for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                let nx = x + dx, ny = y + dy
                if nx >= 0 && nx < w && ny >= 0 && ny < h {
                    let n = ny * w + nx
                    if candidates[n] && !visited[n] { visited[n] = true; q.append(n) }
                }
            }
        }
        if q.count > 12 { found.append(Hub(x: Double(sx)/Double(q.count),
                                         y: Double(sy)/Double(q.count), area: q.count)) }
    }
    let best = Array(found.sorted { $0.area > $1.area }.prefix(2)).sorted { $0.x < $1.x }
    precondition(best.count == 2 && best[1].x - best[0].x > Double(w) * 0.4,
                 "Could not locate both wheel hubs")
    return best
}
func clean(_ image: CGImage) -> CGImage {
    let c = raster(image), w = image.width, h = image.height
    let p = c.data!.bindMemory(to: UInt8.self, capacity: w*h*4)
    // Transparent generation fringes are discarded; keep the connected character.
    var seen = [Bool](repeating: false, count: w*h), largest = [Int]()
    for seed in 0..<w*h where p[seed*4+3] >= 128 && !seen[seed] {
        var q = [seed], head = 0; seen[seed] = true
        while head < q.count {
            let v = q[head]; head += 1; let x = v % w, y = v / w
            for dy in -1...1 { for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                if nx >= 0 && nx < w && ny >= 0 && ny < h {
                    let n = ny*w+nx
                    if p[n*4+3] >= 128 && !seen[n] { seen[n] = true; q.append(n) }
                }
            }}
        }
        if q.count > largest.count { largest = q }
    }
    precondition(largest.count > w*h/10, "No complete character in cell")
    var keep = [Bool](repeating: false, count: w*h)
    for v in largest { keep[v] = true }
    for i in 0..<w*h where !keep[i] { for k in 0...3 { p[i*4+k] = 0 } }
    return c.makeImage()!
}
func tyreFloor(_ image: CGImage) -> Int {
    let c = raster(image), w = image.width, h = image.height
    let p = c.data!.bindMemory(to: UInt8.self, capacity: w*h*4)
    var floor = 0
    for y in Int(Double(h)*0.75)..<h { for x in 0..<w {
        if abs(Double(x)-56.4) > 60 && abs(Double(x)-422.1) > 60 { continue }
        let i = (y*w+x)*4
        let r = Int(p[i]), g = Int(p[i+1]), b = Int(p[i+2])
        if p[i+3] > 200 && max(r,g,b) < 150 && max(r,g,b)-min(r,g,b) < 45 {
            floor = max(floor,y)
        }
    }}
    return floor + 1
}

let source = read(review + "raincoat-sheet.png")
let reference = hubs(read(assets + "nudaeng-ride-01.png"))
let contact = context(frameWidth*4, frameHeight*3)
var report = [[String: Any]]()
for i in 0..<12 {
    let x0 = Int((Double(i%4)*Double(source.width)/4).rounded())
    let x1 = Int((Double(i%4+1)*Double(source.width)/4).rounded())
    let y0 = Int((Double(i/4)*Double(source.height)/3).rounded())
    let y1 = Int((Double(i/4+1)*Double(source.height)/3).rounded())
    let cell = clean(source.cropping(to: CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0))!)
    let points = hubs(cell)
    let sx = points[1].x-points[0].x, sy = points[1].y-points[0].y
    let dx = reference[1].x-reference[0].x, dy = reference[1].y-reference[0].y
    let a = (dx*sx+dy*sy)/(sx*sx+sy*sy), b = (dy*sx-dx*sy)/(sx*sx+sy*sy)
    let tx = reference[0].x-a*points[0].x+b*points[0].y
    let initialTy = reference[0].y+40-b*points[0].x-a*points[0].y
    func place(_ ty: Double) -> CGImage {
        let c = context(frameWidth,frameHeight)
        c.interpolationQuality = .high
        let ch = Double(cell.height)
        c.concatenate(CGAffineTransform(a:a,b:-b,c:b,d:a,tx:tx-b*ch,
                                        ty:Double(frameHeight)-ty-a*ch))
        c.draw(cell,in:CGRect(x:0,y:0,width:cell.width,height:cell.height))
        return c.makeImage()!
    }
    let first = place(initialTy)
    let adjustment = roadY-Double(tyreFloor(first))
    precondition(abs(adjustment)<12, "Unexpected baseline correction")
    let output = place(initialTy+adjustment)
    precondition(tyreFloor(output)==Int(roadY), "Wheel baseline not registered")
    let r = raster(output), p = r.data!.bindMemory(to: UInt8.self,capacity:frameWidth*frameHeight*4)
    var edge = 0, mustard = 0
    for y in 0..<frameHeight { for x in 0..<frameWidth {
        let j = (y*frameWidth+x)*4
        if (x==0 || y==0 || x==frameWidth-1 || y==frameHeight-1) && p[j+3]>128 { edge += 1 }
        if p[j+3]>200 && p[j]>170 && p[j+1]>100 && Int(p[j+1])-Int(p[j+2])>50 { mustard += 1 }
    }}
    precondition(edge==0 && mustard>1000, "Clipped frame or absent raincoat")
    let name = String(format:"nudaeng-rain-ride-%02d.png",i+1)
    png(output,assets+name)
    let left=(i%4)*frameWidth, top=(2-i/4)*frameHeight
    contact.setFillColor(CGColor(red:i%2==0 ? 0.84:0.14,green:i%2==0 ? 0.91:0.21,blue:i%2==0 ? 0.91:0.24,alpha:1))
    contact.fill(CGRect(x:left,y:top,width:frameWidth,height:frameHeight))
    contact.draw(output,in:CGRect(x:left,y:top,width:frameWidth,height:frameHeight))
    report.append(["file":name,"wheelRoadY":tyreFloor(output),"baselineCorrection":adjustment,
                   "scale":hypot(a,b),"edgeOpaquePixels":edge])
}
png(contact.makeImage()!,review+"raincoat-review.png")
let json = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
try json.write(to:URL(fileURLWithPath:review+"alignment.json"))
print("Exported 12 raincoat frames, 480x574, road baseline 556; all alpha borders clear.")
