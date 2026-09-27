import SwiftUI

/// Un pet = une palette + 3 frames de 16x16 pixels (normal, rebond, clignement).
struct Pet {
    let name: String
    let tag: String
    let palette: [Character: UInt32]
    let frames: [[String]]

    var colorKeys: [Character] { palette.keys.sorted() }
}

extension Array where Element == Pet {
    /// Accès sans crash : retourne le premier pet si l'index est invalide.
    subscript(safe index: Int) -> Pet {
        indices.contains(index) ? self[index] : self[0]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}

/// Dessine un pet en pixel art : un Path par couleur.
struct PixelSprite: View {
    let pet: Pet
    let frame: Int
    let pixel: CGFloat

    var body: some View {
        let rows = pet.frames[Swift.min(Swift.max(frame, 0), pet.frames.count - 1)]
        ZStack(alignment: .topLeading) {
            ForEach(pet.colorKeys, id: \.self) { key in
                Path { path in
                    for (y, row) in rows.enumerated() {
                        for (x, ch) in Array(row).enumerated() where ch == key {
                            path.addRect(CGRect(x: CGFloat(x) * pixel,
                                                y: CGFloat(y) * pixel,
                                                width: pixel,
                                                height: pixel))
                        }
                    }
                }
                .fill(Color(hex: pet.palette[key] ?? 0))
            }
        }
        .frame(width: 16 * pixel, height: 16 * pixel, alignment: .topLeading)
    }
}

/// Les 3 jauges façon Tamagotchi.
struct StatBars: View {
    let state: PetAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            bar("Ventre", state.ventre, Color(hex: 0xffd166))
            bar("Humeur", state.humeur, Color(hex: 0xff6fa3))
            bar("Énergie", state.energie, Color(hex: 0x9d7be8))
        }
    }

    private func bar(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 44, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    Rectangle()
                        .fill(i < value ? color : Color.white.opacity(0.15))
                        .frame(width: 6, height: 7)
                }
            }
        }
    }
}
