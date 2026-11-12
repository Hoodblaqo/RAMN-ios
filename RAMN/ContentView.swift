import SwiftUI

private struct RAMNBot: Identifiable, Hashable {
    let id: String
    let name: String
    let flags: Int
    var unavailable: Bool { flags & 5 != 0 }
    var state: String {
        if flags & 4 != 0 { return "Invalid Epic auth" }
        if flags & 1 != 0 { return "Disabled" }
        if flags & 2 != 0 { return "Public bot" }
        return "Your FNLB bot"
    }
}
private struct RAMNItem: Identifiable {
    let id: String
    let name: String
    let rarity: String
    let imageURL: URL?
}

struct ContentView: View {
    @State private var token = KeychainStore.load()
    @State private var bots: [RAMNBot] = []
    @State private var selectedBot: RAMNBot?
    @State private var category = "Outfits"
    @State private var items: [RAMNItem] = []
    @State private var search = ""
    @State private var message = ""
    @State private var status = "Connect your FNLB account to get started."
    @State private var loading = false
    @State private var loadingItems = false
    @State private var tab = "Home"
    @State private var tokenTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @State private var lastHTTP = 0
    private let purple = Color(red: 0.62, green: 0.32, blue: 1)
    private let panel = Color(red: 0.075, green: 0.075, blue: 0.13)
    private let categories = ["Outfits", "Emotes", "Pickaxes", "Back Blings"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.025, blue: 0.09), Color(red: 0.015, green: 0.02, blue: 0.045), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if token.isEmpty { tokenSetup }
                        else {
                            if tab == "Home" { home }
                            else if tab == "Locker" { locker }
                            else if tab == "Chat" { chat }
                            else { settings }
                        }
                    }.padding(.horizontal, 17).padding(.top, 18).padding(.bottom, 24)
                }
                if !token.isEmpty { tabBar }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear { if !token.isEmpty { Task { await fetchBots() } } }
        .onChange(of: token) { value in
            tokenTask?.cancel()
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                bots = []; selectedBot = nil; status = "Paste your FNLB token to connect."; return
            }
            tokenTask = Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if !Task.isCancelled {
                    _ = KeychainStore.save(clean)
                    await fetchBots()
                }
            }
        }
        .onChange(of: category) { _ in Task { await fetchItems() } }
        .onChange(of: search) { _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled { await fetchItems() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [purple, Color(red: 0.28, green: 0.08, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "crown.fill").font(.system(size: 21, weight: .black)).foregroundStyle(.white)
            }.frame(width: 43, height: 43)
            VStack(alignment: .leading, spacing: 2) {
                Text("RAMN").font(.system(size: 22, weight: .black, design: .rounded)).tracking(1.5)
                Text("FORTNITE CONTROL").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.42))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(token.isEmpty ? .gray : (bots.isEmpty ? .orange : .green)).frame(width: 7, height: 7)
                Text(token.isEmpty ? "OFFLINE" : (bots.isEmpty ? "SYNCING" : "ONLINE")).font(.system(size: 9, weight: .heavy)).tracking(0.8)
            }.padding(.horizontal, 10).padding(.vertical, 9).background(.white.opacity(0.07), in: Capsule())
        }.padding(.horizontal, 17).padding(.vertical, 12).background(.black.opacity(0.28))
    }

    private var tokenSetup: some View {
        VStack(alignment: .leading, spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [Color(red: 0.27, green: 0.08, blue: 0.62), Color(red: 0.08, green: 0.04, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: "crown.fill").font(.system(size: 31)).foregroundStyle(.white)
                    Text("YOUR CONTROL\nROOM").font(.system(size: 31, weight: .black, design: .rounded))
                    Text("One token. Your whole squad.").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.68))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            }.frame(height: 190)
            VStack(alignment: .leading, spacing: 12) {
                Label("CONNECT FNLB", systemImage: "lock.shield.fill").font(.system(size: 10, weight: .heavy)).tracking(1.6).foregroundStyle(purple)
                Text("Paste your API token").font(.system(size: 21, weight: .bold, design: .rounded))
                SecureField("FNLB_…", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled().padding(15).background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.09)))
                Text("Your token is stored in this iPhone’s Keychain. It is used to load your own bots.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                if loading { ProgressView("Checking token and loading bots…").tint(purple) }
                Text(status).font(.system(size: 12, weight: .medium)).foregroundStyle(status.contains("failed") || status.contains("rejected") ? .orange : .white.opacity(0.6))
            }.padding(17).background(panel, in: RoundedRectangle(cornerRadius: 22))
            Label("Automatic bot discovery", systemImage: "bolt.fill").foregroundStyle(.white.opacity(0.7))
            Label("Cosmetic previews and search", systemImage: "sparkles").foregroundStyle(.white.opacity(0.7))
            Label("No bot ID entry required", systemImage: "checkmark.shield.fill").foregroundStyle(.white.opacity(0.7))
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WELCOME BACK").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(purple)
                Text("Your squad.\nYour control.").font(.system(size: 31, weight: .black, design: .rounded))
                Text("Manage your FNLB bots from one place.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 11) {
                statCard(title: "YOUR BOTS", value: "\(bots.count)", icon: "gamecontroller.fill")
                statCard(title: "AVAILABLE", value: "\(bots.filter { !$0.unavailable }.count)", icon: "bolt.fill")
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("YOUR SQUAD").font(.system(size: 10, weight: .heavy)).tracking(1.8).foregroundStyle(purple)
                    Spacer()
                    Button("Refresh") { Task { await fetchBots() } }.font(.system(size: 11, weight: .bold)).foregroundStyle(purple).disabled(loading)
                }
                if loading && bots.isEmpty { ProgressView("Loading bots…").tint(purple).padding(.vertical, 12) }
                else if bots.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 24)).foregroundStyle(purple)
                        Text("No bots loaded").font(.system(size: 16, weight: .bold))
                        Text(status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                        Button("Try again") { Task { await fetchBots() } }.buttonStyle(.borderedProminent).tint(purple)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(panel, in: RoundedRectangle(cornerRadius: 19))
                } else {
                    ForEach(bots) { bot in botRow(bot) }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("QUICK ACCESS").font(.system(size: 10, weight: .heavy)).tracking(1.8).foregroundStyle(purple)
                HStack(spacing: 10) {
                    quickButton("Outfits", icon: "person.fill", tint: purple) { tab = "Locker"; category = "Outfits" }
                    quickButton("Emotes", icon: "figure.dance", tint: .cyan) { tab = "Locker"; category = "Emotes" }
                }
                HStack(spacing: 10) {
                    quickButton("Pickaxes", icon: "hammer.fill", tint: .orange) { tab = "Locker"; category = "Pickaxes" }
                    quickButton("Back Blings", icon: "backpack.fill", tint: .green) { tab = "Locker"; category = "Back Blings" }
                }
            }
            statusLine
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(purple).font(.system(size: 17))
            Text(value).font(.system(size: 27, weight: .black, design: .rounded))
            Text(title).font(.system(size: 9, weight: .heavy)).tracking(1.2).foregroundStyle(.white.opacity(0.45))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func botRow(_ bot: RAMNBot) -> some View {
        Button { selectedBot = bot } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [purple.opacity(0.45), Color.blue.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "gamecontroller.fill").font(.system(size: 19)).foregroundStyle(.white)
                }.frame(width: 47, height: 47)
                VStack(alignment: .leading, spacing: 4) {
                    Text(bot.name).font(.system(size: 14, weight: .bold))
                    Text(bot.state.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(bot.unavailable ? .orange : .green)
                }
                Spacer()
                if selectedBot?.id == bot.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(purple).font(.system(size: 21)) }
                else { Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3)).font(.system(size: 12, weight: .bold)) }
            }.padding(12).background(selectedBot?.id == bot.id ? purple.opacity(0.17) : panel, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(selectedBot?.id == bot.id ? purple.opacity(0.8) : .white.opacity(0.06)))
        }.buttonStyle(.plain).disabled(bot.unavailable)
    }

    private func quickButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(tint)
                Text(title).font(.system(size: 13, weight: .bold))
                Text("Browse collection").font(.system(size: 10)).foregroundStyle(.white.opacity(0.42))
            }.frame(maxWidth: .infinity, minHeight: 83, alignment: .leading).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }

    private var locker: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("THE LOCKER").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(purple)
            Text("Cosmetic browser").font(.system(size: 27, weight: .black, design: .rounded))
            Text("Preview Fortnite cosmetics, then send the matching command to your selected bot.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            if let bot = selectedBot {
                HStack { Image(systemName: "gamecontroller.fill").foregroundStyle(purple); Text("Controlling: \(bot.name)").font(.system(size: 12, weight: .semibold)); Spacer() }
                    .padding(12).background(panel, in: RoundedRectangle(cornerRadius: 13))
            } else {
                Text("Choose an available bot on Home before applying items.").font(.system(size: 11)).foregroundStyle(.orange)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { value in
                        Button { category = value } label: {
                            Text(value).font(.system(size: 11, weight: .bold)).padding(.horizontal, 13).padding(.vertical, 10)
                                .background(category == value ? purple : .white.opacity(0.07), in: Capsule()).foregroundStyle(.white)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                TextField("Search cosmetics…", text: $search).font(.system(size: 13)).textInputAutocapitalization(.never)
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4)) } }
            }.padding(13).background(panel, in: RoundedRectangle(cornerRadius: 14))
            if loadingItems { ProgressView("Loading cosmetics…").tint(purple).frame(maxWidth: .infinity).padding(22) }
            else if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(purple)
                    Text("No cosmetics found").font(.system(size: 14, weight: .bold))
                    Text("Try another search or switch category.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                }.frame(maxWidth: .infinity).padding(25).background(panel, in: RoundedRectangle(cornerRadius: 17))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                    ForEach(items) { item in
                        Button { Task { await apply(item) } } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [purple.opacity(0.18), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    if let url = item.imageURL {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image { image.resizable().scaledToFit().padding(6) }
                                            else if phase.error != nil { Image(systemName: "photo").foregroundStyle(.white.opacity(0.3)) }
                                            else { ProgressView().tint(purple) }
                                        }
                                    } else { Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(purple) }
                                }.frame(height: 132)
                                Text(item.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                                Text(item.rarity.uppercased()).font(.system(size: 8, weight: .heavy)).tracking(1).foregroundStyle(purple)
                            }.foregroundStyle(.white).padding(9).background(panel, in: RoundedRectangle(cornerRadius: 17))
                        }.buttonStyle(.plain).disabled(selectedBot == nil || selectedBot?.unavailable == true || loading)
                    }
                }
            }
            statusLine
        }.task { if items.isEmpty { await fetchItems() } }
    }

    private var chat: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("BOT CHAT").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(purple)
            Text("Send a message").font(.system(size: 27, weight: .black, design: .rounded))
            Text("This sends a chat message through FNLB’s documented chat endpoint, not a bot command.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            if let bot = selectedBot { Text("Sending as \(bot.name)").font(.system(size: 12, weight: .semibold)).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 13)) }
            TextField("Write a message…", text: $message, axis: .vertical).lineLimit(2...5).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 14))
            Button { Task { await sendChat() } } label: {
                Label(loading ? "Sending…" : "Send message", systemImage: "paperplane.fill").font(.system(size: 13, weight: .bold)).frame(maxWidth: .infinity).padding(15)
            }.buttonStyle(.borderedProminent).tint(purple).disabled(selectedBot == nil || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
            statusLine
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("SETTINGS").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(purple)
            Text("Account & security").font(.system(size: 27, weight: .black, design: .rounded))
            Label("FNLB token stored in iPhone Keychain", systemImage: "lock.fill").padding(15).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 15))
            Button { Task { await fetchBots() } } label: { Label("Refresh bot list", systemImage: "arrow.clockwise").frame(maxWidth: .infinity).padding(13) }.buttonStyle(.bordered).tint(purple).disabled(loading)
            Button(role: .destructive) {
                tokenTask?.cancel(); KeychainStore.clear(); token = ""; bots = []; selectedBot = nil; status = "Token removed."
            } label: { Label("Disconnect and forget token", systemImage: "trash").frame(maxWidth: .infinity).padding(13) }.buttonStyle(.bordered)
            Text("RAMN uses the official FNLB REST API. Never share your API token with anyone.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            statusLine
        }
    }

    private var statusLine: some View {
        Text(lastHTTP == 0 ? status : "HTTP \(lastHTTP) · \(status)")
            .font(.system(size: 11, weight: .medium)).foregroundStyle(status.lowercased().contains("fail") || status.lowercased().contains("rejected") || status.lowercased().contains("error") ? .orange : .white.opacity(0.48))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Home", "house.fill")
            tabButton("Locker", "square.grid.2x2.fill")
            tabButton("Chat", "bubble.left.and.bubble.right.fill")
            tabButton("Settings", "gearshape.fill")
        }.padding(.top, 10).padding(.bottom, 7).frame(maxWidth: .infinity).background(.black.opacity(0.82).ignoresSafeArea(edges: .bottom))
    }
    private func tabButton(_ name: String, _ icon: String) -> some View {
        Button { tab = name } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(name.uppercased()).font(.system(size: 8, weight: .heavy)).tracking(0.8)
            }.foregroundStyle(tab == name ? purple : .white.opacity(0.38)).frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    @MainActor private func fetchBots() async {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let url = URL(string: "https://api.fnlb.net/v1/bots") else { return }
        loading = true; lastHTTP = 0; status = "Loading bots from FNLB…"
        defer { loading = false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            lastHTTP = code
            guard (200...299).contains(code) else {
                let detail = String(data: data, encoding: .utf8) ?? "No response body"
                status = code == 401 || code == 403 ? "FNLB rejected this token or its permissions. Check the API token in FNLB." : "FNLB bot lookup failed: \(detail.prefix(180))"
                bots = []; selectedBot = nil; return
            }
            // FNLB documents GET /bots as an array; accept common data envelopes too.
            let decoded: [RAMNBotDTO]
            if let rows = try? JSONDecoder().decode([RAMNBotDTO].self, from: data) {
                decoded = rows
            } else if let envelope = try? JSONDecoder().decode(RAMNBotsEnvelope.self, from: data) {
                decoded = envelope.data ?? envelope.bots ?? []
            } else {
                let body = String(data: data, encoding: .utf8) ?? "Unrecognized response"
                status = "FNLB returned an unexpected bot-list format: " + String(body.prefix(220))
                bots = []; selectedBot = nil; return
            }
            bots = decoded.map { RAMNBot(id: $0.id, name: $0.nickname, flags: $0.flags) }
            if selectedBot == nil || !bots.contains(selectedBot!) { selectedBot = bots.first(where: { !$0.unavailable }) }
            status = bots.isEmpty ? "Connected, but this FNLB account has no bots." : "Connected · loaded \(bots.count) bot(s)."
            if bots.isEmpty { selectedBot = nil }
        } catch {
            status = "Could not reach FNLB: \(error.localizedDescription)"
            bots = []; selectedBot = nil
        }
    }

    @MainActor private func fetchItems() async {
        loadingItems = true
        defer { loadingItems = false }
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://fortnite-api.com/v2/cosmetics/br/search/all")
        components?.queryItems = [URLQueryItem(name: "language", value: "en")]
        if !term.isEmpty { components?.queryItems?.append(URLQueryItem(name: "name", value: term)) }
        guard let url = components?.url else { return }
        do {
            var request = URLRequest(url: url); request.timeoutInterval = 25
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) == true else {
                items = []; status = "Cosmetics service returned an error."; return
            }
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let rows = root?["data"] as? [[String: Any]] ?? []
            let wanted = ["Outfits": "outfit", "Emotes": "emote", "Pickaxes": "pickaxe", "Back Blings": "backpack"][category] ?? "outfit"
            items = rows.compactMap { row in
                let type = ((row["type"] as? [String: Any])?["value"] as? String ?? "").lowercased()
                guard type == wanted else { return nil }
                let images = row["images"] as? [String: Any] ?? [:]
                let raw = (images["icon"] as? String) ?? (images["smallIcon"] as? String)
                return RAMNItem(id: row["id"] as? String ?? UUID().uuidString,
                    name: row["name"] as? String ?? "Unknown item",
                    rarity: (row["rarity"] as? [String: Any])?["displayValue"] as? String ?? "Cosmetic",
                    imageURL: raw.flatMap(URL.init(string:)))
            }.prefix(40).map { $0 }
        } catch { items = []; status = "Cosmetics failed to load: \(error.localizedDescription)" }
    }

    @MainActor private func apply(_ item: RAMNItem) async {
        let command = ["Outfits": "outfit", "Emotes": "emote", "Pickaxes": "pickaxe", "Back Blings": "backbling"][category] ?? "outfit"
        await runCommand(command: command, args: item.name)
    }

    @MainActor private func runCommand(command: String, args: String) async {
        guard let bot = selectedBot else { status = "Select an available bot first."; return }
        guard let url = URL(string: "https://api.fnlb.net/v1/bots/\(bot.id)/commands/run") else { return }
        loading = true; lastHTTP = 0
        defer { loading = false }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["command": command, "args": args, "locale": "en"])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0; lastHTTP = code
            guard (200...299).contains(code) else {
                status = "FNLB rejected command: \(String(data: data, encoding: .utf8)?.prefix(180) ?? "No details")"; return
            }
            let result = try? JSONDecoder().decode(RAMNCommandDTO.self, from: data)
            status = result?.content ?? "FNLB accepted the command."
            if result?.format == 4 { status = "Bot error: " + (result?.content ?? "Command failed.") }
        } catch { status = "Command request failed: \(error.localizedDescription)" }
    }

    @MainActor private func sendChat() async {
        guard let bot = selectedBot else { status = "Select an available bot first."; return }
        guard let url = URL(string: "https://api.fnlb.net/v1/bots/\(bot.id)/chat/messages") else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        loading = true; lastHTTP = 0
        defer { loading = false }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["content": text, "locale": "en"])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0; lastHTTP = code
            guard (200...299).contains(code) else { status = "FNLB chat failed: \(String(data: data, encoding: .utf8)?.prefix(180) ?? "No details")"; return }
            let result = try? JSONDecoder().decode(RAMNCommandDTO.self, from: data)
            status = result?.content ?? "Message sent."
            if result?.format == 4 { status = "Bot response: " + (result?.content ?? "Message failed.") }
            else { message = "" }
        } catch { status = "Chat request failed: \(error.localizedDescription)" }
    }
}

private struct RAMNBotDTO: Decodable {
    let id: String
    let nickname: String
    let flags: Int
}
private struct RAMNBotsEnvelope: Decodable {
    let data: [RAMNBotDTO]?
    let bots: [RAMNBotDTO]?
}
private struct RAMNCommandDTO: Decodable {
    let content: String?
    let format: Int?
}
