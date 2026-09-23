import AppKit

// Monerochan desktop companion. Self-contained: create one, call start()/stop().

enum MCMode { case walk, run, idle, jump, dance, wave, coin, combo, backflip, glitchOut, glitchIn, ninja, laser, coinPunch, pump, shuffle, superbrain }

final class MCSprite: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var angle: CGFloat = 0
    var glitch: CGFloat = 0
    var alpha: CGFloat = 1
    var spriteRect = NSRect.zero
    var onClick: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var menuProvider: (() -> NSMenu)?
    var dragStart: NSPoint?; var dragged = false
    // aimable arm overlay (gun), rotated about a shoulder pivot in view coords
    var overlay: NSImage?; var overlayAngle: CGFloat = 0; var overlayPivot = NSPoint.zero
    var pivot: NSPoint? = nil; var drawOffset = CGPoint.zero
    // "in love with the coin": enlarged eyes + sparkles
    var love = false, loveT = 0
    var eyeSrc: [NSRect] = [], eyeDst: [NSPoint] = [], coinPt = NSPoint.zero, heartPt = NSPoint.zero

    override func draw(_ r: NSRect) {
        guard let img = image, let ctx = NSGraphicsContext.current else { return }
        ctx.imageInterpolation = .none
        let cg = ctx.cgContext
        cg.saveGState()
        let pv = pivot ?? NSPoint(x: spriteRect.midX, y: spriteRect.midY)
        cg.translateBy(x: pv.x, y: pv.y)
        cg.rotate(by: angle * .pi / 180)
        cg.translateBy(x: -pv.x, y: -pv.y)
        cg.translateBy(x: drawOffset.x, y: drawOffset.y)
        if glitch <= 0 { img.draw(in: spriteRect, from: .zero, operation: .sourceOver, fraction: alpha) }
        else { drawGlitch(img, cg) }
        if let ov = overlay {
            cg.saveGState()
            cg.translateBy(x: overlayPivot.x, y: overlayPivot.y)
            cg.rotate(by: overlayAngle * .pi / 180)
            cg.translateBy(x: -overlayPivot.x, y: -overlayPivot.y)
            ov.draw(in: spriteRect, from: .zero, operation: .sourceOver, fraction: alpha)
            cg.restoreGState()
        }
        if love { drawLove(img, cg) }
        cg.restoreGState()
    }

    func star(_ cg: CGContext, _ c: NSPoint, _ r: CGFloat, _ col: NSColor) {
        cg.setFillColor(col.cgColor)
        cg.move(to: CGPoint(x: c.x, y: c.y + r))
        cg.addLine(to: CGPoint(x: c.x + r * 0.22, y: c.y + r * 0.22)); cg.addLine(to: CGPoint(x: c.x + r, y: c.y))
        cg.addLine(to: CGPoint(x: c.x + r * 0.22, y: c.y - r * 0.22)); cg.addLine(to: CGPoint(x: c.x, y: c.y - r))
        cg.addLine(to: CGPoint(x: c.x - r * 0.22, y: c.y - r * 0.22)); cg.addLine(to: CGPoint(x: c.x - r, y: c.y))
        cg.addLine(to: CGPoint(x: c.x - r * 0.22, y: c.y + r * 0.22)); cg.closePath(); cg.fillPath()
    }

    func heart(_ cg: CGContext, _ c: NSPoint, _ s: CGFloat, _ a: CGFloat) {
        cg.setFillColor(NSColor(calibratedRed: 1, green: 0.3, blue: 0.55, alpha: a).cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - s, y: c.y - s * 0.1, width: s * 1.1, height: s * 1.1))
        cg.fillEllipse(in: CGRect(x: c.x - s * 0.1, y: c.y - s * 0.1, width: s * 1.1, height: s * 1.1))
        cg.move(to: CGPoint(x: c.x - s * 0.95, y: c.y + s * 0.3)); cg.addLine(to: CGPoint(x: c.x + s * 0.95, y: c.y + s * 0.3))
        cg.addLine(to: CGPoint(x: c.x, y: c.y - s * 1.05)); cg.closePath(); cg.fillPath()
    }

    func drawLove(_ img: NSImage, _ cg: CGContext) {
        let t = CGFloat(loveT)
        // eyes grow in, then pulse gently
        let grow = min(1, t / 10) * (1.55 + 0.1 * sin(t * 0.35))
        for (src, dst) in zip(eyeSrc, eyeDst) {
            let w = src.width * (spriteRect.width / img.size.width) * grow
            let h = src.height * (spriteRect.height / img.size.height) * grow
            img.draw(in: NSRect(x: dst.x - w / 2, y: dst.y - h / 2, width: w, height: h), from: src, operation: .sourceOver, fraction: alpha)
            // big shiny anime highlights
            let hr = 2.2 * grow
            cg.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            cg.fillEllipse(in: CGRect(x: dst.x - w * 0.28 - hr / 2, y: dst.y + h * 0.12, width: hr, height: hr))
            cg.fillEllipse(in: CGRect(x: dst.x + w * 0.1, y: dst.y - h * 0.2, width: hr * 0.6, height: hr * 0.6))
        }
        // twinkling sparkles orbiting the coin
        for i in 0..<6 {
            let ph = t * 0.12 + CGFloat(i) * 1.047
            let rad = 20 + 5 * sin(t * 0.2 + CGFloat(i))
            let p = NSPoint(x: coinPt.x + cos(ph) * rad, y: coinPt.y + sin(ph) * rad)
            let tw = max(0, sin(t * 0.4 + CGFloat(i) * 1.7))
            star(cg, p, 2 + 4 * tw, NSColor(calibratedRed: 1, green: 0.92, blue: 0.5, alpha: 0.35 + 0.65 * tw))
        }
        // little hearts floating up from her head
        for i in 0..<3 {
            let life: CGFloat = 45
            let age = (t + CGFloat(i) * 15).truncatingRemainder(dividingBy: life)
            let p = NSPoint(x: heartPt.x + sin(age * 0.2 + CGFloat(i)) * 7 + CGFloat(i - 1) * 10, y: heartPt.y + age * 0.9)
            heart(cg, p, 4.5, max(0, 1 - age / life))
        }
    }

    func drawGlitch(_ img: NSImage, _ cg: CGContext) {
        let g = glitch, rect = spriteRect
        let split = 3 + g * 14
        for (dx, color) in [(-split, NSColor(calibratedRed: 1, green: 0, blue: 0.35, alpha: 1)),
                            (split, NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1))] {
            tint(img, color).draw(in: rect.offsetBy(dx: dx * CGFloat.random(in: 0.6...1.2), dy: 0),
                                  from: .zero, operation: .sourceOver, fraction: 0.55 * alpha)
        }
        let slices = 14, src = img.size
        for i in 0..<slices {
            let t0 = CGFloat(i) / CGFloat(slices), t1 = CGFloat(i + 1) / CGFloat(slices)
            if CGFloat.random(in: 0...1) < g * 0.35 { continue }
            let shift = CGFloat.random(in: 0...1) < g * 0.6 ? CGFloat.random(in: -1...1) * g * 40 : 0
            let from = NSRect(x: 0, y: src.height * t0, width: src.width, height: src.height * (t1 - t0))
            let to = NSRect(x: rect.minX + shift, y: rect.minY + rect.height * t0, width: rect.width, height: rect.height * (t1 - t0))
            img.draw(in: to, from: from, operation: .sourceOver, fraction: alpha)
        }
        for _ in 0..<Int(g * 18) {
            let w = CGFloat.random(in: 4...26), h = CGFloat.random(in: 2...6)
            let bx = rect.minX + CGFloat.random(in: -20...rect.width), by = rect.minY + CGFloat.random(in: 0...rect.height)
            let c = [NSColor.orange, NSColor.cyan, NSColor.white, NSColor.magenta].randomElement()!
            cg.setFillColor(c.withAlphaComponent(0.8 * alpha).cgColor)
            cg.fill(CGRect(x: bx, y: by, width: w, height: h))
        }
        cg.setFillColor(NSColor.black.withAlphaComponent(0.25 * g).cgColor)
        var yy = rect.minY
        while yy < rect.maxY { cg.fill(CGRect(x: rect.minX - 30, y: yy, width: rect.width + 60, height: 1)); yy += 3 }
    }

    var tintCache: [ObjectIdentifier: [NSColor: NSImage]] = [:]
    func tint(_ img: NSImage, _ c: NSColor) -> NSImage {
        let k = ObjectIdentifier(img)
        if let t = tintCache[k]?[c] { return t }
        let out = NSImage(size: img.size)
        out.lockFocus()
        img.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        c.set(); NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop)
        out.unlockFocus()
        tintCache[k, default: [:]][c] = out
        return out
    }

    override func hitTest(_ p: NSPoint) -> NSView? { spriteRect.contains(convert(p, from: superview)) && alpha > 0.2 ? self : nil }
    override func mouseDown(with e: NSEvent) { dragStart = NSEvent.mouseLocation; dragged = false }
    override func mouseDragged(with e: NSEvent) {
        guard let s = dragStart else { return }
        let m = NSEvent.mouseLocation
        if abs(m.x - s.x) + abs(m.y - s.y) > 4 { dragged = true }
        if dragged { onDrag?(NSPoint(x: m.x - s.x, y: m.y - s.y)); dragStart = m }
    }
    override func mouseUp(with e: NSEvent) { if !dragged { onClick?() } }
    override func rightMouseDown(with e: NSEvent) {
        if let m = menuProvider?() { NSMenu.popUpContextMenu(m, with: e, for: self) }
    }
}

