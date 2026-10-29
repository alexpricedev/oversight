import Foundation

/// Entirely fictional data for screenshots and for trying the layout without a
/// token: a Belt shipyard, an MCRN flagship and a gate authority, all staffed by
/// names from the Expanse. Times are relative to launch, so ages and running
/// clocks look live.
struct DemoData {
    static let owner = Owner(login: "tycho-station", kind: .organization)

    let repos: [Repo]
    let runs: [RepoID: [WorkflowRun]]
    let pullRequests: [String: [PullRequestRow]]
    let issues: [String: [IssueRow]]
    let ci: [String: CIRollup]
    let rateLimit: RateLimitInfo

    init(now: Date = Date()) {
        let owner = DemoData.owner

        let rocinante = RepoID(owner: owner.login, name: "rocinante")
        let medina = RepoID(owner: owner.login, name: "medina-station")
        let donnager = RepoID(owner: owner.login, name: "donnager")
        let nauvoo = RepoID(owner: owner.login, name: "nauvoo")
        let gate = RepoID(owner: owner.login, name: "ring-gate")
        let tycho = RepoID(owner: owner.login, name: "tycho-ops")

        repos = [
            Repo(id: rocinante, isPrivate: true, pushedAt: now.addingTimeInterval(-600)),
            Repo(id: medina, isPrivate: true, pushedAt: now.addingTimeInterval(-1800)),
            Repo(id: donnager, isPrivate: true, pushedAt: now.addingTimeInterval(-7200)),
            Repo(id: nauvoo, isPrivate: true, pushedAt: now.addingTimeInterval(-86400)),
            Repo(id: gate, isPrivate: true, pushedAt: now.addingTimeInterval(-3 * 86400)),
            Repo(id: tycho, isPrivate: true, pushedAt: now.addingTimeInterval(-9 * 86400)),
        ]

        struct RunSpec {
            let repo: RepoID
            let workflow: String
            let branch: String
            let status: String
            let conclusion: String?
            let minutesAgo: Double
            let duration: TimeInterval
            let message: String
        }

        let specs: [RunSpec] = [
            RunSpec(repo: medina, workflow: "Deploy", branch: "main", status: "in_progress", conclusion: nil, minutesAgo: 2.5, duration: 0, message: "Merge pull request #142 from tycho-station/freight-manifest-audit"),
            RunSpec(repo: rocinante, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 9, duration: 68, message: "Merge pull request #12 from tycho-station/epstein-burn-profile"),
            RunSpec(repo: rocinante, workflow: "CI", branch: "feature/docking-clamp", status: "completed", conclusion: "success", minutesAgo: 14, duration: 132, message: "Recalibrate docking clamp telemetry"),
            RunSpec(repo: donnager, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 22, duration: 96, message: "Bump the protomolecule bindings group with 5 updates"),
            RunSpec(repo: gate, workflow: "Deploy", branch: "v1.4.0", status: "completed", conclusion: "success", minutesAgo: 38, duration: 210, message: "Release 1.4.0"),
            RunSpec(repo: medina, workflow: "Deploy", branch: "main", status: "completed", conclusion: "failure", minutesAgo: 52, duration: 41, message: "Fix slow-zone handshake timeout"),
            RunSpec(repo: nauvoo, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 64, duration: 145, message: "Add freight manifest validation"),
            RunSpec(repo: tycho, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 80, duration: 88, message: "Audit relay links after the migration"),
            RunSpec(repo: rocinante, workflow: "CI", branch: "feature/docking-clamp", status: "completed", conclusion: "failure", minutesAgo: 96, duration: 57, message: "Try the new reactor image"),
            RunSpec(repo: donnager, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 120, duration: 73, message: "Merge pull request #91 from tycho-station/medina-freight-queue"),
            RunSpec(repo: medina, workflow: "Deploy", branch: "main", status: "completed", conclusion: "cancelled", minutesAgo: 150, duration: 12, message: "Cancel the stale preview burn"),
            RunSpec(repo: gate, workflow: "CI", branch: "main", status: "queued", conclusion: nil, minutesAgo: 160, duration: 0, message: "Check the transit window queue"),
            RunSpec(repo: nauvoo, workflow: "CI", branch: "release/2.1", status: "completed", conclusion: "success", minutesAgo: 190, duration: 202, message: "Release 2.1"),
            RunSpec(repo: rocinante, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 230, duration: 64, message: "Point the demo beacons at Tycho"),
            RunSpec(repo: donnager, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 280, duration: 109, message: "Add incident labels to the relay log"),
            RunSpec(repo: tycho, workflow: "CI", branch: "main", status: "completed", conclusion: "failure", minutesAgo: 320, duration: 35, message: "Broken asset path in the docking UI"),
            RunSpec(repo: medina, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 400, duration: 71, message: "Swap the Rocinante hero illustration"),
            RunSpec(repo: gate, workflow: "Deploy", branch: "v1.3.2", status: "completed", conclusion: "success", minutesAgo: 500, duration: 195, message: "Release 1.3.2"),
            RunSpec(repo: nauvoo, workflow: "CI", branch: "main", status: "completed", conclusion: "skipped", minutesAgo: 620, duration: 3, message: "Skip CI on manifest-only changes"),
            RunSpec(repo: rocinante, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 780, duration: 118, message: "Cache ETags between gate polls"),
            RunSpec(repo: donnager, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 900, duration: 101, message: "Tighten the freight export"),
            RunSpec(repo: medina, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 1100, duration: 66, message: "Copy pass on the recruitment page"),
            RunSpec(repo: tycho, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 1400, duration: 92, message: "Update the drive review diagrams"),
            RunSpec(repo: gate, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 1700, duration: 143, message: "Add the incident template"),
            RunSpec(repo: nauvoo, workflow: "Deploy", branch: "main", status: "completed", conclusion: "failure", minutesAgo: 2100, duration: 48, message: "Try the new reactor migration"),
            RunSpec(repo: rocinante, workflow: "Deploy", branch: "main", status: "completed", conclusion: "success", minutesAgo: 2600, duration: 70, message: "Ship the rate-limit footer"),
            RunSpec(repo: donnager, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 3200, duration: 97, message: "Normalise the docking label casing"),
            RunSpec(repo: medina, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 3900, duration: 84, message: "Fix the narrow-viewport nav overlap"),
            RunSpec(repo: tycho, workflow: "CI", branch: "main", status: "completed", conclusion: "success", minutesAgo: 4600, duration: 91, message: "Drop the unused drive fonts"),
            RunSpec(repo: gate, workflow: "Deploy", branch: "v1.3.1", status: "completed", conclusion: "success", minutesAgo: 5400, duration: 188, message: "Release 1.3.1"),
        ]

        var runsByRepo: [RepoID: [WorkflowRun]] = [:]
        for (index, spec) in specs.enumerated() {
            let started = now.addingTimeInterval(-spec.minutesAgo * 60)
            let sha = String(format: "%040x", 0xC0FFEE + index)
            let run = WorkflowRun(
                id: Int64(10000 + index),
                name: spec.workflow,
                displayTitle: spec.message,
                headBranch: spec.branch,
                headSHA: sha,
                status: spec.status,
                conclusion: spec.conclusion,
                createdAt: started.addingTimeInterval(-4),
                runStartedAt: spec.status == "queued" ? nil : started,
                updatedAt: spec.status == "in_progress" || spec.status == "queued"
                    ? started
                    : started.addingTimeInterval(spec.duration),
                event: "push",
                htmlURL: URL(string: "https://github.com/\(spec.repo.slug)/actions/runs/\(10000 + index)")!,
                headCommit: WorkflowRun.HeadCommit(id: sha, message: spec.message)
            )
            runsByRepo[spec.repo, default: []].append(run)
        }
        runs = runsByRepo

        struct PullSpec {
            let repo: RepoID
            let number: Int
            let title: String
            let author: String
            let minutesAgo: Double
            let draft: Bool
            let labels: [String]
            let ci: CIRollup
        }

        let pullSpecs: [PullSpec] = [
            PullSpec(repo: medina, number: 91, title: "Redesign the docking clamp: one group, type switch, hover text", author: "tycho-bot[bot]", minutesAgo: 9, draft: false, labels: ["fettle", "docking"], ci: .success),
            PullSpec(repo: rocinante, number: 12, title: "Add the gate transit overview", author: "holden", minutesAgo: 21, draft: false, labels: ["gate"], ci: .success),
            PullSpec(repo: medina, number: 142, title: "Freight manifest audit for the Ring run", author: "naomi", minutesAgo: 34, draft: true, labels: ["freight", "audit"], ci: .pending),
            PullSpec(repo: donnager, number: 73, title: "Bump the protomolecule bindings group with 3 updates", author: "mcrn-bot[bot]", minutesAgo: 55, draft: false, labels: [], ci: .success),
            PullSpec(repo: rocinante, number: 11, title: "Keep polling paused while the station is dark", author: "amos", minutesAgo: 88, draft: false, labels: ["ops"], ci: .pending),
            PullSpec(repo: tycho, number: 48, title: "Fix the footer overlap on short viewports", author: "drummer", minutesAgo: 120, draft: false, labels: ["bug", "design"], ci: .failure),
            PullSpec(repo: nauvoo, number: 26, title: "Validate freight manifests before departure", author: "prax", minutesAgo: 150, draft: false, labels: [], ci: .success),
            PullSpec(repo: gate, number: 9, title: "Show incident history on the Medina status page", author: "elvi", minutesAgo: 210, draft: false, labels: [], ci: .none),
            PullSpec(repo: medina, number: 140, title: "Add the recruitment landing page", author: "fred-j", minutesAgo: 260, draft: false, labels: [], ci: .success),
            PullSpec(repo: rocinante, number: 10, title: "Cache station lists for ten minutes", author: "naomi", minutesAgo: 340, draft: false, labels: [], ci: .success),
            PullSpec(repo: donnager, number: 70, title: "Media, export and handoff polish", author: "bobbie", minutesAgo: 420, draft: false, labels: [], ci: .success),
            PullSpec(repo: tycho, number: 47, title: "Refresh the drive review diagrams", author: "ashford", minutesAgo: 500, draft: false, labels: [], ci: .success),
            PullSpec(repo: nauvoo, number: 24, title: "Bump reactor-core from 2.17 to 2.18", author: "mcrn-bot[bot]", minutesAgo: 610, draft: false, labels: [], ci: .success),
            PullSpec(repo: gate, number: 8, title: "Tighten the probe intervals", author: "holden", minutesAgo: 730, draft: false, labels: [], ci: .success),
            PullSpec(repo: medina, number: 138, title: "Copy pass: what the Belt builds and why", author: "avasarala", minutesAgo: 850, draft: false, labels: [], ci: .success),
            PullSpec(repo: rocinante, number: 9, title: "Add a rate-limit footer to the ops console", author: "alex-k", minutesAgo: 980, draft: false, labels: [], ci: .success),
            PullSpec(repo: donnager, number: 66, title: "Split the editor toolbar out of the footer", author: "bobbie", minutesAgo: 1200, draft: false, labels: [], ci: .failure),
            PullSpec(repo: tycho, number: 45, title: "Move the migration notes into the handbook", author: "drummer", minutesAgo: 1500, draft: false, labels: [], ci: .success),
            PullSpec(repo: nauvoo, number: 21, title: "Expose the Ganymede warehouse views to the dashboard", author: "prax", minutesAgo: 1800, draft: true, labels: [], ci: .none),
            PullSpec(repo: gate, number: 7, title: "Add the maintenance window banner", author: "elvi", minutesAgo: 2200, draft: false, labels: [], ci: .success),
            PullSpec(repo: medina, number: 131, title: "Use the new Tycho brand font everywhere", author: "fred-j", minutesAgo: 2700, draft: false, labels: [], ci: .success),
            PullSpec(repo: rocinante, number: 8, title: "Show burn status from the head commit", author: "holden", minutesAgo: 3100, draft: false, labels: [], ci: .success),
            PullSpec(repo: donnager, number: 61, title: "Bump the docking dependencies group across 2 directories", author: "mcrn-bot[bot]", minutesAgo: 3600, draft: false, labels: [], ci: .success),
            PullSpec(repo: tycho, number: 41, title: "Drop the unused drive fonts", author: "amos", minutesAgo: 4100, draft: false, labels: [], ci: .success),
            PullSpec(repo: nauvoo, number: 18, title: "Add the quote builder handoff", author: "naomi", minutesAgo: 4800, draft: false, labels: [], ci: .success),
            PullSpec(repo: gate, number: 6, title: "Trim the status page payload", author: "elvi", minutesAgo: 5500, draft: false, labels: [], ci: .success),
            PullSpec(repo: rocinante, number: 7, title: "Prefetch the next page of transit windows", author: "alex-k", minutesAgo: 6300, draft: false, labels: [], ci: .success),
        ]

        var pullRequestsByOwner: [String: [PullRequestRow]] = [:]
        var ciByKey: [String: CIRollup] = [:]
        for (index, spec) in pullSpecs.enumerated() {
            let sha = String(format: "%040x", 0xBEEF00 + index)
            let row = PullRequestRow(
                repo: spec.repo,
                number: spec.number,
                title: spec.title,
                author: spec.author,
                createdAt: now.addingTimeInterval(-spec.minutesAgo * 60),
                isDraft: spec.draft,
                labels: spec.labels,
                headSHA: sha,
                url: URL(string: "https://github.com/\(spec.repo.slug)/pull/\(spec.number)")!
            )
            pullRequestsByOwner[owner.login, default: []].append(row)
            ciByKey["\(spec.repo.slug)@\(sha)"] = spec.ci
        }
        pullRequests = pullRequestsByOwner
        ci = ciByKey

        struct IssueSpec {
            let repo: RepoID
            let number: Int
            let title: String
            let labels: [String]
            let minutesAgo: Double
        }

        let issueSpecs: [IssueSpec] = [
            IssueSpec(repo: medina, number: 90, title: "Docking clamp telemetry flips at high burn", labels: ["telemetry", "docking"], minutesAgo: 60),
            IssueSpec(repo: medina, number: 88, title: "Gate transit queue shows stale windows", labels: ["gate", "bug"], minutesAgo: 240),
            IssueSpec(repo: rocinante, number: 33, title: "Burn report duplicates the last row", labels: ["bug", "telemetry"], minutesAgo: 360),
            IssueSpec(repo: nauvoo, number: 137, title: "Freight manifest loses the last line item", labels: ["bug", "freight"], minutesAgo: 480),
            IssueSpec(repo: rocinante, number: 31, title: "Document the fine-grained token setup", labels: ["docs"], minutesAgo: 600),
            IssueSpec(repo: tycho, number: 44, title: "Review diagrams drift from the component tree", labels: ["docs"], minutesAgo: 720),
            IssueSpec(repo: nauvoo, number: 22, title: "Ganymede warehouse views need a nightly refresh", labels: ["ops"], minutesAgo: 900),
            IssueSpec(repo: gate, number: 5, title: "Status page timestamps drift", labels: ["gate", "bug"], minutesAgo: 1100),
            IssueSpec(repo: medina, number: 85, title: "Purge idle staging berths when RAM is tight", labels: ["ops"], minutesAgo: 1300),
            IssueSpec(repo: rocinante, number: 29, title: "Burn status is unknown until the second poll", labels: ["telemetry"], minutesAgo: 1500),
            IssueSpec(repo: medina, number: 134, title: "Copy reads twice on the recruitment page", labels: ["copy"], minutesAgo: 1700),
            IssueSpec(repo: tycho, number: 40, title: "Audit relay links after the domain migration", labels: ["docs"], minutesAgo: 1900),
            IssueSpec(repo: nauvoo, number: 19, title: "Quote builder handoff loses the selected options", labels: ["bug", "freight"], minutesAgo: 2100),
            IssueSpec(repo: gate, number: 4, title: "Add a maintenance window banner", labels: ["gate"], minutesAgo: 2300),
            IssueSpec(repo: donnager, number: 80, title: "Dark mode for the drive console", labels: ["design"], minutesAgo: 2500),
            IssueSpec(repo: rocinante, number: 27, title: "Archived berths still show issues", labels: ["bug"], minutesAgo: 2800),
            IssueSpec(repo: medina, number: 128, title: "Swap the hero illustration for the new one", labels: ["design"], minutesAgo: 3100),
            IssueSpec(repo: tycho, number: 38, title: "Drop the unused drive fonts", labels: ["cleanup"], minutesAgo: 3400),
            IssueSpec(repo: nauvoo, number: 16, title: "Manifest validation should fail the build", labels: ["ci"], minutesAgo: 3700),
            IssueSpec(repo: gate, number: 3, title: "Transit history isn't linked from the footer", labels: ["gate"], minutesAgo: 4000),
            IssueSpec(repo: medina, number: 77, title: "Freight export drops the last line item", labels: ["bug", "freight"], minutesAgo: 4300),
            IssueSpec(repo: rocinante, number: 24, title: "Filter by station should survive a refresh", labels: ["feature"], minutesAgo: 4600),
            IssueSpec(repo: donnager, number: 121, title: "Docking table breaks between 700 and 760 px", labels: ["bug", "design"], minutesAgo: 4900),
            IssueSpec(repo: tycho, number: 34, title: "Move the migration notes into the handbook", labels: ["docs"], minutesAgo: 5200),
            IssueSpec(repo: nauvoo, number: 13, title: "Quote builder: add a currency switch", labels: ["feature"], minutesAgo: 5500),
            IssueSpec(repo: gate, number: 2, title: "Probe intervals are too aggressive at night", labels: ["ops"], minutesAgo: 5800),
            IssueSpec(repo: donnager, number: 74, title: "Label casing is inconsistent in the picker", labels: ["cleanup"], minutesAgo: 6100),
            IssueSpec(repo: medina, number: 71, title: "Relay log: incident history isn't linked", labels: ["gate"], minutesAgo: 6400),
        ]

        var issuesByOwner: [String: [IssueRow]] = [:]
        for spec in issueSpecs {
            let row = IssueRow(
                repo: spec.repo,
                number: spec.number,
                title: spec.title,
                labels: spec.labels,
                createdAt: now.addingTimeInterval(-spec.minutesAgo * 60),
                url: URL(string: "https://github.com/\(spec.repo.slug)/issues/\(spec.number)")!
            )
            issuesByOwner[owner.login, default: []].append(row)
        }
        issues = issuesByOwner

        rateLimit = RateLimitInfo(
            limit: 5000,
            remaining: 4812,
            reset: now.addingTimeInterval(38 * 60),
            observedAt: now
        )
    }
}
