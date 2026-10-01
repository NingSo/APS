import SwiftUI

enum Glyph { case logo, power, settings, link, activity, copy, arrow, back, close, check, qr, tune, download, search, alert, globe, info, terminal }

/// The same 24-unit geometry as Android SignalIcon.kt; not an unrelated symbol/font substitute.
struct SignalIcon: View {
    let glyph: Glyph
    var color: Color = Signal.text
    var body: some View {
        Canvas { original, size in
            var context = original
            context.scaleBy(x: size.width / 24, y: size.height / 24)
            let style = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
                var path = Path(); path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2))
                context.stroke(path, with: .color(color), style: style)
            }
            func circle(_ x: Double, _ y: Double, _ r: Double, fill: Bool = false) {
                let p = Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
                if fill { context.fill(p, with: .color(color)) } else { context.stroke(p, with: .color(color), style: style) }
            }
            func arc(_ x: Double, _ y: Double, _ r: Double, _ start: Double, _ sweep: Double) {
                var p = Path(); p.addArc(center: CGPoint(x: x, y: y), radius: r,
                    startAngle: .degrees(start), endAngle: .degrees(start+sweep), clockwise: false)
                context.stroke(p, with: .color(color), style: style)
            }
            func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
                context.stroke(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 1.3), with: .color(color), style: style)
            }
            switch glyph {
            case .logo: line(4,20,12,4); line(12,4,20,20); line(8,13,16,13); line(9,20,15,20); circle(19,4,1.1,fill:true)
            case .power: arc(12,12,8,-48,276); line(12,2,12,11)
            case .settings:
                circle(12,12,6.5); circle(12,12,2.5)
                for i in 0..<8 { let a = Double(i) * .pi / 4; line(12+cos(a)*6.5,12+sin(a)*6.5,12+cos(a)*9,12+sin(a)*9) }
            case .link: arc(15.5,7.5,5.5,130,285); arc(8.5,16.5,5.5,-50,285); line(9,15,15,9)
            case .activity: line(2,13,7,13); line(7,13,10,5); line(10,5,14,20); line(14,20,17,10); line(17,10,22,10)
            case .copy: box(8,7,11,14); line(5,17,5,3); line(5,3,15,3)
            case .arrow: line(4,12,20,12); line(15,7,20,12); line(20,12,15,17)
            case .back: line(20,12,4,12); line(9,7,4,12); line(4,12,9,17)
            case .close: line(6,6,18,18); line(18,6,6,18)
            case .check: line(4,12,10,18); line(10,18,20,6)
            case .qr: box(3,3,6,6); box(15,3,6,6); box(3,15,6,6); box(14,14,3,3); line(21,14,21,21); line(14,21,17,21)
            case .tune: line(3,7,21,7); line(3,17,21,17); line(8,4,8,10); line(16,14,16,20)
            case .download: line(12,3,12,15); line(7,10,12,15); line(12,15,17,10); line(4,16,4,21); line(4,21,20,21); line(20,21,20,16)
            case .search: circle(10,10,6); line(15,15,21,21)
            case .alert: line(12,3,22,21); line(22,21,2,21); line(2,21,12,3); line(12,9,12,14); circle(12,18,0.9,fill:true)
            case .globe: circle(12,12,9); context.stroke(Path(ellipseIn: CGRect(x: 8,y: 3,width: 8,height: 18)), with: .color(color), style: style); line(3,12,21,12)
            case .info: circle(12,12,9); line(12,11,12,17); circle(12,7,0.9,fill:true)
            case .terminal: line(5,7,11,12); line(11,12,5,17); line(14,17,20,17)
            }
        }.accessibilityHidden(true)
    }
}
