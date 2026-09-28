import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PixelPetsWidgetBundle: WidgetBundle {
    var body: some Widget {
        PetLiveActivity()
    }
}

struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetAttributes.self) { context in
            // Écran verrouillé : juste une fine bande où les persos défilent.
            ParadeStrip(start: context.state.start, font: Parade.fontWide, width: Parade.wideWidth)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.vertical, 8)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let start = context.state.start
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ParadeStrip(start: start, font: Parade.fontWide, width: Parade.wideWidth)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
            } compactLeading: {
                // Les deux moitiés d'une même scène : les persos passent derrière la caméra.
                ParadeStrip(start: start, font: Parade.fontLeft, width: Parade.sideWidth)
            } compactTrailing: {
                ParadeStrip(start: start, font: Parade.fontRight, width: Parade.sideWidth)
            } minimal: {
                PixelSprite(pet: Pet.all[safe: Int(start.timeIntervalSince1970) % Pet.all.count],
                            frame: 0, pixel: 1.3)
            }
        }
    }
}
