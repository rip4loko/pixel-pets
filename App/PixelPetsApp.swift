import SwiftUI

@main
struct PixelPetsApp: App {
    init() {
        Parade.registerFontsFromWidget()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var status = "Les persos défilent dans l'île, au hasard."
    @State private var running = Parade.isRunning
    @State private var previewStart = Parade.randomStart()
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]
    private let pink = Color(hex: 0xff6fa3)

    var body: some View {
        ZStack {
            Color(hex: 0x14121c).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Pixel Pets")
                        .font(.system(size: 34, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.7))

                    preview

                    Button {
                        Task {
                            if running {
                                await Parade.stop()
                                status = "L'île est vide."
                            } else {
                                status = await Parade.start()
                            }
                            running = Parade.isRunning
                        }
                    } label: {
                        Text(running ? "Arrêter le défilé" : "Lancer le défilé")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 25)
                                .fill(running ? Color.white.opacity(0.2) : pink))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text("La troupe")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.top, 6)

                    TimelineView(.periodic(from: .now, by: 0.35)) { timeline in
                        let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.35)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Pet.all.indices, id: \.self) { i in
                                // Chacun bouge à son rythme.
                                let t = tick + i * 7
                                PixelSprite(pet: Pet.all[i], frame: (t % 23 < 2) ? 2 : t % 2, pixel: 3.5)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x1e1a29)))
                                    .accessibilityLabel(Pet.all[i].name)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // À chaque ouverture : le défilé repart au hasard, pour 8 h de plus.
            guard phase == .active else { return }
            previewStart = Parade.randomStart()
            Task {
                status = await Parade.start()
                running = Parade.isRunning
            }
        }
    }

    /// Ce que tu verras dans l'île et sur l'écran verrouillé.
    private var preview: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                ParadeStrip(start: previewStart, font: Parade.fontLeft, width: Parade.sideWidth)
                Capsule().fill(Color(hex: 0x2a2436)).frame(width: 60, height: 10)
                    .padding(.horizontal, 12)
                ParadeStrip(start: previewStart, font: Parade.fontRight, width: Parade.sideWidth)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(.black))

            ParadeStrip(start: previewStart, font: Parade.fontWide, width: Parade.wideWidth)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.5)))
        }
        .frame(maxWidth: .infinity)
    }
}