final class MCClickView: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with e: NSEvent) {}
    override func mouseUp(with e: NSEvent) { onClick?() }
    override func hitTest(_ p: NSPoint) -> NSView? { frame.contains(p) ? self : nil }
}

// Full-screen click-through overlay that draws laser beams and sparks.
final class MCLaserView: NSView {
    struct Beam { var from: NSPoint; var to: NSPoint; var age: Int; var life: Int }
    struct Spark { var p: NSPoint; var v: NSPoint; var age: Int; var life: Int }
    struct Puff { var p: NSPoint; var age: Int; var life: Int }
    struct Coin { var p: NSPoint; var v: NSPoint; var age: Int; var life: Int; var spin: CGFloat }
    struct Candle { var x: CGFloat; var base: CGFloat; var h: CGFloat; var target: CGFloat; var wick: CGFloat; var age: Int; var life: Int; var green: Bool }
    var beams: [Beam] = [], sparks: [Spark] = [], puffs: [Puff] = [], coins: [Coin] = [], candles: [Candle] = []
    var chartLabel: (String, NSPoint, Int)? = nil
    var isEmpty: Bool { beams.isEmpty && sparks.isEmpty && puffs.isEmpty && coins.isEmpty && candles.isEmpty && sbEmpty }
    var floorY: CGFloat = 0

    // Superbrain: neon logo hovering above her, RandomX "hash rain" falling onto her
    struct Drop { var x: CGFloat; var y: CGFloat; var speed: CGFloat; var len: Int; var chars: [Character]; var age: Int; var orange: Bool; var floor: CGFloat; var top: CGFloat; var splash: Bool; var hit: Bool }
    struct Splat { var p: NSPoint; var v: NSPoint; var ch: Character; var age: Int; var life: Int; var orange: Bool }
    var splats: [Splat] = []
    var splashCount = 0
    var bodyTop: ((CGFloat) -> CGFloat?)?
    var sbLogos: [NSImage] = []
    var sbCenter = NSPoint.zero, sbAlpha: CGFloat = 0, sbT = 0, sbActive = false
    var sbTargetY: CGFloat = 0, sbFloorY: CGFloat = 0, sbWidth: CGFloat = 110
    var sbLogoW: CGFloat { (sbWidth + 14) * 144 / 96 }       // brain width == rain width
    var sbK: CGFloat { sbLogoW / 138 }                        // scale vs the original layout
    var drops: [Drop] = []
    var hashLine = "", hashRate = 0
    static let glyphs = Array("0123456789abcdefｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜɱ")
    var glyphFont: NSFont = NSFont(name: "Matrix", size: 13) ?? .monospacedSystemFont(ofSize: 12, weight: .bold)
    var sbEmpty: Bool { !sbActive && drops.isEmpty && splats.isEmpty && sbAlpha <= 0 }

    func stepSuperbrain() {
        guard sbActive || !drops.isEmpty || sbAlpha > 0 else { return }
        sbT += 1
        if sbActive { sbAlpha = min(1, sbAlpha + 0.06) } else { sbAlpha = max(0, sbAlpha - 0.05) }
        // logo floats down into place and bobs
        sbCenter.y += (sbTargetY + sin(CGFloat(sbT) * 0.06) * 6 - sbCenter.y) * 0.12
        if sbActive && sbT > 12 {
            for _ in 0..<2 {
                let x = sbCenter.x + CGFloat.random(in: -sbWidth / 2...sbWidth / 2)
                let gx = (x / 11).rounded() * 11
                // brain underside: two rounded lobes, higher at the outer edges and the centre fissure
                let u = max(-1, min(1, (gx - sbCenter.x) / (sbWidth / 2)))
                let lobe = 1 - pow(abs(abs(u) - 0.5) / 0.5, 2)            // 1 at lobe bottoms, 0 at edges/centre
                let top = sbCenter.y - (18 + lobe * 26) * sbK + CGFloat.random(in: -5...5)
                drops.append(Drop(x: gx, y: top, speed: CGFloat.random(in: 4...8),
                                  len: Int.random(in: 5...12), chars: (0..<14).map { _ in Self.glyphs.randomElement()! },
                                  age: 0, orange: Int.random(in: 0..<7) == 0,
                                  floor: sbFloorY + CGFloat.random(in: 0...40) * CGFloat.random(in: 0...1), top: top, splash: Int.random(in: 0..<3) == 0, hit: false))
            }
        }
        for i in drops.indices {
            drops[i].y -= drops[i].speed; drops[i].age += 1
            if drops[i].age % 3 == 0 { drops[i].chars[Int.random(in: 0..<drops[i].chars.count)] = Self.glyphs.randomElement()! }
        }
        for i in drops.indices where drops[i].splash && !drops[i].hit {
            if let top = bodyTop?(drops[i].x), drops[i].y <= top, drops[i].y > top - 14 {
                drops[i].hit = true
                drops[i].floor = top                      // the stream drains into her
                let n = Int.random(in: 2...4)
                splashCount += 1
                for _ in 0..<n {
                    splats.append(Splat(p: NSPoint(x: drops[i].x, y: top + 2),
                        v: NSPoint(x: CGFloat.random(in: -2.6...2.6), y: CGFloat.random(in: 1.8...4.2)),
                        ch: Self.glyphs.randomElement()!, age: 0, life: Int.random(in: 16...26), orange: drops[i].orange))
                }
            }
        }
        for i in splats.indices { splats[i].p.x += splats[i].v.x; splats[i].p.y += splats[i].v.y; splats[i].v.y -= 0.45; splats[i].age += 1 }
        splats.removeAll { $0.age >= $0.life }
        drops.removeAll { $0.y + CGFloat($0.len) * 13 < $0.floor }
        if sbActive && sbT % 4 == 0 {
            hashLine = String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
            hashRate = Int.random(in: 11800...12600)
        }
    }

