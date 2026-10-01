import SwiftUI

struct SessionActivityView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:15) {
                PageHeading(eyebrow:"LIVE / IN THIS SESSION",title:"看见每次流动。",subtitle:"仅展示当前会话，不上传、不建立云端历史。")
                if store.session.phase == .running {
                    SignalCard {
                        HStack { Text("传输速率").signalFont(14); Spacer(); Eyebrow(text:"60s / LIVE") }
                        HStack {
                            Metric(title:"● 接收",bytes:store.session.receiveRate,rate:true,color:Signal.accent)
                            Metric(title:"● 发送",bytes:store.session.sendRate,rate:true,color:Signal.mint)
                        }
                        ZStack {
                            TrafficChart(samples:store.session.samples)
                            if store.session.samples.isEmpty { Text("等待真实流量采样").signalFont(11).foregroundColor(Signal.secondary) }
                        }.frame(height:115)
                        HStack { Eyebrow(text:"−60s",color:Signal.muted); Spacer(); Text("自适应刻度").signalFont(9).foregroundColor(Signal.muted); Spacer(); Eyebrow(text:"现在",color:Signal.muted) }
                    }
                    SignalCard {
                        HStack(spacing:18) {
                            Metric(title:"本次累计接收",bytes:store.session.received)
                            Metric(title:"本次累计发送",bytes:store.session.sent)
                        }
                        SignalDivider()
                        HStack(spacing:18) {
                            count("活动连接 · 不是设备数",value:"\(store.session.active) 条")
                            count("会话累计连接",value:"\(store.session.total) 次")
                        }
                    }
                } else {
                    SignalCard {
                        SignalIcon(glyph:.activity,color:Signal.secondary).frame(width:22,height:22)
                        Text("等待真实会话").signalFont(18)
                        Text("启动代理后，这里会显示当前会话的速率、曲线和连接统计。").signalFont(12).foregroundColor(Signal.secondary)
                    }
                }
                HStack {
                    Text("会话日志").signalFont(15)
                    Text("\(store.session.events.count)").signalFont(10,mono:true).padding(5).background(Signal.raised,in:RoundedRectangle(cornerRadius:6))
                    Spacer()
                    IconControl(glyph:.download,label:"导出日志") { store.sheet = .export }.disabled(store.session.events.isEmpty)
                }
                HStack(spacing:10) {
                    SignalIcon(glyph:.search,color:Signal.secondary).frame(width:17,height:17)
                    TextField("搜索错误、协议或事件",text:$store.logQuery).signalFont(12)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityIdentifier("log-search")
                }.padding(14).frame(minHeight:48).overlay(RoundedRectangle(cornerRadius:12).stroke(Signal.border,lineWidth:1))
                Choices(labels:["全部","信息","提醒","错误"],selected:filterIndex,compact:true) {
                    store.logFilter = $0 == 0 ? nil : EventLevel.allCases[$0-1]
                }
                if store.filteredEvents.isEmpty {
                    Text(store.session.events.isEmpty ? "尚无会话记录。启动服务后，生命周期事件会出现在这里。" : "没有匹配的日志。试试其他关键词或筛选条件。")
                        .signalFont(12).foregroundColor(Signal.secondary).padding(.vertical,20)
                }
                ForEach(store.filteredEvents) { event in
                    VStack(alignment:.leading,spacing:9) {
                        SignalDivider()
                        HStack(alignment:.top,spacing:9) {
                            Text(event.time,style:.time).signalFont(10,mono:true).foregroundColor(Signal.muted)
                            Text(event.level.rawValue).signalFont(10,mono:true).foregroundColor(event.level == .info ? Signal.accent : event.level == .warning ? Signal.warning : Signal.error)
                            Text(event.text).signalFont(11).frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }
                }
                Text("内存中最多保留 200 条日志、60 个采样。停止或重建会话后清空；接收为目标到客户端，发送为客户端到目标。").signalFont(10).foregroundColor(Signal.muted).lineSpacing(4)
            }.screenPadding()
        }.accessibilityIdentifier("screen-activity")
    }
    private var filterIndex:Int { store.logFilter.flatMap { EventLevel.allCases.firstIndex(of:$0) }.map { $0+1 } ?? 0 }
    private func count(_ title:String,value:String) -> some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).signalFont(10).foregroundColor(Signal.secondary)
            Text(value).signalFont(22,mono:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
