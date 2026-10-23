#if canImport(UIKit) && os(iOS)
import Faro
import SwiftUI
import UIKit

/// One field of the form, drawn by its type.
struct FieldRow: View {
    let field: FaroFormField
    @ObservedObject var model: HelpModel
    var focused: FocusState<String?>.Binding
    let onReturn: () -> Void

    @Environment(\.faroStyle) private var style

    private var s: FaroStrings { model.strings }
    private var issue: FaroFieldIssue? { model.issues[field.key] }

    private var text: Binding<String> {
        Binding(get: { model.value(field.key) }, set: { model.set(field.key, $0) })
    }

    private var label: String {
        if !field.label.isEmpty { return field.label }
        switch field.key {
        case FaroFormField.nameKey: return s.nameLabel
        case FaroFormField.emailKey: return s.emailLabel
        case FaroFormField.messageKey: return s.messageLabel
        default: return field.key
        }
    }

    private var placeholder: String {
        if !field.placeholder.isEmpty { return field.placeholder }
        switch field.key {
        case FaroFormField.emailKey: return s.emailPlaceholder
        case FaroFormField.messageKey: return s.messagePlaceholder
        default: return ""
        }
    }

    private var help: String {
        if !field.help.isEmpty { return field.help }
        return field.key == FaroFormField.emailKey ? s.emailHelp : ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if field.type != .checkbox {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(style.font(.subheadline, .semibold))
                        .foregroundStyle(issue == nil ? Color.primary : Color.red)
                    Spacer(minLength: 8)
                    if !field.isRequired {
                        Text(s.optional)
                            .font(style.font(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHidden(true)
            }
            control
            footer
        }
        .padding(14)
    }

    @ViewBuilder
    private var control: some View {
        switch field.type {
        case .textarea:
            MultilineField(
                text: text,
                placeholder: placeholder,
                label: label,
                hasIssue: issue != nil,
                minHeight: field.key == FaroFormField.messageKey ? 150 : 96,
                counter: field.key == FaroFormField.messageKey ? FaroForm.maximumMessageLength : nil
            )
            .focused(focused, equals: field.key)
            .accessibilityIdentifier("faro.field.\(field.key)")
        case .select:
            SelectField(field: field, selection: text, prompt: s.chooseOption, label: label)
        case .checkbox:
            Toggle(isOn: Binding(get: { text.wrappedValue == "true" }, set: { text.wrappedValue = $0 ? "true" : "" })) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(label).font(style.font(.subheadline))
                    if field.isRequired { Text("*").foregroundStyle(.red).accessibilityHidden(true) }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: style.accent))
            .accessibilityIdentifier("faro.field.\(field.key)")
        case .date:
            DateField(value: text, required: field.isRequired, label: label, strings: s)
                .accessibilityIdentifier("faro.field.\(field.key)")
        default:
            TextField(placeholder, text: text)
                .font(style.font(.body))
                .modifier(Keyboard(type: field.type, key: field.key))
                .submitLabel(.next)
                .onSubmit(onReturn)
                .focused(focused, equals: field.key)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .modifier(FieldWell(hasIssue: issue != nil))
                .accessibilityLabel(label)
                .accessibilityIdentifier("faro.field.\(field.key)")
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let issue {
            Label(s.issue(issue, key: field.key), systemImage: "exclamationmark.circle.fill")
                .font(style.font(.footnote))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        } else if !help.isEmpty {
            Text(help)
                .font(style.font(.footnote))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Keyboard, content type and capitalization by field type.
private struct Keyboard: ViewModifier {
    let type: FaroFieldType
    let key: String

    func body(content: Content) -> some View {
        switch type {
        case .email:
            content
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        case .number:
            content.keyboardType(.decimalPad)
        case .tel:
            content.keyboardType(.phonePad).textContentType(.telephoneNumber)
        case .url:
            content
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        default:
            if key == FaroFormField.nameKey {
                content.textContentType(.name).textInputAutocapitalization(.words)
            } else {
                content
            }
        }
    }
}

/// The well every input sits in.
struct FieldWell: ViewModifier {
    let hasIssue: Bool

    @Environment(\.faroStyle) private var style

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: style.fieldRadius, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.fieldRadius, style: .continuous)
                    .strokeBorder(hasIssue ? Color.red : Color.clear, lineWidth: 1.2)
            )
    }
}

/// A text editor with a placeholder and, for the message, a character count.
private struct MultilineField: View {
    @Binding var text: String
    let placeholder: String
    let label: String
    let hasIssue: Bool
    let minHeight: CGFloat
    let counter: Int?

