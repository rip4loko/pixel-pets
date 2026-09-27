import ActivityKit
import AppIntents
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
            // Écran verrouillé
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x14121c))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let pet = Pet.all[safe: context.state.petIndex]
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelSprite(pet: pet, frame: 0, pixel: 3.5)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(context.state.message)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: ShuffleIntent()) {
                        Image(systemName: "shuffle")
                    }
                    .tint(Color(hex: 0x9d7be8))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 10) {
                        StatBars(state: context.state)
                        Spacer(minLength: 4)
                        Button(intent: FeedIntent()) {
                            Text("Nourrir").font(.caption.bold())
                        }
                        .tint(Color(hex: 0xffd166))
                        Button(intent: PlayIntent()) {
                            Text("Jouer").font(.caption.bold())
                        }
                        .tint(Color(hex: 0xff6fa3))
                    }
                }
            } compactLeading: {
                PixelSprite(pet: pet, frame: 0, pixel: 1.4)
            } compactTrailing: {
                Image(systemName: context.state.humeur > 3 ? "heart.fill" : "heart.slash.fill")
                    .foregroundStyle(Color(hex: 0xff6fa3))
            } minimal: {
                PixelSprite(pet: pet, frame: 0, pixel: 1.3)
            }
        }
    }
}

struct LockScreenView: View {
    let state: PetAttributes.ContentState

    var body: some View {
        let pet = Pet.all[safe: state.petIndex]
        HStack(spacing: 14) {
            PixelSprite(pet: pet, frame: 0, pixel: 3.5)
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(state.message)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
                StatBars(state: state)
            }
            Spacer()
        }
        .padding(14)
    }
}
