import SwiftUI

struct ContentView: View {
    @State private var token = KeychainStore.load()
    @State private var botID = ""
    @State private var command = "outfit"
    @State private var status = "Add your FNLB token to get started."
    @State private var busy = false
    private let commands = ["outfit", "emote", "pickaxe", "backbling", "say"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RAMN").font(.system(size: 38, weight: .black, design: .rounded))
                    Text("FNLB CONTROL PANEL").font(.caption).tracking(3).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)

                GroupBox("API TOKEN") {
                    VStack(spacing: 10) {
                        SecureField("Paste FNLB token", text: $token)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        HStack {
                            Button("Save securely") {
                                status = KeychainStore.save(token) ? "Token saved on this iPhone." : "Could not save token."
                            }.buttonStyle(.borderedProminent)
                            Button("Forget", role: .destructive) {
                                KeychainStore.clear(); token = ""; status = "Saved token removed."
                            }.buttonStyle(.bordered)
                        }
                    }
                }

                GroupBox("BOT") {
                    VStack(spacing: 12) {
                        TextField("Bot ID", text: $botID)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Picker("Command", selection: $command) {
                            ForEach(commands, id: \.self) { Text($0.capitalized).tag($0) }
                        }.pickerStyle(.menu)
                        Button {
                            Task { await runCommand() }
                        } label: {
                            HStack { if busy { ProgressView().tint(.white) }; Text("Run command") }
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).disabled(busy || token.isEmpty || botID.isEmpty)
                    }
                }

                Text(status).font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @MainActor
    private func runCommand() async {
        // Endpoint and payload are provisional until confirmed against FNLB's current API documentation.
        busy = true
        defer { busy = false }
        guard let url = URL(string: "https://api.fnlb.net/v1/bots/\(botID)/commands/run") else {
            status = "Invalid bot ID."; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["command": command])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            status = "HTTP \(code): \(body.prefix(500))"
        } catch { status = "Request failed: \(error.localizedDescription)" }
    }
}
