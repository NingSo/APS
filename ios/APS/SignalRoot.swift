import SwiftUI

struct SignalRoot: View {
    @ObservedObject var store:AppStore
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    private var reduced:Bool { systemReduced || store.preferences.reduceMotion }
    private var secondary:Bool { store.page == .settings || store.page == .diagnostics }
    var body:some View {
        ZStack(alignment:.bottom) {
            VStack(spacing:0) {
                header
                GeometryReader { geometry in
                    ZStack {
                        page.id(store.page).transition(.asymmetric(
                            insertion:.opacity.combined(with:.offset(y:geometry.size.height/18)).animation(reduced ? nil : .easeInOut(duration:0.23)),
                            removal:.opacity.combined(with:.offset(y:-geometry.size.height/24)).animation(reduced ? nil : .easeInOut(duration:0.18))))
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }.clipped()
                bottomBar
            }
            if let toast = store.toast {
                HStack(spacing:10) {
                    SignalIcon(glyph:.check,color:Signal.accent).frame(width:18,height:18)
                    Text(toast).signalFont(12)
                }.padding(15).frame(maxWidth:.infinity,alignment:.leading)
                    .background(Signal.raised,in:RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(Signal.accent.opacity(0.3),lineWidth:1))
                    .padding(.horizontal,24).padding(.bottom,84)
                    .transition(.opacity.combined(with:.offset(y:8)))
                    .accessibilityIdentifier("feedback-toast").allowsHitTesting(false)
            }
        }.frame(maxWidth:600).frame(maxWidth:.infinity,maxHeight:.infinity)
            .background(Signal.background.ignoresSafeArea()).foregroundColor(Signal.text).tint(Signal.accent)
            .animation(reduced ? nil : .easeOut(duration:0.18),value:store.toast)
            .transaction { if reduced { $0.animation = nil; $0.disablesAnimations = true } }
            .sheet(item:$store.sheet) { route in
                SheetContent(store:store,route:route)
            }
    }
    @ViewBuilder private var page:some View {
        switch store.page {
        case .overview: OverviewView(store:store,reduced:reduced)
        case .connect: ConnectionView(store:store)
        case .activity: SessionActivityView(store:store)
        case .settings: SettingsView(store:store)
        case .diagnostics: DiagnosticsView(store:store)
        }
    }
    private var header:some View {
        HStack(spacing:9) {
            if secondary { IconControl(glyph:.back,label:"返回",action:store.back) }
            else {
                SignalIcon(glyph:.logo,color:Signal.accent).frame(width:25,height:25).padding(7)
                    .overlay(RoundedRectangle(cornerRadius:10).stroke(Signal.accent.opacity(0.35),lineWidth:1))
            }
            VStack(alignment:.leading,spacing:4) {
                Text(store.page == .settings ? "设置" : store.page == .diagnostics ? "连接诊断" : "APS").signalFont(19)
                Eyebrow(text:"IOS PROXY SERVER")
            }.frame(maxWidth:.infinity,alignment:.leading)
            if !secondary { IconControl(glyph:.settings,label:"设置") { store.navigate(.settings) }.accessibilityIdentifier("open-settings") }
        }.padding(.leading,14).padding(.trailing,8).frame(minHeight:70)
    }
    private var bottomBar:some View {
        VStack(spacing:0) {
            SignalDivider()
            HStack(spacing:0) {
                tab(.overview,label:"概览",glyph:.tune)
                tab(.connect,label:"连接",glyph:.link)
                tab(.activity,label:"活动",glyph:.activity)
            }.padding(.horizontal,24).frame(minHeight:69)
        }.background(Signal.background)
    }
    private func tab(_ target:Screen,label:String,glyph:Glyph)->some View {
        let selected = store.selectedTab == target
        return Button { store.navigate(target) } label: {
            VStack(spacing:4) {
                SignalIcon(glyph:glyph,color:selected ? Signal.accent : Signal.muted).frame(width:22,height:22)
                    .frame(width:58,height:30).background(selected ? Signal.accent.opacity(0.08) : .clear,in:Capsule())
                Text(label).signalFont(10).foregroundColor(selected ? Signal.accent : Signal.muted)
            }.frame(maxWidth:.infinity,minHeight:64).contentShape(Rectangle())
        }.buttonStyle(PressFeedback()).accessibilityLabel(label).accessibilityIdentifier("nav-\(target.rawValue)")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
