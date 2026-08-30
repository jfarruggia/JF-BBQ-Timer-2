// ProbeAttachSheet.swift
// Grill Time Pro
//
// Sheet that lets the user pick which cook (timer) the connected probe belongs to.
// Presented automatically when the probe connects with no cook attached.
// Visual polish is deferred to Phase 2E; this is a plain functional list.
// Gated behind #if os(iOS) — the watch never presents this UI.

#if os(iOS)

import SwiftUI

// MARK: - CookItem

/// Lightweight value type used to pass cook identity into the sheet without
/// depending on BBQTimer directly (keeps the sheet easy to preview/test).
struct CookItem: Identifiable {
    let id: UUID
    let name: String
}

// MARK: - ProbeAttachSheet

struct ProbeAttachSheet: View {

    /// The cooks the user can assign the probe to.
    let cooks: [CookItem]

    /// The probe manager that will record the attachment.
    @ObservedObject var probeManager: ProbeBLEManager

    /// Dismiss action injected by the presenting view via `.sheet`.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(cooks) { cook in
                        Button {
                            probeManager.attach(toCookID: cook.id)
                            dismiss()
                        } label: {
                            Text(cook.name)
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Choose a cook for the probe reading")
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .immersiveGlassList()
            .tint(Color("TimerAccent"))
            .navigationTitle("Attach probe to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif // os(iOS)
