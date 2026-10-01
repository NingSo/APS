import SwiftUI

struct SignalOrbit: View {
    let phase: Phase
    let animate: Bool
    let action: () -> Void
    @State private var epoch = ProcessInfo.processInfo.systemUptime
    private var outerSpins: Bool { animate && (phase == .running || phase == .starting) }
    private var middleSpins: Bool { animate && (phase == .running || phase == .starting || phase == .failed) }
    private var spinKey: String { "\(outerSpins)-\(middleSpins)" }
    var body: some View {
        let ringColor = phase == .stopped ? Color(hex: 0x74846D) : Signal.color(phase)
        let centerColor = phase == .stopped ? Signal.accent : ringColor
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0/60, paused: !outerSpins && !middleSpins)) { _ in
                let elapsed = max(0, ProcessInfo.processInfo.systemUptime - epoch)
                let outer = outerSpins ? elapsed.truncatingRemainder(dividingBy: 20) / 20 * 360 : 0
                let middle = middleSpins ? -elapsed.truncatingRemainder(dividingBy: 38) / 38 * 360 : 0
                OrbitDrawing(color: ringColor, outerAngle: outer, middleAngle: middle)
            }.frame(width: 206, height: 193)
            Button(action: action) {
                VStack(spacing: 9) {
                    SignalIcon(glyph: phase == .failed ? .alert : .power, color: centerColor).frame(width: 26, height: 26)
                    Text(phase.action).signalFont(17).foregroundColor(centerColor)
                    Eyebrow(text: phase == .running ? "TAP TO STOP" : phase.busy ? "PLEASE WAIT" : "TAP TO START")
                }.frame(width: 124, height: 124)
                    .background(RadialGradient(colors: [centerColor.opacity(0.06), .clear], center: .center, startRadius: 0, endRadius: 62), in: Circle())
                    .contentShape(Circle())
            }.buttonStyle(PressFeedback()).disabled(phase.busy)
                .accessibilityIdentifier("power-control").accessibilityLabel(phase.action)
        }.frame(width: 206, height: 206)
            .onChange(of: spinKey) { _ in epoch = ProcessInfo.processInfo.systemUptime }
    }
}
private struct OrbitDrawing: View {
    let color: Color
    let outerAngle: Double
    let middleAngle: Double
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = Double(min(size.width,size.height))/2
            func point(_ radius: Double, _ degrees: Double) -> CGPoint {
                CGPoint(x: Double(center.x) + cos(degrees * .pi/180)*radius,
                        y: Double(center.y) + sin(degrees * .pi/180)*radius)
            }
            func circle(_ center: CGPoint, _ radius: Double) -> Path {
                Path(ellipseIn: CGRect(x: Double(center.x)-radius, y: Double(center.y)-radius, width: radius*2, height: radius*2))
            }
            context.fill(circle(center,radius), with: .radialGradient(Gradient(colors: [color.opacity(0.06),.clear]), center: center, startRadius: 0, endRadius: CGFloat(radius)))
            for tick in 0..<64 {
                let degrees = Double(tick)*360/64
                let length: Double = tick % 8 == 0 ? 7 : 3
                var p = Path(); p.move(to: point(radius-3-length,degrees)); p.addLine(to: point(radius-3,degrees))
                context.stroke(p, with: .color(color.opacity(tick % 8 == 0 ? 0.38 : 0.15)), lineWidth: 1)
            }
            let outer = radius-18; let middle = outer-10
            context.stroke(circle(center,outer), with: .color(color.opacity(0.09)), lineWidth: 1)
            context.stroke(circle(center,middle), with: .color(color.opacity(0.09)), lineWidth: 1)
            context.stroke(circle(center,outer-22), with: .color(color.opacity(0.19)), lineWidth: 1)
            var a = Path(); a.addArc(center: center, radius: CGFloat(outer), startAngle: .degrees(outerAngle-105), endAngle: .degrees(outerAngle+149), clockwise: false)
            context.stroke(a, with: .linearGradient(Gradient(colors: [color.opacity(0.08),color]), startPoint: .zero, endPoint: CGPoint(x:size.width,y:0)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var b = Path(); b.addArc(center: center, radius: CGFloat(middle), startAngle: .degrees(middleAngle), endAngle: .degrees(middleAngle+33), clockwise: false)
            context.stroke(b, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth:1,lineCap:.round))
            let dot = point(outer,outerAngle-19)
            context.fill(circle(dot,7),with:.color(color.opacity(0.13)))
            context.fill(circle(dot,2.5),with:.color(color))
            context.fill(circle(point(middle,middleAngle+180),2),with:.color(color))
        }.accessibilityHidden(true)
    }
}
