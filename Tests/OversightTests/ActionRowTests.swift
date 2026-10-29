import Foundation
@testable import Oversight
import Testing

@Suite("Action rows")
struct ActionRowTests {
    private func runs() throws -> [WorkflowRun] {
        try Fixtures.decode(WorkflowRunsResponse.self, "deploy_runs").workflowRuns
    }

    private func row(_ id: Int64) throws -> ActionRow {
        let runs = try runs()
        let run = try #require(runs.first { $0.id == id })
        return ActionRow(run: run, repo: Sample.atlas.id)
    }

    @Test("An action row uses the first line of the commit message and a short SHA")
    func parsesMessageAndSHA() throws {
        let row = try row(501)
        #expect(row.workflowName == "Deploy")
        #expect(row.message == "Ship the cross-repo view")
        #expect(row.shortSHA == "aaaaaaa")
        #expect(row.ref == "main")
        #expect(row.isProductionRelease == false)
    }

    @Test("A v-prefixed tag is a production release")
    func detectsProductionRelease() throws {
        #expect(try row(503).isProductionRelease == true)
        #expect(try row(503).ref == "v1.4.0")

        let notATag = ActionRow(run: Sample.run(id: 9, branch: "version-2"), repo: Sample.atlas.id)
        #expect(notATag.isProductionRelease == false)
    }

    @Test("Run states map to row states")
    func mapsStates() throws {
        #expect(try row(501).state == .inProgress)
        #expect(try row(502).state == .success)
        #expect(try row(504).state == .failure)
        #expect(try row(505).state == .neutral)
        #expect(try row(506).state == .neutral)

        let queued = ActionRow(
            run: Sample.run(id: 10, status: "queued", conclusion: nil),
            repo: Sample.atlas.id
        )
        #expect(queued.state == .inProgress)
        #expect(queued.isQueued)
        #expect(queued.isRunning)

        let timedOut = ActionRow(
            run: Sample.run(id: 11, conclusion: "timed_out"),
            repo: Sample.atlas.id
        )
        #expect(timedOut.state == .failure)
    }

    @Test("A finished run has a fixed duration, a running one grows with the clock")
    func computesDurations() throws {
        let finished = try row(502)
        #expect(finished.isRunning == false)
        #expect(finished.duration(now: Sample.date("2026-10-30T12:00:00Z")) == 120)

        let running = try row(501)
        #expect(running.isRunning == true)
        #expect(running.duration(now: Sample.date("2026-10-29T10:05:06Z")) == 300)
        #expect(running.duration(now: Sample.date("2026-10-29T10:10:06Z")) == 600)
    }

    @Test("A run with no commit message falls back to the display title")
    func fallsBackToDisplayTitle() throws {
        let run = try WorkflowRun(
            id: 12,
            name: "CI",
            displayTitle: "Display title fallback",
            headBranch: "main",
            headSHA: "1234567890",
            status: "completed",
            conclusion: "success",
            createdAt: Sample.date("2026-10-29T09:00:00Z"),
            runStartedAt: Sample.date("2026-10-29T09:00:00Z"),
            updatedAt: Sample.date("2026-10-29T09:01:00Z"),
            event: "push",
            htmlURL: #require(URL(string: "https://github.com/alexpricedev/atlas/actions/runs/12")),
            headCommit: nil
        )
        #expect(ActionRow(run: run, repo: Sample.atlas.id).message == "Display title fallback")
    }
}
