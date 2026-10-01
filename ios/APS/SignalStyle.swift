import SwiftUI

enum Signal {
    static let background = Color(hex: 0x090D0B)
    static let surface = Color(hex: 0x141A16)
    static let raised = Color(hex: 0x1C241E)
    static let border = Color(hex: 0x2B362E)
    static let text = Color(hex: 0xEFF5ED)
    static let secondary = Color(hex: 0xA0AFA2)
    static let muted = Color(hex: 0x7D8D7F)
    static let accent = Color(hex: 0xC1F76B)
    static let onAccent = Color(hex: 0x17220B)
    static let mint = Color(hex: 0x7ADECF)
    static let warning = Color(hex: 0xEDBD79)
    static let error = Color(hex: 0xFF978A)
    static func color(_ phase: Phase) -> Color {
        switch phase {
        case .running: return accent
        case .starting, .stopping: return warning
        case .failed: return error
        case .stopped: return secondary
        }
    }
}
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
private struct SignalFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let mono: Bool
    init(_ size: CGFloat, weight: Font.Weight, mono: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight; self.mono = mono
    }
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: mono ? .monospaced : .default))
    }
}
extension View {
    func signalFont(_ size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> some View {
        modifier(SignalFont(size, weight: weight, mono: mono))
    }
    func screenPadding() -> some View { padding(.horizontal, 20).padding(.bottom, 24) }
}
struct Eyebrow: View {
    var text: String
    var color: Color = Signal.secondary
    var body: some View { Text(text).signalFont(9, mono: true).tracking(1.5).foregroundColor(color) }
}
struct PageHeading: View {
    var eyebrow = ""
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !eyebrow.isEmpty { Eyebrow(text: eyebrow) }
            Text(title).signalFont(29).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).signalFont(12).foregroundColor(Signal.secondary).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SignalCard<Content: View>: View {
    let color: Color
    let content: Content
    init(color: Color = Signal.surface, @ViewBuilder content: () -> Content) {
        self.color = color; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Signal.border, lineWidth: 1))
    }
}
struct SignalDivider: View { var body: some View { Rectangle().fill(Signal.border).frame(height: 1).accessibilityHidden(true) } }
struct PressFeedback: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduced
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduced ? 0.98 : 1)
            .animation(reduced ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
struct PrimaryAction: View {
    let title: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).signalFont(14, weight: .medium).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundColor(Signal.onAccent).padding(.horizontal, 12)
                .background(Signal.accent.opacity(enabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(PressFeedback()).disabled(!enabled)
    }
}
struct SecondaryAction: View {
    let title: String
    var glyph: Glyph = .arrow
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) { SignalIcon(glyph: glyph).frame(width: 18, height: 18); Text(title).signalFont(12) }
                .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 12)
                .foregroundColor(Signal.text).background(Signal.raised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Signal.border, lineWidth: 1))
        }.buttonStyle(PressFeedback()).disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }
}
struct IconControl: View {
    let glyph: Glyph
    let label: String
    var color: Color = Signal.text
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            SignalIcon(glyph: glyph, color: color).frame(width: 21, height: 21).frame(width: 48, height: 48).contentShape(Rectangle())
        }.buttonStyle(PressFeedback()).accessibilityLabel(label)
    }
}
struct StatePill: View {
    let phase: Phase
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Signal.color(phase)).frame(width: 5, height: 5)
            Text(phase.badge).signalFont(9, mono: true)
        }.padding(.horizontal, 8).padding(.vertical, 6).foregroundColor(Signal.color(phase))
            .background(Signal.color(phase).opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Signal.color(phase).opacity(0.25), lineWidth: 1))
            .accessibilityElement(children: .ignore).accessibilityLabel(phase.title)
    }
}
struct Metric: View {
    let title: String
    let bytes: Int64
    var rate = false
    var color: Color = Signal.text
    var body: some View {
        let amount = ByteAmount(bytes, rate: rate)
        VStack(alignment: .leading, spacing: 6) {
            Text(title).signalFont(10).foregroundColor(Signal.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 5) { value(amount); unit(amount) }
                VStack(alignment: .leading, spacing: 2) { value(amount); unit(amount) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func value(_ amount: ByteAmount) -> some View { Text(amount.value).signalFont(25, mono: true).foregroundColor(color).monospacedDigit() }
    private func unit(_ amount: ByteAmount) -> some View { Text(amount.unit).signalFont(9).foregroundColor(Signal.secondary) }
}
struct Choices: View {
    let labels: [String]
    let selected: Int
    var compact = false
    let action: (Int) -> Void
    var body: some View {
        if compact {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) { items }
            }
        } else {
            HStack(spacing: 4) { items }.padding(4)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Signal.border, lineWidth: 1))
        }
    }
    private var items: some View {
        ForEach(labels.indices, id: \.self) { index in
            Button { action(index) } label: {
                Text(labels[index]).signalFont(compact ? 11 : 12)
                    .frame(maxWidth: compact ? nil : .infinity, minHeight: 48)
                    .padding(.horizontal, compact ? 13 : 6)
                    .background(selected == index ? Signal.raised : Signal.background, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(selected == index ? Signal.accent : Signal.secondary)
            }.buttonStyle(PressFeedback()).accessibilityAddTraits(selected == index ? [.isSelected] : [])
        }
    }
}
