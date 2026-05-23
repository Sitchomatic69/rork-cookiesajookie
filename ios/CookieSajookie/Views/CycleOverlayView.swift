import SwiftUI

/// Full-screen overlay shown during the cycle reset. Displays the step
/// checklist and a pulsing identity glyph until the cold-start fires.
struct CycleOverlayView: View {
    @Bindable var viewModel: CycleProfileViewModel
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0B0B10"),
                    Color(hex: "#11131A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                glyph
                title
                stepList
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
        }
        .onAppear { pulse = true }
        .preferredColorScheme(.dark)
    }

    private var glyph: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#14B8A6").opacity(0.18), lineWidth: 1)
                .frame(width: 180, height: 180)
                .scaleEffect(pulse ? 1.08 : 0.95)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#14B8A6").opacity(0.35), .clear],
                        center: .center, startRadius: 4, endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color(hex: "#14B8A6"))
                .symbolEffect(.pulse, options: .repeating)
        }
    }

    private var title: some View {
        VStack(spacing: 8) {
            Text("Cycling identity")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Sealing a new device persona and wiping every trace of the previous one.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.allSteps, id: \.self) { step in
                stepRow(step)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func stepRow(_ step: CycleCoordinator.Step) -> some View {
        HStack(spacing: 14) {
            stepIcon(step)
            Text(step.rawValue)
                .font(.callout.weight(.medium))
                .foregroundStyle(stepColor(step))
            Spacer()
        }
    }

    private func stepIcon(_ step: CycleCoordinator.Step) -> some View {
        Group {
            if viewModel.completedSteps.contains(step) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#22C55E"))
            } else if viewModel.currentStep == step {
                ProgressView().tint(Color(hex: "#14B8A6"))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .frame(width: 22, height: 22)
    }

    private func stepColor(_ step: CycleCoordinator.Step) -> Color {
        if viewModel.completedSteps.contains(step) { return .white }
        if viewModel.currentStep == step { return .white }
        return .white.opacity(0.45)
    }

    private var footer: some View {
        Text("The app will cold-start when the new identity is sealed.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.35))
            .multilineTextAlignment(.center)
    }
}
