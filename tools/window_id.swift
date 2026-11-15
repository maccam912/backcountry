// Prints the CoreGraphics window id of the largest on-screen Luanti window.
import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
var best = 0, area = 0.0
for w in list {
    let owner = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    if owner.contains("luanti") || owner.contains("minetest") {
        let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
        let a = (b["Width"] as? Double ?? 0) * (b["Height"] as? Double ?? 0)
        if a > area { area = a; best = w[kCGWindowNumber as String] as? Int ?? 0 }
    }
}
print(best)