    func drawSuperbrain(_ cg: CGContext) {
        guard sbAlpha > 0 || !drops.isEmpty else { return }
        // rain
        for d in drops {
            for k in 0..<d.len {
                let py = d.y + CGFloat(k) * 13
                if py < d.floor || py > d.top { continue }
                let emerge = min(1, (d.top - py) / 20)   // fade in as it leaves the brain
                let groundFade = min(1, (py - d.floor) / 45)
                let p = convert(window!.convertPoint(fromScreen: NSPoint(x: d.x, y: py)), from: nil)
                let head = k == 0 && d.y > d.floor + 4
                let fade = 1 - CGFloat(k) / CGFloat(d.len)
                let col: NSColor = head ? NSColor(calibratedRed: 0.85, green: 1, blue: 0.9, alpha: 1)
                    : (d.orange ? NSColor(calibratedRed: 1, green: 0.45, blue: 0.05, alpha: fade)
                                : NSColor(calibratedRed: 0.1, green: 1, blue: 0.45, alpha: fade * 0.9))
                var attrs: [NSAttributedString.Key: Any] = [.font: glyphFont, .foregroundColor: col.withAlphaComponent(col.alphaComponent * groundFade * emerge)]
                if head {
                    let sh = NSShadow(); sh.shadowColor = NSColor(calibratedRed: 0.2, green: 1, blue: 0.5, alpha: 1); sh.shadowBlurRadius = 8
                    attrs[.shadow] = sh
                }
                (String(d.chars[k % d.chars.count]) as NSString).draw(at: NSPoint(x: p.x - 4, y: p.y), withAttributes: attrs)
            }
        }
        let sf = NSFont(name: "Matrix", size: 12) ?? .monospacedSystemFont(ofSize: 11, weight: .bold)
        for sp in splats {
            let t = CGFloat(sp.age) / CGFloat(sp.life)
            let p = convert(window!.convertPoint(fromScreen: sp.p), from: nil)
            if sp.age < 3 {                                  // tiny impact flash
                cg.setFillColor(NSColor(calibratedRed: 0.7, green: 1, blue: 0.8, alpha: 0.5 * (1 - CGFloat(sp.age) / 3)).cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
            }
            let col = sp.orange ? NSColor(calibratedRed: 1, green: 0.5, blue: 0.1, alpha: 0.85 * (1 - t))
                                : NSColor(calibratedRed: 0.4, green: 1, blue: 0.6, alpha: 0.85 * (1 - t))
            (String(sp.ch) as NSString).draw(at: NSPoint(x: p.x - 3, y: p.y), withAttributes: [.font: sf, .foregroundColor: col])
        }
        guard sbAlpha > 0, !sbLogos.isEmpty else { return }
        let img = sbLogos[(sbT / 5) % sbLogos.count]
        let c = convert(window!.convertPoint(fromScreen: sbCenter), from: nil)
        let w: CGFloat = sbLogoW, h = w * img.size.height / img.size.width
        // pulsing neon halo
        let pulse = 0.5 + 0.5 * sin(CGFloat(sbT) * 0.15)
        // feathered aura: radial gradients that fade smoothly to nothing (no hard ring edges)
        let space = CGColorSpaceCreateDeviceRGB()
        for (r, rgb, peak) in [(96.0, (1.0, 0.2, 0.8), 0.16), (70.0, (0.0, 1.0, 0.7), 0.18)] {
            let rr = CGFloat(r) * sbK * (1 + 0.08 * pulse)
            let a0 = CGFloat(peak) * sbAlpha
            let cols = [0.0, 0.35, 0.7, 1.0].map { t -> CGColor in
                let fall = pow(1 - CGFloat(t), 2.2)
                return CGColor(colorSpace: space, components: [rgb.0, rgb.1, rgb.2, a0 * fall])!
            }
            guard let g = CGGradient(colorsSpace: space, colors: cols as CFArray, locations: [0, 0.35, 0.7, 1]) else { continue }
            cg.saveGState()
            cg.translateBy(x: c.x, y: c.y); cg.scaleBy(x: 1, y: 0.82)
            cg.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: rr, options: [])
            cg.restoreGState()
        }
        // occasional glitch jitter
        let jit: CGFloat = sbT % 37 < 2 ? CGFloat.random(in: -4...4) : 0
        img.draw(in: NSRect(x: c.x - w / 2 + jit, y: c.y - h / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: sbAlpha)
        // RandomX readout
        if sbActive && sbT > 20 {
            let f = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
            let a1: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: NSColor(calibratedRed: 0.2, green: 1, blue: 0.55, alpha: sbAlpha)]
            let a2: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: NSColor(calibratedRed: 1, green: 0.5, blue: 0.1, alpha: sbAlpha)]
            ("RandomX  \(hashRate) H/s" as NSString).draw(at: NSPoint(x: c.x + w / 2 - 24 * sbK, y: c.y + 8), withAttributes: a2)
            (String(hashLine.prefix(12)) + "…" + String(hashLine.suffix(8)) as NSString).draw(at: NSPoint(x: c.x + w / 2 - 24 * sbK, y: c.y - 6), withAttributes: a1)
        }
    }

    func step() {
        for i in beams.indices { beams[i].age += 1 }
        for b in beams where b.age < b.life && b.age % 2 == 0 {
            for _ in 0..<3 {
                sparks.append(Spark(p: b.to, v: NSPoint(x: CGFloat.random(in: -6...6) + (b.to.x > b.from.x ? -3 : 3), y: CGFloat.random(in: -2...8)),
                                    age: 0, life: Int.random(in: 10...22)))
            }
        }
        beams.removeAll { $0.age >= $0.life }
        for i in sparks.indices { sparks[i].p.x += sparks[i].v.x; sparks[i].p.y += sparks[i].v.y; sparks[i].v.y -= 0.6; sparks[i].age += 1 }
        sparks.removeAll { $0.age >= $0.life }
        for i in puffs.indices { puffs[i].age += 1; puffs[i].p.y += 1.2; puffs[i].p.x += CGFloat.random(in: -0.6...0.6) }
        puffs.removeAll { $0.age >= $0.life }
        for i in coins.indices {
            coins[i].p.x += coins[i].v.x; coins[i].p.y += coins[i].v.y
            coins[i].v.y -= 0.55; coins[i].spin += 0.35; coins[i].age += 1
            if coins[i].p.y < floorY + 6 && coins[i].v.y < 0 {           // bounce on the dock line
                coins[i].p.y = floorY + 6; coins[i].v.y *= -0.45; coins[i].v.x *= 0.7
            }
        }
        coins.removeAll { $0.age >= $0.life }
        for i in candles.indices {
            candles[i].age += 1
            candles[i].h += (candles[i].target - candles[i].h) * 0.25
        }
        candles.removeAll { $0.age >= $0.life }
        if let l = chartLabel { chartLabel = l.2 <= 0 ? nil : (l.0, l.1, l.2 - 1) }
        stepSuperbrain()
        needsDisplay = true
    }

    func drawCoin(_ cg: CGContext, _ c: Coin) {
        let p = convert(window!.convertPoint(fromScreen: c.p), from: nil)
        let a = c.age > c.life - 12 ? CGFloat(c.life - c.age) / 12 : 1
        let r: CGFloat = 13, sx = max(0.15, abs(cos(c.spin)))
        cg.saveGState()
        cg.translateBy(x: p.x, y: p.y); cg.scaleBy(x: sx, y: 1)
        cg.setFillColor(NSColor(calibratedRed: 1, green: 0.4, blue: 0, alpha: a).cgColor)
        cg.fillEllipse(in: CGRect(x: -r, y: -r, width: 2*r, height: 2*r))
        cg.setStrokeColor(NSColor(calibratedWhite: 0.25, alpha: a).cgColor); cg.setLineWidth(2)
        cg.strokeEllipse(in: CGRect(x: -r, y: -r, width: 2*r, height: 2*r))
        // Monero "M": white M on the upper part, grey band at the bottom
        cg.setFillColor(NSColor(calibratedWhite: 0.3, alpha: a).cgColor)
        cg.fill(CGRect(x: -r*0.85, y: -r*0.62, width: r*1.7, height: r*0.32))
        cg.setStrokeColor(NSColor.white.withAlphaComponent(a).cgColor); cg.setLineWidth(2.6)
        cg.setLineJoin(.miter)
        cg.move(to: CGPoint(x: -r*0.55, y: -r*0.3)); cg.addLine(to: CGPoint(x: -r*0.55, y: r*0.5))
        cg.addLine(to: CGPoint(x: 0, y: -r*0.05)); cg.addLine(to: CGPoint(x: r*0.55, y: r*0.5))
        cg.addLine(to: CGPoint(x: r*0.55, y: -r*0.3)); cg.strokePath()
        cg.restoreGState()
    }

    func drawCandle(_ cg: CGContext, _ c: Candle) {
        let a = c.age > c.life - 20 ? CGFloat(c.life - c.age) / 20 : 1
        let bl = convert(window!.convertPoint(fromScreen: NSPoint(x: c.x, y: c.base)), from: nil)
        let w: CGFloat = 20
        let col = c.green ? NSColor(calibratedRed: 0.1, green: 0.95, blue: 0.35, alpha: a)
                          : NSColor(calibratedRed: 1, green: 0.25, blue: 0.3, alpha: a)
        // glow
        cg.setFillColor(col.withAlphaComponent(0.18 * a).cgColor)
        cg.fill(CGRect(x: bl.x - 5, y: bl.y - 5, width: w + 10, height: c.h + 10))
        // wick
        cg.setStrokeColor(col.cgColor); cg.setLineWidth(2)
        cg.move(to: CGPoint(x: bl.x + w/2, y: bl.y - c.wick * 0.4)); cg.addLine(to: CGPoint(x: bl.x + w/2, y: bl.y + c.h + c.wick)); cg.strokePath()
        // body
        cg.setFillColor(col.cgColor)
        cg.fill(CGRect(x: bl.x, y: bl.y, width: w, height: c.h))
        cg.setStrokeColor(NSColor.black.withAlphaComponent(0.5 * a).cgColor); cg.setLineWidth(1)
        cg.stroke(CGRect(x: bl.x, y: bl.y, width: w, height: c.h))
    }

    override func draw(_ r: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        drawSuperbrain(cg)
        for c in candles { drawCandle(cg, c) }
        if candles.count > 1 {           // trend line through the closes
            cg.setStrokeColor(NSColor(calibratedRed: 0.4, green: 1, blue: 0.5, alpha: 0.6).cgColor)
            cg.setLineWidth(2); cg.setLineDash(phase: 0, lengths: [6, 4])
            for (i, c) in candles.enumerated() {
                let p = convert(window!.convertPoint(fromScreen: NSPoint(x: c.x + 10, y: c.base + c.h)), from: nil)
                if i == 0 { cg.move(to: p) } else { cg.addLine(to: p) }
            }
            cg.strokePath(); cg.setLineDash(phase: 0, lengths: [])
        }
        if let (text, pt, _) = chartLabel {
            let p = convert(window!.convertPoint(fromScreen: pt), from: nil)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .heavy),
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 1, blue: 0.4, alpha: 1),
                .strokeColor: NSColor.black, .strokeWidth: -3]
            (text as NSString).draw(at: p, withAttributes: attrs)
        }
        for c in coins { drawCoin(cg, c) }
        for s in puffs {
            let t = CGFloat(s.age) / CGFloat(s.life)
            let p = convert(window!.convertPoint(fromScreen: s.p), from: nil)
            let rr = 4 + t * 12
            cg.setFillColor(NSColor(white: 0.85, alpha: 0.55 * (1 - t)).cgColor)
            cg.fillEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2))
        }
        cg.setLineCap(.round)
        for b in beams {
            let t = CGFloat(b.age) / CGFloat(b.life)
            let fade = t < 0.75 ? 1 : (1 - t) / 0.25
            let flick = CGFloat.random(in: 0.8...1.15)
            let from = convert(window!.convertPoint(fromScreen: b.from), from: nil)
            let to = convert(window!.convertPoint(fromScreen: b.to), from: nil)
            for (w, c) in [(26.0, NSColor(calibratedRed: 1, green: 0.35, blue: 0, alpha: 0.18)),
                           (14.0, NSColor(calibratedRed: 1, green: 0.45, blue: 0, alpha: 0.45)),
                           (6.0, NSColor(calibratedRed: 1, green: 0.75, blue: 0.3, alpha: 0.9)),
                           (2.5, NSColor.white)] {
                cg.setStrokeColor(c.withAlphaComponent(c.alphaComponent * fade).cgColor)
                cg.setLineWidth(CGFloat(w) * flick)
                cg.move(to: from); cg.addLine(to: to); cg.strokePath()
            }
            // muzzle and impact glow
            for (p, rad) in [(from, 18.0), (to, 26.0)] {
                cg.setFillColor(NSColor(calibratedRed: 1, green: 0.6, blue: 0.1, alpha: 0.55 * fade).cgColor)
                let rr = CGFloat(rad) * flick
                cg.fillEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2))
                cg.setFillColor(NSColor.white.withAlphaComponent(0.9 * fade).cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - rr / 3, y: p.y - rr / 3, width: rr / 1.5, height: rr / 1.5))
            }
        }
        for s in sparks {
            let a = 1 - CGFloat(s.age) / CGFloat(s.life)
            let p = convert(window!.convertPoint(fromScreen: s.p), from: nil)
            cg.setFillColor((s.age % 3 == 0 ? NSColor.white : NSColor.orange).withAlphaComponent(a).cgColor)
            cg.fill(CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
        }
    }
    override func hitTest(_ p: NSPoint) -> NSView? { nil }
}

