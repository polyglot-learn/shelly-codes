import Foundation

/// A point on Shelly's canvas. (0, 0) is the middle; y goes up, like Python's turtle.
nonisolated struct Point: Equatable, Hashable, Sendable {
    var x: Double
    var y: Double

    static let zero = Point(x: 0, y: 0)

    func distance(to other: Point) -> Double {
        hypot(other.x - x, other.y - y)
    }

    /// Shortest distance from this point to the segment a–b.
    func distance(toSegment a: Point, _ b: Point) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 { return distance(to: a) }
        let t = max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / lengthSquared))
        return distance(to: Point(x: a.x + t * dx, y: a.y + t * dy))
    }

    func interpolated(to other: Point, _ t: Double) -> Point {
        Point(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }
}

nonisolated struct RGB: Equatable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 1, g: 1, b: 1)

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        self.init(
            r: Double((hex >> 16) & 0xFF) / 255,
            g: Double((hex >> 8) & 0xFF) / 255,
            b: Double(hex & 0xFF) / 255
        )
    }

    /// A color name like "red" or "sky blue", or a hex string like "#ff8800".
    static func parse(_ text: String) -> RGB? {
        let key = text.lowercased().replacingOccurrences(of: " ", with: "")
        if key.hasPrefix("#") {
            var digits = String(key.dropFirst())
            if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
            guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
            return RGB(hex: value)
        }
        return names[key].map { RGB(hex: $0) }
    }

    /// Color names a child is likely to try, with their web (CSS) values.
    static let names: [String: UInt32] = [
        "red": 0xFF0000, "orange": 0xFFA500, "yellow": 0xFFFF00, "green": 0x008000, "blue": 0x0000FF,
        "purple": 0x800080, "pink": 0xFFC0CB, "brown": 0xA52A2A, "black": 0x000000, "white": 0xFFFFFF,
        "gray": 0x808080, "grey": 0x808080, "cyan": 0x00FFFF, "magenta": 0xFF00FF, "gold": 0xFFD700,
        "lime": 0x00FF00, "navy": 0x000080, "teal": 0x008080, "violet": 0xEE82EE, "indigo": 0x4B0082,
        "maroon": 0x800000, "olive": 0x808000, "coral": 0xFF7F50, "salmon": 0xFA8072,
        "turquoise": 0x40E0D0, "skyblue": 0x87CEEB, "lightblue": 0xADD8E6, "darkblue": 0x00008B,
        "darkgreen": 0x006400, "lightgreen": 0x90EE90, "orchid": 0xDA70D6, "plum": 0xDDA0DD,
        "tan": 0xD2B48C, "beige": 0xF5F5DC, "silver": 0xC0C0C0, "crimson": 0xDC143C,
        "chocolate": 0xD2691E, "hotpink": 0xFF69B4, "lavender": 0xE6E6FA, "mint": 0x98FF98,
        "lightgray": 0xD3D3D3, "lightgrey": 0xD3D3D3, "darkgray": 0xA9A9A9, "darkgrey": 0xA9A9A9,
        "darkred": 0x8B0000, "darkorange": 0xFF8C00, "aqua": 0x00FFFF, "fuchsia": 0xFF00FF,
        "royalblue": 0x4169E1, "forestgreen": 0x228B22, "seagreen": 0x2E8B57, "tomato": 0xFF6347,
        "peachpuff": 0xFFDAB9, "khaki": 0xF0E68C, "firebrick": 0xB22222, "deeppink": 0xFF1493,
        "deepskyblue": 0x00BFFF, "springgreen": 0x00FF7F, "yellowgreen": 0x9ACD32, "sienna": 0xA0522D,
        "slateblue": 0x6A5ACD, "steelblue": 0x4682B4, "midnightblue": 0x191970, "lemonchiffon": 0xFFFACD,
    ]
}

nonisolated struct Pen: Equatable, Hashable, Sendable {
    var color: RGB
    var width: Double
}

nonisolated struct TurtleState: Equatable, Sendable {
    var position = Point.zero
    /// Degrees. 0 points right (east) and positive turns are counterclockwise. Not wrapped, so turns animate smoothly.
    var heading: Double = 0
    var penDown = true
    var penColor = RGB.black
    var fillColor = RGB.black
    var width: Double = 1
    var visible = true

    init(position: Point = .zero, heading: Double = 0) {
        self.position = position
        self.heading = heading
    }
}

/// Everything Shelly does, in order, so the canvas can replay it as an animation.
nonisolated enum TurtleEvent: Equatable, Sendable {
    case move(from: Point, to: Point, pen: Pen?)
    case turn(from: Double, to: Double)
    case dot(at: Point, size: Double, color: RGB)
    case fill([Point], RGB)
    case write(String, at: Point, color: RGB)
    case background(RGB)
    case visibility(Bool)
    case print(String)
}

/// The finished picture after some number of events, used for checking levels.
nonisolated struct Drawing: Sendable {
    var segments: [(Point, Point)] = []
    var path: [(Point, Point)] = []

    init(_ events: some Sequence<TurtleEvent>) {
        for event in events {
            if case .move(let from, let to, let pen) = event {
                path.append((from, to))
                if pen != nil, from != to { segments.append((from, to)) }
            }
        }
    }

    /// True if every part of `target` lies within `tolerance` of a line in `drawn`.
    static func covers(_ drawn: [(Point, Point)], _ target: [(Point, Point)], tolerance: Double = 6) -> Bool {
        for (a, b) in target {
            let length = a.distance(to: b)
            let steps = max(1, Int(length / 4))
            for step in 0...steps {
                let p = a.interpolated(to: b, Double(step) / Double(steps))
                if !drawn.contains(where: { p.distance(toSegment: $0.0, $0.1) <= tolerance }) {
                    return false
                }
            }
        }
        return true
    }
}
