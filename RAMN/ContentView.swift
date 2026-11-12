import SwiftUI

private struct RAMNBot: Identifiable, Hashable {
    let id: String
    let name: String
    let flags: Int
    var unavailable: Bool { flags & 5 != 0 }
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
    @State private var status = "Paste your FNLB token to load your bots."
    @State private var loading = false
    @State private var loadingItems = false
    @State private var tab = "Locker"
    @State private var tokenTask: Task<Void, Never>?
    private let purple = Color(red: 0.62, green: 0.42, blue: 1)
    private let panel = Color(red: 0.085, green: 0.10, blue: 0.16)
    private let categories = ["Outfits", "Emotes", "Pickaxes", "Back Blings"]

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.065).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if token.isEmpty { tokenSetup }
                        else {
                            botPicker
                            if tab == "Locker" { locker }
                            else if tab == "Chat" { chat }
                            else { settings }
                        }
                    }.padding(18)
                }
                if !token.isEmpty { tabBar }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !token.isEmpty { Task { await fetchBots() } } }
        .onChange(of: token) { value in
            tokenTask?.cancel()
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { bots = []; selectedBot = nil; return }
            tokenTask = Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                if !Task.isCancelled {
                    _ = KeychainStore.save(clean)
                    await fetchBots()
                }
            }
        }
        .onChange(of: category) { _ in Task { await fetchItems() } }
        .onChange(of: search) {
            _ in Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if !Task.isCancelled { await fetchItems() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(purple.gradient)
                Text("R").font(.system(size: 25, weight: .black, design: .rounded))
            }.frame(width: 43, height: 43)
            VStack(alignment: .leading, spacing: 1) {
                Text("RAMN").font(.system(size: 22, weight: .black, design: .rounded)).tracking(1.5)
                Text("CONTROL CENTER").font(.system(size: 9, weight: .bold)).tracking(2.3).foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(token.isEmpty ? .gray : .green).frame(width: 7, height: 7)
                Text(token.isEmpty ? "OFFLINE" : "CONNECTED").font(.system(size: 9, weight: .bold))
            }.padding(10).background(.white.opacity(0.07), in: Capsule())
        }.padding(.horizontal, 18).padding(.vertical, 12).background(.black.opacity(0.25))
    }

    private var tokenSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR CONTROL ROOM").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple)
            Text("One token.\nYour whole squad.").font(.system(size: 34, weight: .black, design: .rounded))
            Text("Paste your FNLB API token. RAMN will automatically look up the bots on your account.")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.58))
            VStack(alignment: .leading, spacing: 11) {
                Label("FNLB API TOKEN", systemImage: "key.fill").font(.system(size: 10, weight: .bold)).tracking(1.4)
                SecureField("Paste token here", text: $token)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(15).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                Text("Stored securely in iPhone Keychain.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 20))
            if loading { ProgressView("Finding your bots…").tint(purple) }
            Text(status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
        }
    }

    private var botPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR SQUAD").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple)
                    Text("Choose a bot").font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("\(bots.count) BOTS").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.5))
            }
            if loading && bots.isEmpty { ProgressView().tint(purple) }
            else if bots.isEmpty {
                Text(status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(bots) { bot in
                            Button { selectedBot = bot } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Image(systemName: "gamecontroller.fill").font(.system(size: 19))
                                        Spacer()
                                        if selectedBot?.id == bot.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(purple) }
                                    }
                                    Text(bot.name).font(.system(size: 14, weight: .bold)).lineLimit(1)
                                    Text(bot.unavailable ? "UNAVAILABLE" : "AVAILABLE")
                                        .font(.system(size: 8, weight: .heavy)).tracking(1)
                                        .foregroundStyle(bot.unavailable ? .orange : .green)
                                }.foregroundStyle(.white).padding(13).frame(width: 145, height: 105, alignment: .leading)
                                    .background(selectedBot?.id == bot.id ? purple.opacity(0.22) : panel, in: RoundedRectangle(cornerRadius: 17))
                                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(selectedBot?.id == bot.id ? purple : .white.opacity(0.07), lineWidth: 1))
                            }.buttonStyle(.plain).disabled(bot.unavailable)
                        }
                    }
                }
            }
        }
    }

    private var locker: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("THE LOCKER").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple)
                    Text("Cosmetic browser").font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { value in
                        Button { category = value } label: {
                            Text(value).font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(category == value ? purple : .white.opacity(0.07), in: Capsule())
                                .foregroundStyle(.white)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                TextField("Search Fortnite cosmetics", text: $search).font(.system(size: 13)).textInputAutocapitalization(.never)
            }.padding(13).background(panel, in: RoundedRectangle(cornerRadius: 13))
            if loadingItems { ProgressView("Loading item images…").tint(purple).frame(maxWidth: .infinity).padding() }
            else if items.isEmpty {
                Text("Search for an item to see its image here.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity).padding(24).background(panel, in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items) { item in
                        Button { Task { await apply(item) } } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.055))
                                    if let url = item.imageURL {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image { image.resizable().scaledToFit().padding(7) }
                                            else if phase.error != nil { Image(systemName: "photo").foregroundStyle(.white.opacity(0.25)) }
                                            else { ProgressView().tint(purple) }
                                        }
                                    } else { Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(purple) }
                                }.frame(height: 128)
                                Text(item.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                                Text(item.rarity.uppercased()).font(.system(size: 8, weight: .heavy)).tracking(1).foregroundStyle(purple)
                            }.foregroundStyle(.white).padding(9).background(panel, in: RoundedRectangle(cornerRadius: 17))
                        }.buttonStyle(.plain).disabled(selectedBot == nil || loading)
                    }
                }
            }
            Text(selectedBot == nil ? "Select a bot above to apply cosmetics." : "Tap an item to send it to \(selectedBot?.name ?? "your bot").")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            Text(status).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
        }
    }

    private var chat: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BOT CHAT").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple)
            Text("Send a message").font(.system(size: 23, weight: .bold, design: .rounded))
            TextField("Type your message", text: $message).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 13))
            Button { Task { await run(command: "say", args: [message]) } } label: {
                Label("Send to selected bot", systemImage: "paperplane.fill").frame(maxWidth: .infinity).padding(14)
            }.buttonStyle(.borderedProminent).tint(purple).disabled(selectedBot == nil || message.isEmpty || loading)
            Text(status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SETTINGS").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(purple)
            Text("Account & security").font(.system(size: 23, weight: .bold, design: .rounded))
            Label("FNLB token saved in Keychain", systemImage: "lock.fill").padding(15).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 14))
            Button(role: .destructive) {
                KeychainStore.clear(); token = ""; bots = []; selectedBot = nil; status = "Token removed."
            } label: { Label("Forget token", systemImage: "trash").frame(maxWidth: .infinity).padding(13) }.buttonStyle(.bordered)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Locker", "square.grid.2x2.fill")
            tabButton("Chat", "bubble.left.and.bubble.right.fill")
            tabButton("Settings", "gearshape.fill")
        }.padding(.top, 11).padding(.bottom, 7).background(.black.opacity(0.55))
    }
    private func tabButton(_ name: String, _ icon: String) -> some View {
        Button { tab = name } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17))
                Text(name.uppercased()).font(.system(size: 8, weight: .bold)).tracking(1)
            }.foregroundStyle(tab == name ? purple : .white.opacity(0.4)).frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    @MainActor private func fetchBots() async {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let url = URL(string: "https://api.fnlb.net/v1/bots") else { return }
        loading = true
        defer { loading = false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                status = code == 401 ? "Token rejected. Check your FNLB token." : "Bot lookup failed (HTTP \(code))."
                bots = []; selectedBot = nil; return
            }
            let json = try JSONSerialization.jsonObject(with: data)
            let rows = (json as? [[String: Any]]) ?? ((json as? [String: Any])?["data"] as? [[String: Any]]) ?? []
            bots = rows.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return RAMNBot(id: id, name: row["nickname"] as? String ?? "Unnamed bot", flags: row["flags"] as? Int ?? 0)
            }
            if selectedBot == nil || !bots.contains(selectedBot!) { selectedBot = bots.first(where: { !$0.unavailable }) }
            status = bots.isEmpty ? "No bots found on this account." : "Loaded \(bots.count) bots."
            if items.isEmpty { await fetchItems() }
        } catch { status = "Bot lookup failed: \(error.localizedDescription)" }
    }

    @MainActor private func fetchItems() async {
        loadingItems = true
        defer { loadingItems = false }
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "a" : search
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://fortnite-api.com/v2/cosmetics/br/search/all?name=\(encoded)&language=en") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let rows = root?["data"] as? [[String: Any]] ?? []
            let wanted = ["Outfits": "outfit", "Emotes": "emote", "Pickaxes": "pickaxe", "Back Blings": "backpack"][category] ?? "outfit"
            items = rows.compactMap { row in
                let type = ((row["type"] as? [String: Any])?["value"] as? String ?? "").lowercased()
                guard type == wanted else { return nil }
                let images = row["images"] as? [String: Any] ?? [:]
                let rawImage = (images["icon"] as? String) ?? (images["smallIcon"] as? String)
                return RAMNItem(id: row["id"] as? String ?? UUID().uuidString,
                                name: row["name"] as? String ?? "Unknown item",
                                rarity: (row["rarity"] as? [String: Any])?["displayValue"] as? String ?? "Cosmetic",
                                imageURL: rawImage.flatMap(URL.init(string:)))
            }.prefix(30).map { $0 }
        } catch { status = "Cosmetic images couldn't load. Check your connection." }
    }

    @MainActor private func apply(_ item: RAMNItem) async {
        let command = ["Outfits": "outfit", "Emotes": "emote", "Pickaxes": "pickaxe", "Back Blings": "backbling"][category] ?? "outfit"
        await run(command: command, args: [item.name])
    }

    @MainActor private func run(command: String, args: [String]) async {
        guard let bot = selectedBot else { status = "Select a bot first."; return }
        guard let url = URL(string: "https://api.fnlb.net/v1/bots/\(bot.id)/commands/run") else { return }
        loading = true
        defer { loading = false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["command": command, "args": args, "locale": "en"])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            status = "HTTP \(code): \((String(data: data, encoding: .utf8) ?? "No response").prefix(220))"
            if command == "say" && code == 200 { message = "" }
        } catch { status = "Command failed: \(error.localizedDescription)" }
    }
}