final class MoneroChanCompanion: NSObject {
    let framesDir: URL
    var onTurnOff: (() -> Void)?        // host decides what "turn off" means
    var turnOffTitle = "Turn off Monerochan"
    private(set) var running = false

    let size: CGFloat = 128
    let pad: CGFloat = 70
    var win: NSWindow!, sprite = MCSprite()
    var laserWin: NSWindow?, laserView = MCLaserView()
    var timers: [Timer] = []
    var panel: NSPanel?, label = NSTextField(labelWithString: "Loading Monero stats…")
    var frames: [String: NSImage] = [:], framesL: [String: NSImage] = [:]
    var x: CGFloat = 200, y: CGFloat = 0, groundY: CGFloat = 0, vy: CGFloat = 0
    var dir: CGFloat = 1, mode: MCMode = .walk, modeTime = 0.0, tick = 0, statsText = ""
    var modeTick = 0, combo: [(String, Int, CGFloat)] = [], comboIdx = 0, comboLeft = 0
    var targetX: CGFloat = 0, targetGround: CGFloat = 0
    var hasFight = false, hasNinja = false, hasGun = false
    var walkFrames = ["walk0", "walk1", "walk2", "walk3"]
    var walkPhase: CGFloat = 0
    var ninjaMove = 0, shots = 0, landTick = 0, ninjaPhase = 0
    var laserFan = false
    var shuffleFrames: [String] = []

    init(framesDir: URL) { self.framesDir = framesDir; super.init() }

    static func flipped(_ img: NSImage) -> NSImage {
        let out = NSImage(size: img.size)
        out.lockFocus()
        let t = NSAffineTransform(); t.translateX(by: img.size.width, yBy: 0); t.scaleX(by: -1, yBy: 1); t.concat()
        img.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }

    var screen: NSRect { (NSScreen.main ?? NSScreen.screens[0]).visibleFrame }

