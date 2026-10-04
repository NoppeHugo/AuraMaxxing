import SwiftUI

/// Crews : ton groupe de potes / ton lycée. Les points de la semaine de chaque membre s'additionnent.
struct CrewView: View {

    @EnvironmentObject private var session: SessionStore
    @State private var board: CrewBoard?
    @State private var name = ""
    @State private var code = ""
    @State private var kind = "school"
    @State private var city = ""
    @State private var rankingMode: RankingMode = .schools

    enum RankingMode: String, CaseIterable { case schools = "Lycées", city = "Ma ville", all = "Tous" }
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuraBackground(colors: [.auraCyan, .auraPurple, .auraCyan], intensity: 0.18)
                ScrollView {
                    VStack(spacing: 16) {
                        if let crew = board?.crew {
                            myCrew(crew)
                        } else if board != nil {
                            joinOrCreate
                        } else {
                            ProgressView().padding(.top, 60)
                        }
                        if let error { Text(error).foregroundStyle(Color.auraRed) }
                        if let board { rankings(board) }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
            .navigationTitle("Crews")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await load() }
    }

    // MARK: - Mon crew

    private func myCrew(_ crew: CrewBoard.MyCrew) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(crew.name).font(.system(size: 28, weight: .black, design: .rounded))
                    Text("#\(crew.rank) des crews · \(crew.points) pts cette semaine")
                        .font(.subheadline).foregroundStyle(Color.auraMuted)
                    if crew.kind == "school", let city = crew.city {
                        Text("🏫 Établissement · \(city)").font(.caption.weight(.bold)).foregroundStyle(Color.auraCyan)
                    }
                }
                Spacer()
            }
            // Le code d'invitation est fait pour être partagé en story / dans le groupe de la classe.
            ShareLink(item: "Rejoins mon crew « \(crew.name) » sur AuraMaxxing avec le code \(crew.code) 🔥") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CODE D'INVITATION").font(.caption2.weight(.heavy)).foregroundStyle(Color.auraMuted)
                        Text(crew.code).font(.system(size: 26, weight: .black, design: .monospaced)).kerning(4)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up").font(.title3)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { Analytics.track(.crewCodeShared) })

            ForEach(Array(crew.members.enumerated()), id: \.element.id) { i, m in
                HStack(spacing: 12) {
                    Text("\(i + 1)").font(.headline.weight(.black)).foregroundStyle(Color.auraMuted).frame(width: 24)
                    AvatarView(player: m, size: 38)
                    Text(m.pseudo).font(.subheadline.weight(.heavy))
                    if m.isMe == true { Text("toi").font(.caption2.weight(.bold)).foregroundStyle(Color.auraCyan) }
                    Spacer()
                    Text("\(m.points ?? 0)").font(.headline.weight(.black)).monospacedDigit()
                }
            }
            Button("Quitter le crew", role: .destructive) { Task { await leave() } }
                .font(.footnote)
                .frame(maxWidth: .infinity)
        }
        .auraCard(padding: 18)
    }

    // MARK: - Rejoindre / créer

    private var joinOrCreate: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Monte ton crew").font(.system(size: 28, weight: .black, design: .rounded))
            Text("Ton lycée ou ta bande : les points de chaque membre s'additionnent. Chaque semaine, on découvre le lycée qui a le plus d'aura de France et de ta ville.")
                .foregroundStyle(Color.auraMuted)

            field("Code d'un crew (ex. K7XP2M)", text: $code)
                .textInputAutocapitalization(.characters)
            Button("Rejoindre") { Task { await join() } }
                .buttonStyle(GlowButtonStyle())
                .disabled(busy || code.count < 6)

            HStack { line; Text("ou").foregroundStyle(Color.auraMuted); line }

            Picker("Type", selection: $kind) {
                Text("🏫 Lycée / école").tag("school")
                Text("👥 Potes").tag("friends")
            }
            .pickerStyle(.segmented)
            field(kind == "school" ? "Nom de l'établissement (ex. Lycée Victor Hugo)" : "Nom du crew (ex. Les Sigmas)", text: $name)
            if kind == "school" {
                field("Ville (ex. Lyon)", text: $city)
            }
            Button(kind == "school" ? "Créer le crew du lycée" : "Créer mon crew") { Task { await create() } }
                .buttonStyle(GhostButtonStyle())
                .disabled(busy || name.count < 3 || (kind == "school" && city.trimmingCharacters(in: .whitespaces).count < 2))
        }
        .auraCard(padding: 18)
    }

    private var line: some View { Rectangle().fill(Color.auraBorder).frame(height: 1) }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Classement des crews

    /// « Le lycée avec le plus d'aura » : France, ma ville, ou tous les crews.
    private func rankings(_ board: CrewBoard) -> some View {
        let list: [CrewBoard.CrewRow]
        switch rankingMode {
        case .schools: list = board.schools
        case .city: list = board.city?.crews ?? []
        case .all: list = board.top
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Classement · \(board.week.label)").font(.headline)
            Picker("Classement", selection: $rankingMode) {
                ForEach(RankingMode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            if rankingMode == .city, let cityName = board.city?.name {
                Text("Les lycées de \(cityName)").font(.caption).foregroundStyle(Color.auraMuted)
            }
            if list.isEmpty {
                Text(rankingMode == .city && board.city == nil
                     ? "Rejoins ou crée le crew de ton lycée pour voir le classement de ta ville."
                     : "Aucun crew ici pour l'instant. Sois le premier 👑")
                    .font(.subheadline).foregroundStyle(Color.auraMuted).padding(.vertical, 20)
            }
            ranking(list)
        }
    }

    private func ranking(_ top: [CrewBoard.CrewRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(top) { c in
                HStack {
                    Text(c.rank <= 3 ? ["🥇", "🥈", "🥉"][c.rank - 1] : "\(c.rank)").frame(width: 30)
                    VStack(alignment: .leading) {
                        Text(c.name).font(.subheadline.weight(.heavy))
                        Text("\(c.members) membre" + (c.members > 1 ? "s" : "") + (c.city.map { " · \($0)" } ?? ""))
                            .font(.caption).foregroundStyle(Color.auraMuted)
                    }
                    Spacer()
                    Text("\(c.points)").font(.headline.weight(.black)).monospacedDigit()
                }
                .padding(10)
                .background(c.isMine ? Color.auraPurple.opacity(0.3) : Color.auraCard, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        do { board = try await APIClient.shared.get("crew"); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func create() async {
        await run {
            let _: CrewRef = try await APIClient.shared.post("crew", CrewNameBody(name: name, kind: kind, city: city))
            Analytics.track(.crewCreated)
        }
    }

    private func join() async {
        await run {
            let _: CrewRef = try await APIClient.shared.post("crew/join", CrewCodeBody(code: code))
            Analytics.track(.crewJoined)
        }
    }

    private func leave() async {
        await run { let _: OkResponse = try await APIClient.shared.post("crew/leave", EmptyBody()) }
    }

    private func run(_ action: () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do {
            try await action()
            Haptics.success()
            name = ""; code = ""; city = ""
            await load()
            await session.refresh()
        } catch {
            Haptics.error()
            self.error = error.localizedDescription
        }
    }
}
