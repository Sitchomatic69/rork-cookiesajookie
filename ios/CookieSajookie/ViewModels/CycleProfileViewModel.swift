import Foundation
import Observation

/// Drives the cycle overlay UI: tracks current step and runs the coordinator.
@MainActor
@Observable
final class CycleProfileViewModel {
    var isCycling: Bool = false
    var currentStep: CycleCoordinator.Step?
    var completedSteps: Set<CycleCoordinator.Step> = []

    private let coordinator = CycleCoordinator()

    var allSteps: [CycleCoordinator.Step] { CycleCoordinator.Step.allCases }

    func startCycle() async {
        guard !isCycling else { return }
        isCycling = true
        completedSteps = []
        coordinator.onStep = { [weak self] step in
            guard let self else { return }
            if let prev = self.currentStep {
                self.completedSteps.insert(prev)
            }
            self.currentStep = step
        }
        await coordinator.cycle()
        // If we get here (soft-restart build), mark final step done.
        if let last = currentStep { completedSteps.insert(last) }
        isCycling = false
    }
}
