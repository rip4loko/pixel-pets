import ActivityKit
import CoreText
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

    /// Point de départ au hasard dans le film d'1 h. Au moins 10 min écoulées,
    /// pour que le minuteur affiche toujours « mm:ss ».
    static func randomStart() -> Date {
        Date().addingTimeInterval(-Double(600 + Int.random(in: 0..<3600)))
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

    /// L'app n'embarque pas les polices : elle emprunte celles du widget.
    static func registerFontsFromWidget() {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: plugins.appendingPathComponent("PixelPetsWidget.appex"),
                includingPropertiesForKeys: nil)
        else { return }
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Une bande du défilé. Le texte du minuteur est remplacé par l'image par la police.
struct ParadeStrip: View {
    let start: Date
    let font: String
    let width: CGFloat

    var body: some View {
        Text(timerInterval: start...start.addingTimeInterval(172_800), countsDown: false)
            .font(.custom(font, fixedSize: Parade.fontSize))
            .lineLimit(1)
            // L'image est toujours à la fin du texte (après « 1: » quand il y a des heures) :
            // on garde la taille naturelle du texte et on cale sa fin sur le bord droit.
            .multilineTextAlignment(.trailing)
            .fixedSize()
            .frame(width: width, height: Parade.fontSize, alignment: .trailing)
            .clipped()
            .accessibilityLabel("Défilé de Pixel Pets")
    }
}
