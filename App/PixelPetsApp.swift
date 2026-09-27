import SwiftUI

@main
struct PixelPetsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var selected = 0
    @State private var status = "Choisis un pet, puis mets-le dans l'île."
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]
    private let pink = Color(hex: 0xff6fa3)
    private let lilac = Color(hex: 0x9d7be8)

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

                    HStack(spacing: 10) {
                        actionButton("Dans l'île", pink) {
                            status = await PetEngine.start(petIndex: selected)
                        }
                        actionButton("Au hasard", lilac) {
                            let i = PetEngine.randomOther(than: selected)
                            selected = i
                            status = await PetEngine.start(petIndex: i)
                        }
                        actionButton("Retirer", Color.white.opacity(0.25)) {
                            await PetEngine.stopAll()
                            status = "L'île est vide."
                        }
                    }

                    TimelineView(.periodic(from: .now, by: 0.35)) { timeline in
                        let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.35)
                        let frame = (tick % 26 < 2) ? 2 : tick % 2
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Pet.all.indices, id: \.self) { i in
                                petCard(i, frame: frame)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // À chaque retour dans l'app, un nouveau pet passe dans l'île.
            if phase == .active && PetEngine.isRunning {
                Task { await PetEngine.shuffle() }
            }
        }
    }

    private func petCard(_ i: Int, frame: Int) -> some View {
        let pet = Pet.all[i]
        return Button {
            selected = i
        } label: {
            VStack(spacing: 6) {
                PixelSprite(pet: pet, frame: frame, pixel: 4)
                Text(pet.name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1e1a29)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(i == selected ? pink : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pet.name)
    }

    private func actionButton(_ title: String, _ color: Color, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 22).fill(color))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
