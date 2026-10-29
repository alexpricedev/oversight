import Foundation
@testable import Oversight
import Testing

@Suite("PR CI rollup")
struct CIRollupTests {
    @Test("No runs means there is nothing to report")
    func emptyIsNone() {
        #expect(CIRollup.from([]) == .none)
    }

    @Test("Any failure wins, even while another run is still going")
    func failureWinsOverPending() throws {
        let response = try Fixtures.decode(WorkflowRunsResponse.self, "ci_runs_failure")
        #expect(CIRollup.from(response.workflowRuns) == .failure)
    }

    @Test("An unfinished run means pending")
    func pendingWhenAnyRunIsUnfinished() throws {
        let response = try Fixtures.decode(WorkflowRunsResponse.self, "ci_runs_pending")
        #expect(CIRollup.from(response.workflowRuns) == .pending)
    }

    @Test("All successful runs mean success")
    func allSuccess() {
        let runs = [
            Sample.run(id: 1, conclusion: "success"),
            Sample.run(id: 2, conclusion: "success"),
        ]
        #expect(CIRollup.from(runs) == .success)
    }

    @Test("Skipped and cancelled runs are ignored when something succeeded")
    func neutralRunsDoNotBlockSuccess() {
        let runs = [
            Sample.run(id: 1, conclusion: "success"),
            Sample.run(id: 2, conclusion: "skipped"),
            Sample.run(id: 3, conclusion: "cancelled"),
        ]
        #expect(CIRollup.from(runs) == .success)
    }

    @Test("Only cancelled or skipped runs is neutral")
    func onlyNeutralRuns() {
        let runs = [
            Sample.run(id: 1, conclusion: "cancelled"),
            Sample.run(id: 2, conclusion: "skipped"),
        ]
        #expect(CIRollup.from(runs) == .neutral)
    }

    @Test("A timed out run counts as a failure")
    func timedOutIsFailure() {
        #expect(CIRollup.from([Sample.run(id: 1, conclusion: "timed_out")]) == .failure)
    }
}
