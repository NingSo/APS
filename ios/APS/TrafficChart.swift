import SwiftUI

struct TrafficChart: View {
    let samples: [TrafficSample]
    var compact = false
    var sentOnly = false
    var body: some View {
        Canvas { context, size in
            if !compact {
                for i in 0..<4 {
                    let y = size.height * Double(i)/3
                    var p = Path(); p.move(to: CGPoint(x:0,y:y)); p.addLine(to:CGPoint(x:size.width,y:y))
                    context.stroke(p,with:.color(Signal.border),style:StrokeStyle(lineWidth:1,dash:[2,7]))
                }
            }
            guard let last = samples.last else { return }
            let maximum = Double(samples.map { max($0.received,$0.sent) }.max() ?? 1).clampedMinimum(1) * 1.15
            func x(_ sample: TrafficSample) -> Double { min(1,max(0,(sample.uptime-last.uptime+60)/60))*size.width }
            func y(_ value: Int64) -> Double { size.height-Double(value)/maximum*size.height }
            func line(_ sent: Bool) -> Path {
                var p = Path()
                for (index,sample) in samples.enumerated() {
                    let point = CGPoint(x:x(sample),y:y(sent ? sample.sent : sample.received))
                    if index == 0 { p.move(to:point) } else { p.addLine(to:point) }
                }; return p
            }
            if !compact, let first = samples.first {
                var area = line(false); area.addLine(to:CGPoint(x:size.width,y:size.height)); area.addLine(to:CGPoint(x:x(first),y:size.height)); area.closeSubpath()
                context.fill(area,with:.linearGradient(Gradient(colors:[Signal.accent.opacity(0.16),.clear]),startPoint:.zero,endPoint:CGPoint(x:0,y:size.height)))
            }
            if !sentOnly { context.stroke(line(false),with:.color(Signal.accent),style:StrokeStyle(lineWidth:1.7,lineCap:.round)) }
            if !compact || sentOnly { context.stroke(line(true),with:.color(Signal.mint),style:StrokeStyle(lineWidth:1.2,lineCap:.round,dash:compact ? [] : [4,5])) }
            let tip = CGPoint(x:size.width,y:y(sentOnly ? last.sent : last.received))
            context.fill(Path(ellipseIn:CGRect(x:tip.x-2,y:tip.y-2,width:4,height:4)),with:.color(sentOnly ? Signal.mint : Signal.accent))
        }.accessibilityLabel("最近 60 秒传输速率曲线；当前数值见上方")
    }
}
private extension Double { func clampedMinimum(_ minimum: Double) -> Double { max(minimum,self) } }
