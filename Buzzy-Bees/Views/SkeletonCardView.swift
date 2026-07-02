//
//  SkeletonCardView.swift
//  Buzzy-Bees
//

import SwiftUI

struct SkeletonCardView: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.darkGray)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(AppTheme.darkGray).frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(AppTheme.darkGray).frame(width: 100, height: 11)
                RoundedRectangle(cornerRadius: 4).fill(AppTheme.darkGray).frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppTheme.mediumGray.opacity(0.3)))
        .overlay(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.07), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            shimmerOffset = geo.size.width + 200
                        }
                    }
            }
            .clipped()
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCardView()
            }
        }
    }
}
