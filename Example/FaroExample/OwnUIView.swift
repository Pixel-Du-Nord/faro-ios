import Faro
import SwiftUI

/// The core alone, under the app's own (deliberately plain) screen: how an app
/// with its own design uses `form()`, `prepare()`, `validate` and `send()`.
struct OwnUIView: View {
    @State private var form: FaroForm?
    @State private var kind: FaroKind = .question
    @State private var values: [String: String] = [:]
    @State private var issues: [String: FaroFieldIssue] = [:]
    @State private var status = ""
    @State private var sending = false

    var body: some View {
        NavigationView {
            Form {
                if let form {
                    Section {
                        Picker("Kind", selection: $kind) {
                            ForEach(form.kinds, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(form.title.isEmpty ? "Request" : form.title)
                    } footer: {
                        Text("Form from \(form.organizationName) · \(form.source.rawValue) · \(form.locale)")
                    }
                    Section("Fields, in Faro's order") {
                        ForEach(form.fields) { field in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(field.label.isEmpty ? field.key : field.label) · \(field.type.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                                TextField(field.placeholder, text: Binding(
                                    get: { values[field.key] ?? "" },
                                    set: { values[field.key] = $0 }
                                ))
                                if let issue = issues[field.key] {
                                    Text(issue.rawValue).font(.caption).foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    Section {
                        Button(sending ? "Sending…" : "Send with the core") { send(form) }
                            .disabled(sending)
                        if !status.isEmpty { Text(status).font(.footnote) }
                    }
                } else {
                    Text(status.isEmpty ? "Loading the form…" : status)
                }
            }
            .navigationTitle("Own UI")
        }
        .navigationViewStyle(.stack)
        .task {
            Faro.shared.prepare()
            form = Faro.shared.cachedForm(locale: ExampleSettings.locale)
            do {
                form = try await Faro.shared.form(locale: ExampleSettings.locale)
                kind = form?.kinds.first ?? .question
            } catch {
                status = error.localizedDescription
                // Offline with nothing cached: the SDK's minimal form, with our own labels.
                if form == nil { form = .fallback(locale: ExampleSettings.locale) }
            }
        }
        // Leaving the screen: stop a proof still being solved (a solved one is kept).
        .onDisappear { Faro.shared.cancelPending() }
    }

    private func send(_ form: FaroForm) {
        issues = form.validate(kind: kind, values: values)
        guard issues.isEmpty else {
            status = "Fix: " + issues.keys.sorted().joined(separator: ", ")
            return
        }
        sending = true
        Task {
            defer { sending = false }
            do {
                let ticket = try await Faro.shared.send(form.request(kind: kind, values: values))
                status = "Request #\(ticket.number), replies to \(ticket.email)"
            } catch FaroError.invalidForm(let field) {
                issues = [field: .invalid]
                status = "Faro says \(field) is not valid"
            } catch {
                status = error.localizedDescription
            }
        }
    }
}
