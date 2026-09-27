import ActivityKit
import AppIntents
import Foundation

/// Ce que la Live Activity affiche dans la Dynamic Island.
struct PetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var petIndex: Int
        var ventre: Int
        var humeur: Int
        var energie: Int
        var message: String
    }

    var startedAt: Date
}

/// Toute la logique : lancer, changer de pet, nourrir, jouer, arrêter.
enum PetEngine {
    static let greetings = ["Coucou !", "Bouh !", "Hihihi…", "Je te vois.", "Miaou ?", "Nyeh heh heh", "Salut toi."]

    static var isRunning: Bool { !Activity<PetAttributes>.activities.isEmpty }

    static func randomOther(than index: Int) -> Int {
        let count = Pet.all.count
        guard count > 1 else { return 0 }
        var r = Int.random(in: 0..<(count - 1))
        if r >= index { r += 1 }
        return r
    }

    /// Met un pet dans l'île (ou remplace celui qui y est déjà).
    static func start(petIndex: Int) async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "Active les Live Activities : Réglages › Pixel Pets."
        }
        let name = Pet.all[safe: petIndex].name
        if let current = Activity<PetAttributes>.activities.first {
            var s = current.content.state
            s.petIndex = petIndex
            s.message = greetings.randomElement() ?? "Coucou !"
            await current.update(ActivityContent(state: s, staleDate: nil))
            return "\(name) est dans l'île !"
        }
        let state = PetAttributes.ContentState(petIndex: petIndex, ventre: 6, humeur: 7, energie: 8,
                                               message: greetings.randomElement() ?? "Coucou !")
        do {
            _ = try Activity<PetAttributes>.request(
                attributes: PetAttributes(startedAt: Date()),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)
            return "\(name) est dans l'île !"
        } catch {
            return "Oups : \(error.localizedDescription)"
        }
    }

    /// Un pet au hasard prend la place.
    static func shuffle() async {
        await apply { s in
            s.petIndex = randomOther(than: s.petIndex)
            s.message = greetings.randomElement() ?? "Coucou !"
        }
    }

    static func stopAll() async {
        for activity in Activity<PetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func apply(_ change: (inout PetAttributes.ContentState) -> Void) async {
        for activity in Activity<PetAttributes>.activities {
            var s = activity.content.state
            change(&s)
            await activity.update(ActivityContent(state: s, staleDate: nil))
        }
    }
}

// Boutons de la Dynamic Island ouverte (iOS 17+).

struct FeedIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Nourrir"
    init() {}
    func perform() async throws -> some IntentResult {
        await PetEngine.apply { s in
            s.ventre = min(10, s.ventre + 3)
            s.message = "Miam !"
        }
        return .result()
    }
}

struct PlayIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Jouer"
    init() {}
    func perform() async throws -> some IntentResult {
        await PetEngine.apply { s in
            if s.energie <= 0 {
                s.message = "Trop fatigué…"
            } else {
                s.humeur = min(10, s.humeur + 3)
                s.energie = max(0, s.energie - 2)
                s.ventre = max(0, s.ventre - 1)
                s.message = "Youpi !"
            }
        }
        return .result()
    }
}

struct ShuffleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Autre pet"
    init() {}
    func perform() async throws -> some IntentResult {
        await PetEngine.shuffle()
        return .result()
    }
}
