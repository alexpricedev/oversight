import SwiftUI

/// A tappable dashboard row. Every row opens its subject on github.com.
struct DashboardRow<Content: View, Trailing: View>: View {
    let url: URL?
    let warning: String?
    private let content: Content
    private let trailing: Trailing

    @State private var isHovering = false
    @Environment(\.openURL) private var openURL

    init(
        url: URL?,
        warning: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.url = url
        self.warning = warning
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        Button {
            if let url {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                content
                Spacer(minLength: 6)
                trailing
                if let warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .help(warning)
                        .accessibilityLabel("Problem loading this repository: \(warning)")
                }
                if url != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.08) : Color.clear)
        .onHover { isHovering = $0 }
        .help(url?.absoluteString ?? "")
    }
}

extension DashboardRow where Trailing == EmptyView {
    init(url: URL?, warning: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(url: url, warning: warning, trailing: { EmptyView() }, content: content)
    }
}

struct ActionRowView: View {
    let row: ActionRow
    let now: Date
    let warning: String?

    var body: some View {
        DashboardRow(
            url: row.url,
            warning: warning,
            trailing: { duration },
            content: {
                Image(systemName: row.state.symbolName)
                    .foregroundStyle(row.state.tint)
                    .font(.callout)
                    .help(row.state.label)
                    .accessibilityLabel(row.state.label)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(row.message)
                            .lineLimit(1)
                        if row.isProductionRelease {
                            Badge(text: "PROD", tint: .green)
                                .help("A v* tag: production release")
                        }
                    }
                    HStack(spacing: 5) {
                        Text(row.workflowName)
                            .fontWeight(.medium)
                        Text("·")
                        RepoBadge(repo: row.repo)
                        Text("·")
                        Text(row.ref)
                        Text("·")
                        Text(RelativeTime.ago(row.startedAt, now: now))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.workflowName) \(row.state.label) on \(row.repo.name), \(row.ref), commit \(row.shortSHA)."
        )
    }

    @ViewBuilder
    private var duration: some View {
        if row.isQueued {
            Text("queued")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if row.isRunning {
            Text(Elapsed.clock(row.duration(now: now)))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.blue)
                .monospacedDigit()
        } else {
            Text(Elapsed.short(row.duration(now: now)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct PullRequestRowView: View {
    let row: PullRequestRow
    let ci: CIRollup
    let now: Date

    var body: some View {
        DashboardRow(
            url: row.url,
            trailing: {
                Text(ci.label)
                    .font(.caption)
                    .foregroundStyle(ci.tint)
                    .fixedSize()
            },
            content: {
                CIStatusIcon(rollup: ci)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(row.title)
                            .lineLimit(1)
                        if row.isDraft {
                            Badge(text: "Draft")
                        }
                    }
                    HStack(spacing: 5) {
                        RepoBadge(repo: row.repo)
                        Text("#\(row.number)")
                        Text("·")
                        Text("@\(row.author)")
                        Text("·")
                        Text(RelativeTime.ago(row.createdAt, now: now))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pull request \(row.title) in \(row.repo.name), by \(row.author), CI \(ci.label)."
        )
    }
}

struct IssueRowView: View {
    let row: IssueRow
    let now: Date

    var body: some View {
        DashboardRow(url: row.url) {
            Image(systemName: "smallcircle.filled.circle")
                .foregroundStyle(.green)
                .font(.callout)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    RepoBadge(repo: row.repo)
                    Text("#\(row.number)")
                    Text("·")
                    Text(RelativeTime.ago(row.createdAt, now: now))
                    ForEach(Array(row.labels.prefix(2)), id: \.self) { label in
                        Badge(text: label, tint: .accentColor)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(row.title) in \(row.repo.name).")
    }
}