    func loadFrames() {
        guard frames.isEmpty else { return }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: framesDir.path)) ?? []
        for f in names where f.hasSuffix(".png") {
            let n = String(f.dropLast(4))
            if let img = NSImage(contentsOf: framesDir.appendingPathComponent(f)) { frames[n] = img; framesL[n] = Self.flipped(img) }
        }
        hasFight = frames["stance"] != nil
        hasNinja = frames["nj_tornado"] != nil
        hasGun = frames["gun_fire"] != nil
        if frames["walkB0"] != nil { walkFrames = ["walkB0", "walkB1", "walkB2", "walkB3"] }
        if frames["wk7"] != nil { walkFrames = (0..<8).map { "wk\($0)" } }
        if frames["sh7"] != nil { shuffleFrames = (0..<8).map { "sh\($0)" } }
        if let d = try? Data(contentsOf: framesDir.appendingPathComponent("meta.json")),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            func pt(_ v: Any?) -> NSPoint? { (v as? [NSNumber]).map { NSPoint(x: $0[0].doubleValue, y: $0[1].doubleValue) } }
            if let p = pt(j["gun_pivot"]) { gunPivot = p }
            if let p = pt(j["gun_muzzle"]) { gunMuzzle = p }
            if let p = pt(j["fire_muzzle"]) { fireMuzzle = p }
            if let p = pt(j["coin_center"]) { coinCenter = p }
            if let e = j["eyes"] as? [Any] { eyes = e.compactMap { pt($0) } }
        }
        hasRig = frames["gun_arm"] != nil && frames["gun_body"] != nil
        sbLogoFrames = (0..<4).compactMap { frames["sb_logo\($0)"] }
        hasSB = !sbLogoFrames.isEmpty
        hasBliss = frames["bl2"] != nil
    }

    // rig data, in 160-px frame coords (y down)
    var gunPivot = NSPoint(x: 79, y: 76), gunMuzzle = NSPoint(x: 131, y: 70), fireMuzzle = NSPoint(x: 128, y: 71)
    var coinCenter = NSPoint(x: 44, y: 68), eyes: [NSPoint] = []
    var hasRig = false, pendingPump = false
    var hasSB = false, hasBliss = false, sbLogoFrames: [NSImage] = []
    var aimDeg: CGFloat = 0
    var armRest: CGFloat { atan2(gunPivot.y - gunMuzzle.y, gunMuzzle.x - gunPivot.x) * 180 / .pi }

    /// frame px (y down) -> sprite view coords, honoring facing
    func toView(_ p: NSPoint) -> NSPoint {
        let k = size / 160
        return NSPoint(x: pad + (dir > 0 ? p.x : 160 - p.x) * k, y: (160 - p.y) * k)
    }

    /// world-space muzzle when the arm points along `deg` (0 = level, + = up)
    func muzzleWorld(_ deg: CGFloat) -> NSPoint {
        let k = size / 160
        let r = (deg - armRest) * .pi / 180
        let dx = (gunMuzzle.x - gunPivot.x) * k, dy = (gunPivot.y - gunMuzzle.y) * k
        let rx = dx * cos(r) - dy * sin(r), ry = dx * sin(r) + dy * cos(r)
        let pv = toView(gunPivot)
        return NSPoint(x: x - pad + pv.x + rx * dir, y: y + pv.y + ry)
    }

    var currentFrame = "idle_front"
    var topCache: [String: [Int]] = [:]
    /// per-column topmost opaque row (y down) of a 160px frame, -1 if empty
    func columnTops(_ name: String) -> [Int] {
        if let c = topCache[name] { return c }
        var tops = [Int](repeating: -1, count: 160)
        if let img = frames[name], let cgi = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let ctx = CGContext(data: nil, width: 160, height: 160, bitsPerComponent: 8, bytesPerRow: 640,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cgi, in: CGRect(x: 0, y: 0, width: 160, height: 160))
            let px = ctx.data!.bindMemory(to: UInt8.self, capacity: 160 * 640)
            for xx in 0..<160 {
                for yy in 0..<160 where px[yy * 640 + xx * 4 + 3] > 60 { tops[xx] = yy; break }
            }
        }
        topCache[name] = tops
        return tops
    }
    var centerCache: [String: NSPoint] = [:]
    /// centre of the opaque body in a 160px frame (x right, y down)
    func bodyCenter(_ name: String) -> NSPoint {
        if let c = centerCache[name] { return c }
        let tops = columnTops(name)
        let cols = tops.indices.filter { tops[$0] >= 0 }
        var c = NSPoint(x: 80, y: 90)
        if let a = cols.first, let b = cols.last {
            let top = cols.map { tops[$0] }.min() ?? 0
            c = NSPoint(x: CGFloat(a + b) / 2, y: (CGFloat(top) + 158) / 2)
        }
        centerCache[name] = c
        return c
    }

    func bodyTopAt(_ wx: CGFloat) -> CGFloat? {
        let k = size / 160
        var fx = (wx - x) / k
        if dir < 0 { fx = 160 - fx }
        let xi = Int(fx)
        guard xi >= 0 && xi < 160 else { return nil }
        let t = columnTops(currentFrame)[xi]
        return t < 0 ? nil : y + (160 - CGFloat(t)) * k
    }

    func setAim(_ deg: CGFloat) {
        aimDeg = deg
        sprite.overlay = (dir < 0 ? framesL : frames)["gun_arm"]
        sprite.overlayPivot = toView(gunPivot)
        sprite.overlayAngle = (deg - armRest) * dir
    }

    func start() {
        guard !running else { return }
        running = true
        loadFrames()
        let vf = screen
        groundY = vf.minY; y = groundY; x = vf.midX
        let W = size + pad * 2
        if win == nil {
            win = NSWindow(contentRect: NSRect(x: x - pad, y: y, width: W, height: W), styleMask: .borderless, backing: .buffered, defer: false)
            win.isOpaque = false; win.backgroundColor = .clear; win.hasShadow = false
            win.level = .floating
            win.isReleasedWhenClosed = false
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            sprite.frame = NSRect(x: 0, y: 0, width: W, height: W)
            sprite.spriteRect = NSRect(x: pad, y: 0, width: size, height: size)
            sprite.onClick = { [weak self] in self?.togglePanel() }
            sprite.onDrag = { [weak self] d in
                guard let s = self else { return }
                s.x += d.x; s.groundY = max(s.screen.minY, s.groundY + d.y); s.y = s.groundY
            }
            sprite.menuProvider = { [weak self] in self?.contextMenu() ?? NSMenu() }
            win.contentView = sprite
        }
        win.orderFrontRegardless()
        pick()
        timers = [
            Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in self?.step() },
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.fetch() },
        ]
        fetch()
    }

    func stop() {
        guard running else { return }
        running = false
        timers.forEach { $0.invalidate() }; timers = []
        win?.orderOut(nil)
        panel?.orderOut(nil)
        laserView.beams = []; laserView.sparks = []; laserView.puffs = []
        laserView.coins = []; laserView.candles = []; laserView.chartLabel = nil
        laserView.sbActive = false; laserView.drops = []; laserView.splats = []; laserView.sbAlpha = 0
        laserWin?.orderOut(nil)
    }

    func contextMenu() -> NSMenu {
        let m = NSMenu()
        var items: [(String, Selector)] = [("Fight!", #selector(doCombo)), ("Backflip", #selector(doBackflip))]
        if hasNinja { items.append(("Ninja kicks", #selector(doNinja))) }
        if hasGun { items.append(("Laser gun", #selector(doLaser))); items.append(("Sun-ray laser fan", #selector(doLaserFan))) }
        if hasFight { items.append(("Coin punch", #selector(doCoinPunch))); items.append(("Pump the chart 📈", #selector(doPump))) }
        items.append(("Shuffle dance", #selector(doShuffle)))
        if hasSB { items.append(("Superbrain hash rain 🧠", #selector(doSuperbrain))) }
        items.append(("Glitch teleport", #selector(doGlitch)))
        for (t, sel) in items {
            let it = NSMenuItem(title: t, action: sel, keyEquivalent: ""); it.target = self; m.addItem(it)
        }
        m.addItem(.separator())
        let off = NSMenuItem(title: turnOffTitle, action: #selector(turnOff), keyEquivalent: ""); off.target = self
        m.addItem(off)
        return m
    }

    @objc func turnOff() { stop(); onTurnOff?() }

    func setMode(_ m: MCMode, _ t: Double) {
        if mode == .superbrain && m != .superbrain { laserView.sbActive = false }
        mode = m; modeTime = t; modeTick = 0; sprite.angle = 0; sprite.glitch = 0; sprite.alpha = 1
        sprite.overlay = nil; sprite.love = false
    }

    func pick() {
        guard groundY <= screen.minY + 1 || Int.random(in: 0..<2) == 0 else { standardPick(); return }
        let r = Int.random(in: 0..<100)
        if r >= 58 {
            switch r {
            case 58..<65: if hasFight { doCombo(); return }
            case 65..<71: if hasNinja { doNinja(); return }
            case 71..<75: if hasGun { doLaser(); return }
            case 75..<79: if hasGun { doLaserFan(); return }
            case 79..<83: if hasFight { doCoinPunch(); return }
            case 83..<87: if hasFight && groundY <= screen.minY + 1 { doPump(); return }
            case 87..<90: if hasFight { doBackflip(); return }
            case 90..<95: if hasSB && groundY <= screen.minY + 1 { doSuperbrain(); return }
            default: doGlitch(); return
            }
        }
        standardPick()
    }

    func standardPick() {
        let r = Int.random(in: 0..<100)
        if r < 14 { doShuffle(); return }
        let m: MCMode = r < 38 ? .walk : r < 56 ? .run : r < 68 ? .idle : r < 78 ? .jump : r < 88 ? .dance : r < 93 ? .wave : .coin
        setMode(m, m == .jump ? 99 : Double.random(in: 2.5...6))
        if m == .jump { vy = 14 }
        if Bool.random() && (m == .walk || m == .run) { dir = -dir }
    }

    @objc func doSuperbrain() {
        guard hasSB else { return }
        showLaserOverlay()
        let lv = laserView
        lv.sbLogos = sbLogoFrames
        let cx = x + size / 2
        lv.sbCenter = NSPoint(x: cx, y: y + size + 260)
        lv.sbTargetY = y + size + 165
        lv.sbFloorY = screen.minY
        lv.sbT = 0; lv.sbAlpha = 0; lv.sbActive = true
        lv.bodyTop = { [weak self] wx in self?.bodyTopAt(wx) }
        setMode(.superbrain, 99)
    }

    @objc func doShuffle() {
        if Bool.random() { dir = -dir }
        setMode(.shuffle, Double.random(in: 4...7))
    }

    @objc func doCoinPunch() {
        guard hasFight else { return }
        if Bool.random() { dir = -dir }
        setMode(.coinPunch, 99)
    }

    var pumpBaseY: CGFloat = 0, pumpX: CGFloat = 0, pumpCount = 0
    @objc func doPump() {
        guard hasFight else { return }
        // the chart only ever grows to the RIGHT. If there isn't room, glitch-teleport to the left side first.
        dir = 1
        if screen.maxX - (x + size) < 560 || groundY > screen.minY + 1 {
            pendingPump = true
            targetX = screen.minX + CGFloat.random(in: 20...220); targetGround = screen.minY
            setMode(.glitchOut, 99)
            return
        }
        pumpCount = 0
        pumpBaseY = groundY + 24
        pumpX = x + size + 14
        laserView.candles = []
        setMode(.pump, 99)
    }

    @objc func doLaserFan() {
        guard hasGun else { return }
        laserFan = true; shots = 1
        dir = (screen.maxX - (x + size)) > (x - screen.minX) ? 1 : -1
        setMode(.laser, 99)
    }

    func spawnCoins(_ n: Int, from p: NSPoint, power: CGFloat = 1) {
        showLaserOverlay()
        laserView.floorY = screen.minY
        for _ in 0..<n {
            laserView.coins.append(.init(p: p,
                v: NSPoint(x: dir * CGFloat.random(in: 3...11) * power, y: CGFloat.random(in: 4...13) * power),
                age: 0, life: Int.random(in: 70...110), spin: CGFloat.random(in: 0...6)))
        }
    }

    func pumpCandle() {
        showLaserOverlay()
        let vf = screen
        let last = laserView.candles.last
        let base = last.map { $0.base + $0.target - CGFloat.random(in: 4...14) } ?? pumpBaseY
        let red = pumpCount > 1 && Int.random(in: 0..<6) == 0     // the occasional tiny dip
        let h = red ? CGFloat.random(in: 10...20) : CGFloat.random(in: 28...62) * (1 + CGFloat(pumpCount) * 0.06)
        let cx = pumpX + CGFloat(pumpCount) * 28          // always rightward
        guard cx > vf.minX && cx < vf.maxX - 20 && base < vf.maxY - 60 else { return }
        let b = red ? base - h + 8 : base
        laserView.candles.append(.init(x: cx, base: b, h: 0, target: h, wick: CGFloat.random(in: 6...16),
                                       age: 0, life: 260, green: !red))
        pumpCount += 1
    }

    func fireFanRay(_ i: Int, of n: Int) {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).frame
        showLaserOverlay()
        // fan from just below horizontal to almost straight up, like sun rays; beam leaves the actual muzzle
        let deg = -6 + CGFloat(i) / CGFloat(max(1, n - 1)) * 84
        let muzzle = hasRig ? muzzleWorld(deg) : NSPoint(x: dir > 0 ? x + size * 0.92 : x + size * 0.08, y: y + size * 0.58)
        let a = deg * .pi / 180
        let len = hypot(vf.width, vf.height)
        let end = NSPoint(x: muzzle.x + cos(a) * len * dir, y: muzzle.y + sin(a) * len)
        laserView.beams.append(.init(from: muzzle, to: end, age: 0, life: (n - i) * 4 + 10))
    }

    @objc func doCombo() {
        guard hasFight else { return }
        let combos: [[(String, Int, CGFloat)]] = [
            [("stance",12,0),("jab",5,1),("stance",3,0),("jab",5,1),("punch",8,2.5),("stance",6,0),("uppercut",12,0.5),("victory",24,0)],
            [("stance",10,0),("fkick",8,2),("stance",4,0),("hkick",10,1),("spin",12,3),("spin",6,3),("stance",8,0),("victory",22,0)],
            [("stance",10,0),("crouch",8,0),("sweep",12,2),("crouch",6,0),("uppercut",10,0),("palm",18,1.5),("stance",8,0)],
            [("stance",8,0),("crouch",8,0),("flykick",24,7),("stance",6,0),("punch",8,2),("jab",5,1),("victory",24,0)],
        ]
        combo = combos.randomElement()!
        comboIdx = 0; comboLeft = combo[0].1
        if Bool.random() { dir = -dir }
        setMode(.combo, 99)
    }

    @objc func doBackflip() { guard hasFight else { doGlitch(); return }; setMode(.backflip, 99); vy = 0 }

    // 0 = tornado kick, 1 = dive kick, 2 = split kick, 3 = wall run + flip off
    @objc func doNinja() {
        guard hasNinja else { return }
        ninjaMove = Int.random(in: 0..<4)
        ninjaPhase = 0
        if ninjaMove == 3 { dir = x < screen.midX ? -1 : 1 }   // head for the nearest wall
        else if Bool.random() { dir = -dir }
        vy = 0
        setMode(.ninja, 99)
    }

    @objc func doLaser() {
        guard hasGun else { return }
        laserFan = false
        shots = Int.random(in: 1...3)
        // face the wider side of the screen so the beam has room
        dir = (screen.maxX - (x + size)) > (x - screen.minX) ? 1 : -1
        setMode(.laser, 99)
    }

    @objc func doGlitch() {
        let vf = screen
        targetX = CGFloat.random(in: vf.minX...(vf.maxX - size))
        targetGround = Bool.random() ? vf.minY : CGFloat.random(in: vf.minY...(vf.minY + vf.height * 0.6))
        setMode(.glitchOut, 99)
    }

    func doGlitchHome() {
        targetX = CGFloat.random(in: screen.minX...(screen.maxX - size)); targetGround = screen.minY
        setMode(.glitchOut, 99)
    }

    func showLaserOverlay() {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).frame
        if laserWin == nil {
            let w = NSWindow(contentRect: vf, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false
            w.ignoresMouseEvents = true; w.level = .floating; w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            laserView.frame = NSRect(origin: .zero, size: vf.size)
            w.contentView = laserView
            laserWin = w
        }
        if laserWin!.frame != vf { laserWin!.setFrame(vf, display: false); laserView.frame = NSRect(origin: .zero, size: vf.size) }
        if !laserWin!.isVisible { laserWin!.orderFrontRegardless(); win.orderFrontRegardless() }
    }

    func fireLaser() {
        let vf = (NSScreen.main ?? NSScreen.screens[0]).frame
        showLaserOverlay()
        let v = toView(fireMuzzle)
        let muzzle = NSPoint(x: x - pad + v.x, y: y + v.y)
        let end = NSPoint(x: dir > 0 ? vf.maxX : vf.minX, y: muzzle.y)
        laserView.beams.append(.init(from: muzzle, to: end, age: 0, life: 18))
    }

    func step() {
        tick += 1; modeTick += 1; modeTime -= 1/30
        let vf = screen
        var name = "idle_front"
        switch mode {
        case .walk:
            // Feet-planted walk: step length is matched to the cycle so the planted foot doesn't slide.
            walkPhase += 1
            let n = walkFrames.count
            let hold = n == 8 ? 4 : 6
            let f = Int(walkPhase) / hold % n
            x += (n == 8 ? 2.4 : 2.0) * dir
            name = walkFrames[f]
            // bob: low on contact frames, high on passing frames
            let pass = n == 8 ? (f % 4 == 2) : (f % 2 == 1)
            y = groundY + (pass ? 3 : 0)
        case .shuffle:
            // shuffle dance travelling across the screen: slides, kicks and hops on the beat
            let beat = 7
            let fs = shuffleFrames.isEmpty ? ["cheer", "wave", "jump", "idle_34"] : shuffleFrames
            let f = (modeTick / beat) % fs.count
            let within = modeTick % beat
            name = fs[f]
            let slide: CGFloat = f % 2 == 1 ? 3.6 : 1.2       // glide on the slide frames
            x += slide * dir
            y = groundY + (name == fs.last && within < 5 ? 10 : (within < 2 ? 2 : 0))
            if modeTick % (beat * fs.count * 2) == beat * fs.count * 2 - 1 && Bool.random() { dir = -dir }
        case .coinPunch:
            // wind-up, punch, a spray of Monero coins, repeat, uppercut finisher with a big burst
            let t = modeTick
            y = groundY
            let seq: [(Int, String)] = [(10, "stance"), (6, "punch"), (6, "stance"), (6, "punch"), (6, "stance"), (6, "jab"), (8, "stance"), (14, "uppercut"), (24, "victory")]
            var acc = 0; name = "stance"
            for (i, (len, fr)) in seq.enumerated() {
                if t < acc + len {
                    name = fr
                    if t == acc && (fr == "punch" || fr == "jab" || fr == "uppercut") {
                        let fist = NSPoint(x: dir > 0 ? x + size * 0.95 : x + size * 0.05, y: y + size * (fr == "uppercut" ? 0.85 : 0.62))
                        spawnCoins(fr == "uppercut" ? 14 : 5, from: fist, power: fr == "uppercut" ? 1.25 : 0.9)
                        sprite.glitch = 0.12
                        x += 3 * dir
                    } else if t == acc + 2 { sprite.glitch = 0 }
                    _ = i
                    break
                }
                acc += len
            }
            if t >= acc { modeTime = 0 }
        case .pump:
            // punch the chart up: every punch adds a green candle climbing up the screen
            let t = modeTick
            y = groundY
            if t < 12 { name = "stance" }
            else {
                let k = t - 12, cycle = 11
                let punches = 12
                if k / cycle < punches {
                    let w = k % cycle
                    name = w < 5 ? ((k / cycle) % 3 == 2 ? "uppercut" : ((k / cycle) % 2 == 0 ? "punch" : "jab")) : "stance"
                    if w == 0 { pumpCandle(); sprite.glitch = 0.1; y = groundY + 2 }
                    if w == 2 { sprite.glitch = 0 }
                } else if k / cycle == punches && k % cycle == 0 {
                    if let top = laserView.candles.last {
                        // candles explode into coins and vanish right away
                        showLaserOverlay(); laserView.floorY = screen.minY
                        for c in laserView.candles {
                            for _ in 0..<(c.green ? 2 : 1) {
                                laserView.coins.append(.init(p: NSPoint(x: c.x + 10, y: c.base + c.h / 2),
                                    v: NSPoint(x: CGFloat.random(in: -5...5), y: CGFloat.random(in: 3...10)),
                                    age: 0, life: Int.random(in: 60...95), spin: CGFloat.random(in: 0...6)))
                            }
                            for _ in 0..<4 {
                                laserView.sparks.append(.init(p: NSPoint(x: c.x + 10, y: c.base + CGFloat.random(in: 0...c.h)),
                                    v: NSPoint(x: CGFloat.random(in: -4...4), y: CGFloat.random(in: -2...6)), age: 0, life: Int.random(in: 10...20)))
                            }
                        }
                        spawnCoins(10, from: NSPoint(x: top.x + 10, y: top.base + top.target + 10), power: 1)
                        laserView.candles = []
                    }
                    name = "victory"
                } else if k - punches * cycle < 60 { name = (tick / 10) % 2 == 0 ? "victory" : "cheer" }
                else { modeTime = 0 }
            }
        case .superbrain:
            // she looks up in awe, leans back and soaks in the hash rain, then cheers
            let t = modeTick
            y = groundY
            laserView.sbCenter.x = x + size / 2
            laserView.sbFloorY = screen.minY
            let b = hasBliss
            if t < 24 { name = b ? "bl0" : "idle_front" }
            else if t < 40 { name = b ? "bl1" : "cheer" }
            else if t < 250 {
                // blissed out: slow sway between lean-back poses
                let seq = b ? ["bl2", "bl3", "bl12", "bl3", "bl2", "bl9", "bl8", "bl4", "bl13", "bl5"] : ["cheer", "jump", "cheer", "wave"]
                name = seq[((t - 40) / 26) % seq.count]
                y = groundY + sin(CGFloat(t) * 0.05) * 2
            } else if t < 262 { laserView.sbActive = false; name = b ? "bl14" : "cheer" }
            else if t < 300 { name = b ? "bl15" : "cheer" }
            else { modeTime = 0 }
        case .run: x += 5.5 * dir; name = "run\((tick / 4) % 4)"
        case .idle: name = (tick / 45) % 4 == 3 ? "idle_34" : "idle_front"
        case .jump:
            x += 3 * dir; y += vy; vy -= 0.9; name = "jump"
            if y <= groundY { y = groundY; modeTime = 0 }
        case .dance:
            let seq = ["cheer","wave","idle_front","jump"]; name = seq[(tick / 8) % 4]
            y = groundY + ((tick / 8) % 2 == 0 ? 6 : 0)
        case .wave: name = (tick / 10) % 2 == 0 ? "wave" : "idle_front"
        case .coin:
            name = "coin"
            // falls in love with the coin: eyes grow, sparkles orbit it, hearts float up
            if !eyes.isEmpty {
                let k = size / 160
                sprite.love = true; sprite.loveT = modeTick
                sprite.eyeSrc = eyes.map { e in NSRect(x: e.x - 5, y: 160 - e.y - 5, width: 10, height: 10) }
                if dir < 0 { sprite.eyeSrc = sprite.eyeSrc.map { NSRect(x: 160 - $0.maxX, y: $0.minY, width: $0.width, height: $0.height) } }
                sprite.eyeDst = eyes.map { toView($0) }
                sprite.coinPt = toView(coinCenter)
                let top = toView(NSPoint(x: 80, y: 18)); sprite.heartPt = NSPoint(x: top.x, y: top.y + 6 * k)
            }

        case .combo:
            let (f, _, push) = combo[comboIdx]
            name = f; x += push * dir
            if f == "flykick" {
                let total = CGFloat(combo[comboIdx].1), t = CGFloat(combo[comboIdx].1 - comboLeft) / total
                y = groundY + sin(t * .pi) * 70
            } else { y = groundY }
            sprite.glitch = f == "palm" ? 0.15 : 0
            comboLeft -= 1
            if comboLeft <= 0 {
                sprite.glitch = 0
                comboIdx += 1
                if comboIdx >= combo.count { modeTime = 0 } else { comboLeft = combo[comboIdx].1 }
            }

        case .backflip:
            let t = modeTick
            if t < 10 { name = "bf0"; y = groundY }
            else if t < 40 {
                if t == 10 { vy = 15 }
                let p = CGFloat(t - 10) / 30
                name = p < 0.3 ? "bf1" : p < 0.75 ? "bf2" : "bf3"
                y += vy; vy -= 1.0
                x -= 0.6 * dir                     // almost straight up, drifting slightly back
                sprite.angle = p * 360 * dir
                if y < groundY { y = groundY }
            } else if t < 52 { sprite.angle = 0; y = groundY; name = t < 46 ? "bf3" : "victory" }
            else { modeTime = 0 }

        case .ninja: name = stepNinja(vf)

        case .laser:
            // draw, aim, fire N shots (with recoil), blow smoke, holster
            let t = modeTick
            y = groundY
            if t < 12 { name = "gun_draw" }
            else if t < 24 { name = "gun_aim" }
            else if laserFan {
                // sun-ray fan: the gun arm sweeps up with each beam, beams leave the muzzle
                let k = t - 24, rays = 9, per = 4
                if k < rays * per {
                    let i = k / per
                    let deg = -6 + CGFloat(i) / CGFloat(rays - 1) * 84
                    if hasRig {
                        name = "gun_body"
                        let prev = i == 0 ? 0 : -6 + CGFloat(i - 1) / CGFloat(rays - 1) * 84
                        let f = min(1, CGFloat(k % per + 1) / 2)          // swing to the new angle, then fire
                        setAim(prev + (deg - prev) * f)
                    } else { name = k % per == 0 ? "gun_fire" : "gun_aim" }
                    if k % per == 1 { fireFanRay(i, of: rays) }
                } else if k < rays * per + 10 {
                    // hold the last angle while the beams fade
                    if hasRig { name = "gun_body"; setAim(78) } else { name = "gun_aim" }
                } else if k < rays * per + 24 {
                    // lower the gun back to level
                    let f = CGFloat(k - rays * per - 10) / 14
                    if hasRig { name = "gun_body"; setAim(78 * (1 - f)) } else { name = "gun_aim" }
                } else if k < rays * per + 64 {
                    sprite.overlay = nil
                    name = "gun_smoke"
                    if k % 5 == 0 {
                        let muzzle = NSPoint(x: dir > 0 ? x + size * 0.8 : x + size * 0.2, y: y + size * 0.6)
                        laserView.puffs.append(.init(p: muzzle, age: 0, life: 30))
                    }
                } else { sprite.overlay = nil; modeTime = 0 }
            }
            else {
                let k = t - 24, shotLen = 16
                let shot = k / shotLen, within = k % shotLen
                if shot < shots {
                    name = within < 6 ? "gun_fire" : "gun_aim"
                    if within == 0 { fireLaser() }
                    if within < 3 { x -= 2.5 * dir }       // recoil
                } else if k - shots * shotLen < 36 {
                    name = "gun_smoke"
                    if (k - shots * shotLen) % 5 == 0 {
                        let muzzle = NSPoint(x: dir > 0 ? x + size * 0.8 : x + size * 0.2, y: y + size * 0.6)
                        showLaserOverlay()
                        laserView.puffs.append(.init(p: muzzle, age: 0, life: 30))
                    }
                }
                else { modeTime = 0 }
            }

        case .glitchOut:
            let t = CGFloat(modeTick) / 22
            sprite.glitch = min(1, t * 1.3)
            sprite.alpha = max(0, 1 - max(0, t - 0.55) * 2.4)
            name = modeTick % 6 < 3 ? "idle_front" : (hasFight ? "stance" : "idle_34")
            if modeTick % 3 == 0 { x += CGFloat.random(in: -8...8) }
            if modeTick >= 22 {
                x = targetX; groundY = targetGround; y = groundY
                setMode(.glitchIn, 99); sprite.glitch = 1; sprite.alpha = 0
            }
        case .glitchIn:
            let t = CGFloat(modeTick) / 20
            sprite.alpha = min(1, t * 2)
            sprite.glitch = max(0, 1 - t)
            name = hasFight ? (t < 0.7 ? "crouch" : "stance") : "idle_front"
            if modeTick >= 20 {
                sprite.glitch = 0; sprite.alpha = 1; name = hasFight ? "victory" : "wave"; modeTime = 0
                if pendingPump { pendingPump = false; modeTime = 1; DispatchQueue.main.async { self.doPump() } }
            }
        }

        if mode != .ninja || ninjaMove != 3 {
            if x < vf.minX { x = vf.minX; dir = 1 }
            if x > vf.maxX - size { x = vf.maxX - size; dir = -1 }
        }
        if mode != .backflip && mode != .ninja { sprite.angle = 0 }   // only flips may rotate her
        if mode == .backflip, frames[name] != nil {
            // keep every flip frame's body on one vertical line and spin around the body's own centre,
            // so the silhouette doesn't swing forward/back between poses
            let k = size / 160
            let c = bodyCenter(name), c0 = bodyCenter("bf0")
            let dx = (c0.x - c.x) * k * dir
            sprite.drawOffset = CGPoint(x: dx, y: 0)
            let v = toView(c)
            sprite.pivot = NSPoint(x: v.x + dx, y: v.y)
        } else { sprite.pivot = nil; sprite.drawOffset = .zero }
        if abs(sprite.angle) > 0.5 && mode == .ninja && ninjaMove != 0 && !(ninjaMove == 3 && ninjaPhase == 2) { sprite.angle = 0 }
        if [.run, .idle, .wave, .coin].contains(mode) { y = groundY }
        if frames[name] == nil { name = "idle_front" }
        currentFrame = name
        sprite.image = (dir < 0 ? framesL : frames)[name]
        sprite.needsDisplay = true
        win.setFrameOrigin(NSPoint(x: x - pad, y: y))

        if !laserView.isEmpty || laserWin?.isVisible == true {
            laserView.step()
            if laserView.isEmpty { laserWin?.orderOut(nil) }
        }
        if let p = panel, p.isVisible { placePanel() }
        if modeTime <= 0 {
            if mode == .dance { y = groundY }
            if groundY > vf.minY + 1 && mode != .glitchIn && Int.random(in: 0..<3) == 0 { doGlitchHome(); return }
            pick()
        }
    }

    func stepNinja(_ vf: NSRect) -> String {
        let t = modeTick
        switch ninjaMove {
        case 0: // tornado kick: crouch, leap spinning, land
            if t < 8 { y = groundY; return "nj_crouch" }
            if t == 8 { vy = 13 }
            if y > groundY || t == 8 {
                y += vy; vy -= 0.9; x += 3 * dir
                sprite.angle = CGFloat(t - 8) * -24 * dir
                if y <= groundY { y = groundY; sprite.angle = 0 }
                return "nj_tornado"
            }
            sprite.angle = 0
            if t < 60 { return "nj_land" }
            modeTime = 0; return "nj_land"
        case 1: // big jump, then dive kick angled down
            if t < 8 { y = groundY; return "nj_crouch" }
            if t == 8 { vy = 17 }
            if t < 24 { y += vy; vy -= 0.9; x += 2 * dir; return "nj_sidekick" }
            if y > groundY { y = max(groundY, y - 16); x += 11 * dir; landTick = t; return "nj_dive" }
            sprite.glitch = t - landTick < 6 ? 0.25 : 0            // impact flash
            if t - landTick > 30 { modeTime = 0 }
            return "nj_land"
        case 2: // split kick in mid-air, then axe kick
            if t < 8 { y = groundY; return "nj_crouch" }
            if t == 8 { vy = 14 }
            if t < 40 && (y > groundY || t == 8) { y += vy; vy -= 0.9; if y < groundY { y = groundY }; return "nj_split" }
            y = groundY
            if t < 58 { x += 1 * dir; return "nj_axe" }
            if t < 70 { return "nj_land" }
            modeTime = 0; return "nj_land"
        default: // wall kick: sprint at the edge, leap, kick off it, backflip away (upright the whole time)
            let edge = dir > 0 ? vf.maxX - size : vf.minX
            if ninjaPhase == 0 {
                let d = abs(edge - x)
                if d > 60 { x += 7 * dir; y = groundY; return "run\((tick / 3) % 4)" }
                ninjaPhase = 1; vy = 15
            }
            if ninjaPhase == 1 {                      // rising toward the wall
                y += vy; vy -= 0.9; x += 4 * dir
                if (dir > 0 && x >= edge) || (dir < 0 && x <= edge) || vy <= 2 {
                    x = min(max(x, vf.minX), vf.maxX - size)
                    ninjaPhase = 2; landTick = t; dir = -dir; vy = 9
                    sprite.glitch = 0.2                // kick-off flash
                }
                return "nj_sidekick"
            }
            // pushed off the wall: flip away, then land
            sprite.glitch = t - landTick < 4 ? 0.2 : 0
            y += vy; vy -= 0.9; x += 6 * dir
            let p = min(1, CGFloat(t - landTick) / 24)
            sprite.angle = p < 1 ? -p * 360 * dir : 0
            if y <= groundY { y = groundY; sprite.angle = 0; modeTime = 0; return "nj_land" }
            return p < 0.5 ? "bf1" : "bf2"
        }
    }

    // MARK: stats / news panel

    func togglePanel() {
        if let p = panel, p.isVisible { p.orderOut(nil); return }
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 330), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.level = .floating; p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let box = NSVisualEffectView(frame: p.contentView!.bounds)
            box.material = .hudWindow; box.state = .active; box.wantsLayer = true
            box.layer?.cornerRadius = 14; box.layer?.borderWidth = 2
            box.layer?.borderColor = NSColor(calibratedRed: 1, green: 0.4, blue: 0, alpha: 1).cgColor
            label.frame = NSRect(x: 14, y: 128, width: 272, height: 190)
            label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            label.textColor = .white; label.maximumNumberOfLines = 0
            box.addSubview(label)
            let sep = NSBox(frame: NSRect(x: 14, y: 122, width: 272, height: 1)); sep.boxType = .separator
            box.addSubview(sep)
            kindLabel.frame = NSRect(x: 14, y: 98, width: 200, height: 18)
            kindLabel.font = .boldSystemFont(ofSize: 11)
            kindLabel.textColor = NSColor(calibratedRed: 1, green: 0.55, blue: 0.1, alpha: 1)
            box.addSubview(kindLabel)
            let next = NSButton(title: "Next ▶", target: self, action: #selector(nextItem))
            next.bezelStyle = .inline; next.frame = NSRect(x: 216, y: 96, width: 70, height: 20)
            box.addSubview(next)
            itemView.frame = NSRect(x: 14, y: 12, width: 272, height: 82)
            itemView.onClick = { [weak self] in if let u = self?.currentLink { NSWorkspace.shared.open(u) } }
            itemLabel.frame = itemView.bounds
            itemLabel.font = .systemFont(ofSize: 12)
            itemLabel.textColor = .white; itemLabel.maximumNumberOfLines = 0
            itemLabel.lineBreakMode = .byWordWrapping
            itemView.addSubview(itemLabel); box.addSubview(itemView)
            p.contentView = box
            panel = p
        }
        label.stringValue = statsText.isEmpty ? "Loading Monero stats…" : statsText
        nextItem()
        placePanel(); panel!.orderFrontRegardless(); fetch()
        if [.walk, .run, .idle, .coin, .dance].contains(mode) { setMode(.wave, 2) }
    }

    func placePanel() {
        guard let p = panel else { return }
        let vf = screen
        let px = min(max(x + size/2 - 150, vf.minX + 4), vf.maxX - 304)
        p.setFrameOrigin(NSPoint(x: px, y: min(y + size + 4, vf.maxY - 334)))
    }

    func get(_ url: String, _ done: @escaping ([String: Any]) -> Void) {
        URLSession.shared.dataTask(with: URL(string: url)!) { d, _, _ in
            if let d, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { done(j) }
        }.resume()
    }

    let kindLabel = NSTextField(labelWithString: "")
    let itemLabel = NSTextField(wrappingLabelWithString: "")
    let itemView = MCClickView()
    var currentLink: URL?
    var news: [(String, URL)] = []
    var itemIndex = 0

    let trivia = [
        "Monero launched on April 18, 2014 as a fork of Bytecoin, built on the CryptoNote protocol.",
        "“Monero” means “coin” in Esperanto. The project was briefly called BitMonero at launch.",
        "Every transaction hides the sender with ring signatures, currently a ring of 16 possible signers.",
        "Stealth addresses give every payment a fresh one-time address, so your public address never shows up on-chain.",
        "RingCT (2017) hides transaction amounts. Bulletproofs (2018) and Bulletproofs+ (2022) made those proofs far smaller.",
        "Monero uses RandomX proof-of-work (since Nov 2019), designed to favor ordinary CPUs over ASICs.",
        "A new Monero block is targeted every 2 minutes.",
        "Tail emission: since mid-2022, every block pays a fixed 0.6 XMR forever, to keep miners paid.",
        "The smallest unit is a piconero: 0.000000000001 XMR.",
        "Monero has no fixed block size limit: it adjusts dynamically with demand.",
        "Monero's upcoming FCMP++ upgrade replaces ring signatures with full-chain membership proofs, so any output could be the real spender.",
    ]
    let projects = [
        ("P2Pool: decentralized mining pool with no pool operator and no fees.", "https://p2pool.io"),
        ("Haveno: decentralized, non-custodial peer-to-peer exchange for trading XMR.", "https://haveno.exchange"),
        ("Feather Wallet: lightweight, fast desktop wallet for Monero.", "https://featherwallet.org"),
        ("Cake Wallet: open-source mobile wallet with built-in Monero support.", "https://cakewallet.com"),
        ("Monerujo: long-running open-source Android wallet for Monero.", "https://www.monerujo.io"),
        ("Cuprate: an alternative Monero node written in Rust.", "https://github.com/Cuprate/cuprate"),
        ("Monero CCS: the community crowdfunding system that pays Monero's developers.", "https://ccs.getmonero.org"),
        ("Monero SuperPay: self-hosted, privacy-first point of sale. Accept XMR at any business with no KYC and no fees.", "https://monerosuperpay.com"),
        ("Monero Superbrain Umbrel Suite: a community app store of Monero apps for Umbrel, with P2Pool mining, SuperPay, atomic swaps and more.", "https://github.com/brainchainz/Monero-Superbrain"),
        ("MAGIC Monero Fund: funds Monero research and development through donations.", "https://monerofund.org"),
    ]

    @objc func nextItem() {
        itemIndex += 1
        let kind = itemIndex % 3
        if kind == 0, !news.isEmpty {
            let n = news[(itemIndex / 3) % news.count]
            kindLabel.stringValue = "📰 NEWS  (click to open)"; itemLabel.stringValue = n.0; currentLink = n.1
        } else if kind == 1 {
            let p = Int.random(in: 0..<3) == 0 ? projects[projects.firstIndex { $0.1.contains("brainchainz") || $0.1.contains("superpay") }! + Int.random(in: 0...1)] : projects[Int.random(in: 0..<projects.count)]
            kindLabel.stringValue = "🛠 PROJECT  (click to open)"; itemLabel.stringValue = p.0; currentLink = URL(string: p.1)
        } else {
            kindLabel.stringValue = "💡 TRIVIA"; itemLabel.stringValue = trivia[Int.random(in: 0..<trivia.count)]; currentLink = nil
        }
    }

    func fetchNews() {
        URLSession.shared.dataTask(with: URL(string: "https://www.getmonero.org/feed.xml")!) { d, _, _ in
            guard let d, let s = String(data: d, encoding: .utf8) else { return }
            let re = try! NSRegularExpression(pattern: "<entry>\\s*<title[^>]*>(.*?)</title>\\s*<link href=\"([^\"]+)\"", options: [.dotMatchesLineSeparators])
            var items: [(String, URL)] = []
            for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)).prefix(10) {
                var t = String(s[Range(m.range(at: 1), in: s)!])
                for (a, b) in [("&apos;", "'"), ("&quot;", "\""), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">")] { t = t.replacingOccurrences(of: a, with: b) }
                if let u = URL(string: String(s[Range(m.range(at: 2), in: s)!])) { items.append((t, u)) }
            }
            DispatchQueue.main.async { self.news = items }
        }.resume()
    }

    var price: [String: Any] = [:], net: [String: Any] = [:]
    func fetch() {
        if news.isEmpty { fetchNews() }
        get("https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd,btc&include_24hr_change=true&include_market_cap=true&include_24hr_vol=true") { j in
            DispatchQueue.main.async { self.price = (j["monero"] as? [String: Any]) ?? [:]; self.render() }
        }
        get("https://xmrchain.net/api/networkinfo") { j in
            DispatchQueue.main.async { self.net = (j["data"] as? [String: Any]) ?? [:]; self.render() }
        }
    }

    func num(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? Double(v as? String ?? "") ?? 0 }
    func render() {
        let usd = num(price["usd"]), ch = num(price["usd_24h_change"]), mc = num(price["usd_market_cap"])
        let vol = num(price["usd_24h_vol"]), btc = num(price["btc"])
        let h = Int(num(net["height"])), hr = num(net["hash_rate"]) / 1e9, diff = num(net["difficulty"]) / 1e9
        let pool = Int(num(net["tx_pool_size"])), txs = num(net["tx_count"]) / 1e6
        let arrow = ch >= 0 ? "▲" : "▼"
        statsText = """
        ɱ  MONERO (XMR)
        ─────────────────────────
        Price    $\(String(format: "%.2f", usd))  \(arrow)\(String(format: "%.2f", abs(ch)))%
        In BTC   \(String(format: "%.6f", btc))
        Mkt cap  $\(String(format: "%.2f", mc / 1e9))B
        24h vol  $\(String(format: "%.1f", vol / 1e6))M
        ─────────────────────────
        Height   \(h)
        Hashrate \(String(format: "%.2f", hr)) GH/s
        Diff     \(String(format: "%.1f", diff)) G
        Mempool  \(pool) txs
        Total tx \(String(format: "%.1f", txs))M
        """
        if panel?.isVisible == true { label.stringValue = statsText }
    }
}