    @Environment(\.faroStyle) private var style

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(style.font(.body))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(style.font(.body))
                    .frame(minHeight: minHeight)
                    .modifier(ClearEditorBackground())
                    .accessibilityLabel(label)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(FieldWell(hasIssue: hasIssue))
            if let counter {
                let count = text.unicodeScalars.count
                Text("\(count) / \(counter)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(count > counter ? Color.red : Color.secondary)
                    .accessibilityHidden(count < counter - 200)
            }
        }
    }
}

/// `TextEditor` paints its own background until iOS 16 lets us hide it.
private struct ClearEditorBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

/// A list: chips (tap again to clear an optional one), or a menu when it is long.
private struct SelectField: View {
    let field: FaroFormField
    @Binding var selection: String
    let prompt: String
    let label: String

    @Environment(\.faroStyle) private var style

    var body: some View {
        if field.options.count > 12 {
            Menu {
                Picker(label, selection: $selection) {
                    if !field.isRequired { Text("—").tag("") }
                    ForEach(field.options) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            } label: {
                HStack {
                    Text(field.options.first { $0.value == selection }?.label ?? prompt)
                        .foregroundStyle(selection.isEmpty ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                }
                .font(style.font(.body))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .modifier(FieldWell(hasIssue: false))
            }
            .accessibilityLabel(label)
            .accessibilityIdentifier("faro.field.\(field.key)")
        } else if field.groups.isEmpty {
            chips(field.options)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                let loose = field.options.filter { option in
                    option.group.map { key in !field.groups.contains { $0.key == key } } ?? true
                }
                if !loose.isEmpty { chips(loose) }
                ForEach(field.groups) { group in
                    let options = field.options.filter { $0.group == group.key }
                    if !options.isEmpty {
                        Text(group.label.uppercased())
                            .font(style.font(.caption2, .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        chips(options)
                    }
                }
            }
        }
    }

    private func chips(_ options: [FaroFieldOption]) -> some View {
        ChipFlow {
            ForEach(options) { option in
                let selected = selection == option.value
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selection = selected && !field.isRequired ? "" : option.value
                    }
                } label: {
                    HStack(spacing: 5) {
                        if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                        Text(option.label)
                    }
                    .font(style.font(.subheadline, selected ? .semibold : .regular))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .foregroundStyle(selected ? style.onAccent : Color.primary)
                    .background(style.control().fill(selected ? AnyShapeStyle(style.accent)
                                                              : AnyShapeStyle(Color(.tertiarySystemFill))))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(label): \(option.label)")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("faro.option.\(field.key).\(option.value)")
            }
        }
    }
}

/// Chips that wrap onto new lines (iOS 16+); a sideways row before that.
private struct ChipFlow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            WrapLayout(spacing: 8) { content() }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }.padding(.vertical, 2)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += row + spacing
                row = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            row = max(row, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += row + spacing
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

/// A date as `yyyy-MM-dd`: a button until one is chosen, then the compact picker.
private struct DateField: View {
    @Binding var value: String
    let required: Bool
    let label: String
    let strings: FaroStrings

    @Environment(\.faroStyle) private var style

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        if let date = Self.formatter.date(from: value) {
            HStack {
                DatePicker(
                    label,
                    selection: Binding(get: { date }, set: { value = Self.formatter.string(from: $0) }),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Spacer()
                if !required {
                    Button(strings.clear) { value = "" }
                        .font(style.font(.subheadline))
                }
            }
        } else {
            Button {
                value = Self.formatter.string(from: Date())
            } label: {
                Label(strings.chooseDate, systemImage: "calendar")
                    .font(style.font(.subheadline, .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .foregroundStyle(style.accentInk)
                    .background(style.control().fill(style.accent.opacity(0.12)))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(label): \(strings.chooseDate)")
        }
    }
}
#endif
