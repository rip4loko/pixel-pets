import ActivityKit
import SwiftUI

/// La Live Activity ne stocke qu'une date : le départ du « film » du défilé.
struct PetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var start: Date
    }

    var startedAt: Date
}

/// Le défilé : un minuteur système affiché avec une police spéciale
/// (voir tools/make_fonts.py). Chaque seconde écoulée = une image du film.
enum Parade {
    static let fontLeft = "ParadeLeft"
    static let fontRight = "ParadeRight"
    static let fontWide = "ParadeWide"
    static let fontSize: CGFloat = 24
    static let sideWidth: CGFloat = 28 * 4 / 3
    static let wideWidth: CGFloat = 270 * 4 / 3

    static var isRunning: Bool { !Activity<PetAttributes>.activities.isEmpty }

    /// Point de départ au hasard dans le film d'1 h. Toujours plus d'1 h écoulée,
    /// pour que le minuteur ait toujours la même forme « h:mm:ss ».
    static func randomStart() -> Date {
        Date().addingTimeInterval(-Double(3600 + Int.random(in: 0..<3600)))
    }

    /// Relance le défilé à un endroit au hasard (et repart pour 8 h).
    static func start() async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "Active les Live Activities : Réglages › Pixel Pets."
        }
        await stop()
        let state = PetAttributes.ContentState(start: randomStart())
        do {
            _ = try Activity<PetAttributes>.request(
                attributes: PetAttributes(startedAt: Date()),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)
            return "Le défilé passe dans l'île !"
        } catch {
            return "Oups : \(error.localizedDescription)"
        }
    }

    static func stop() async {
        for activity in Activity<PetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Une bande du défilé : une couche de minuteur par couleur, empilées.
/// La police remplace le texte du minuteur par l'image (voir tools/make_fonts.py).
struct ParadeStrip: View {
    let start: Date
    let font: String
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .trailing) {
            ForEach(Parade.layerColors.indices, id: \.self) { layer in
                Text(timerInterval: start...start.addingTimeInterval(172_800), countsDown: false)
                    .font(.custom("\(font)\(layer)", fixedSize: Parade.fontSize))
                    .foregroundStyle(Color(hex: Parade.layerColors[layer]))
                    .contentTransition(.identity)
                    .lineLimit(1)
                    // Chaque caractère fait 1/5 de l'image, et « 1:02:05 » en a 7 : on laisse
                    // la place de 8 caractères pour que l'iPhone ne coupe jamais le texte.
                    // L'image est toujours à la fin : on la cale sur le bord droit.
                    .multilineTextAlignment(.trailing)
                    .frame(width: width * 8 / 5, alignment: .trailing)
            }
        }
        .frame(width: width, height: Parade.fontSize, alignment: .trailing)
        .clipped()
        .accessibilityLabel("Défilé de Pixel Pets")
    }
}
