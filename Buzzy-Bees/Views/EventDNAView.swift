//
//  EventDNAView.swift
//  Buzzy-Bees
//
//  Generates a unique deterministic visual pattern ("DNA fingerprint") for each event.
//  The pattern is derived entirely from the event's UUID — same event always produces
//  the same pattern. No two UUIDs produce the same result.
//

import SwiftUI

struct EventDNAView: View {
    let event: Event

    var body: some View {
        Canvas { context, size in
            let genes = buildGenes(size: size)

            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(genes.bgColor)
            )

            // Draw concentric rings + scattered dots
            for ring in genes.rings {
                var path = Path()
                path.addEllipse(in: CGRect(
                    x: ring.center.x - ring.radius,
                    y: ring.center.y - ring.radius,
                    width: ring.radius * 2,
                    height: ring.radius * 2
                ))
                context.stroke(path, with: .color(ring.color.opacity(ring.opacity)), lineWidth: ring.lineWidth)
            }

            for dot in genes.dots {
                var path = Path()
                path.addEllipse(in: CGRect(x: dot.x - dot.r, y: dot.y - dot.r, width: dot.r * 2, height: dot.r * 2))
                context.fill(path, with: .color(dot.color.opacity(dot.opacity)))
            }
        }
    }

    // MARK: - Deterministic gene generation

    private struct Ring {
        let center: CGPoint
        let radius: CGFloat
        let color: Color
        let opacity: Double
        let lineWidth: CGFloat
    }

    private struct Dot {
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
        let color: Color
        let opacity: Double
    }

    private struct Genes {
        let bgColor: Color
        let rings: [Ring]
        let dots: [Dot]
    }

    /// Deterministic pseudo-random value in [0, 1) from a UUID seed + index
    private func dna(_ index: Int) -> Double {
        // Use the UUID's raw bytes as entropy. XOR-fold with index for variation.
        let bytes = event.id.uuid
        let b: [UInt8] = [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
        ]
        // Pick two bytes based on index, XOR with index
        let i1 = index % 16
        let i2 = (index + 7) % 16
        var v = UInt32(b[i1]) ^ UInt32(b[i2]) ^ UInt32(truncatingIfNeeded: index &* 2654435761)
        // xorshift32
        v ^= v << 13
        v ^= v >> 17
        v ^= v << 5
        return Double(v) / Double(UInt32.max)
    }

    private func buildGenes(size: CGSize) -> Genes {
        let w = size.width
        let h = size.height

        // Palette derived from event type + UUID
        let paletteIndex = Int(dna(0) * 4)
        let palettes: [[Color]] = [
            [AppTheme.gold, .orange, .yellow],
            [.cyan, .blue, .teal],
            [.purple, .pink, .indigo],
            [.green, .mint, .teal],
        ]
        let palette = palettes[paletteIndex]

        let bgBrightness = dna(1) * 0.15 + 0.05
        let bgColor = Color(hue: dna(2), saturation: 0.4, brightness: bgBrightness)

        // Generate 3–5 rings
        let ringCount = 3 + Int(dna(3) * 3)
        var rings: [Ring] = []
        for i in 0..<ringCount {
            let cx = w * CGFloat(dna(10 + i * 4) * 0.8 + 0.1)
            let cy = h * CGFloat(dna(11 + i * 4) * 0.8 + 0.1)
            let radius = CGFloat(dna(12 + i * 4)) * min(w, h) * 0.4 + 4
            let colorIdx = Int(dna(13 + i * 4) * Double(palette.count))
            rings.append(Ring(
                center: CGPoint(x: cx, y: cy),
                radius: radius,
                color: palette[min(colorIdx, palette.count - 1)],
                opacity: dna(14 + i * 4) * 0.5 + 0.3,
                lineWidth: CGFloat(dna(15 + i * 4)) * 2 + 0.5
            ))
        }

        // Generate 6–12 dots
        let dotCount = 6 + Int(dna(4) * 7)
        var dots: [Dot] = []
        for i in 0..<dotCount {
            let colorIdx = Int(dna(50 + i * 4) * Double(palette.count))
            dots.append(Dot(
                x: w * CGFloat(dna(51 + i * 4)),
                y: h * CGFloat(dna(52 + i * 4)),
                r: CGFloat(dna(53 + i * 4)) * 5 + 1,
                color: palette[min(colorIdx, palette.count - 1)],
                opacity: dna(54 + i * 4) * 0.6 + 0.2
            ))
        }

        return Genes(bgColor: bgColor, rings: rings, dots: dots)
    }
}

#Preview {
    HStack(spacing: 12) {
        EventDNAView(event: Event(
            title: "Soccer", type: .sports, location: "Park",
            date: Date().addingTimeInterval(3600), description: "A fun game",
            userId: "a@b.com"
        ))
        .frame(width: 80, height: 80)
        .cornerRadius(12)

        EventDNAView(event: Event(
            title: "Party", type: .party, location: "Downtown",
            date: Date().addingTimeInterval(7200), description: "Great party",
            userId: "c@d.com"
        ))
        .frame(width: 80, height: 80)
        .cornerRadius(12)
    }
    .padding()
    .background(Color.black)
}
