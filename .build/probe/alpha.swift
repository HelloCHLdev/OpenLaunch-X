import AppKit
let path = CommandLine.arguments[1]
guard let img = NSImage(contentsOfFile: path),
      let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { exit(1) }
print("size: \(rep.pixelsWide)x\(rep.pixelsHigh) hasAlpha=\(rep.hasAlpha)")
let pts: [(String, Int, Int)] = [
    ("左上角", 2, 2),
    ("右上角", rep.pixelsWide - 3, 2),
    ("左下角", 2, rep.pixelsHigh - 3),
    ("右下角", rep.pixelsWide - 3, rep.pixelsHigh - 3),
    ("正中", rep.pixelsWide / 2, rep.pixelsHigh / 2)
]
for (name, x, y) in pts {
    if let c = rep.colorAt(x: x, y: y) {
        let a = c.alphaComponent
        print("\(name) (\(x),\(y)) alpha=\(String(format: "%.3f", a)) rgb=(\(String(format: "%.2f", c.redComponent)),\(String(format: "%.2f", c.greenComponent)),\(String(format: "%.2f", c.blueComponent)))")
    }
}
