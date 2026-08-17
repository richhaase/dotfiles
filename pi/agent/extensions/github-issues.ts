/**
 * GitHub Issues Extension
 *
 * Provides a tool for the LLM to look up GitHub issues, and a /issues command
 * for interactive browsing. Uses the `gh` CLI under the hood.
 *
 * Features:
 * - `github_issues` tool: LLM can search/list/view issues
 * - `/issues` command: Interactive issue browser
 *
 * Requirements: `gh` CLI installed and authenticated
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	truncateHead,
	formatSize,
} from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";

interface Issue {
	number: number;
	title: string;
	state: string;
	author: { login: string };
	labels: { name: string }[];
	assignees: { login: string }[];
	milestone?: { title: string } | null;
	createdAt: string;
	updatedAt: string;
	closedAt?: string | null;
	body: string;
	comments: IssueComment[];
	url: string;
}

interface IssueComment {
	author: { login: string };
	createdAt: string;
	body: string;
}

interface IssueWithComments extends Issue {
	commentsList: IssueComment[];
}

interface IssueDetails {
	action: string;
	repo?: string;
	issueCount?: number;
	issueNumber?: number;
	truncated?: boolean;
}

function formatDate(iso: string): string {
	const d = new Date(iso);
	return d.toLocaleDateString("en-US", {
		year: "numeric",
		month: "short",
		day: "numeric",
	});
}

function formatRelative(iso: string): string {
	const now = Date.now();
	const then = new Date(iso).getTime();
	const diff = now - then;
	const mins = Math.floor(diff / 60000);
	if (mins < 60) return `${mins}m ago`;
	const hours = Math.floor(mins / 60);
	if (hours < 24) return `${hours}h ago`;
	const days = Math.floor(hours / 24);
	if (days < 30) return `${days}d ago`;
	const months = Math.floor(days / 30);
	if (months < 12) return `${months}mo ago`;
	return `${Math.floor(months / 12)}y ago`;
}

function stateIcon(state: string): string {
	return state === "OPEN" ? "🟢" : "🟣";
}

function formatIssueList(issues: Issue[]): string {
	if (issues.length === 0) return "No issues found.";

	const lines: string[] = [];
	lines.push(`Found ${issues.length} issue(s):\n`);

	for (const issue of issues) {
		const labels = issue.labels.map((l) => l.name).join(", ");
		const assignees = issue.assignees.map((a) => a.login).join(", ");

		lines.push(`${stateIcon(issue.state)} #${issue.number}: ${issue.title}`);
		lines.push(`   State: ${issue.state}  |  Author: @${issue.author.login}  |  Updated: ${formatRelative(issue.updatedAt)}  |  Comments: ${issue.comments.length}`);
		if (labels) lines.push(`   Labels: ${labels}`);
		if (assignees) lines.push(`   Assignees: ${assignees}`);
		if (issue.milestone) lines.push(`   Milestone: ${issue.milestone.title}`);
		lines.push("");
	}

	return lines.join("\n");
}

function formatIssueDetail(issue: IssueWithComments): string {
	const lines: string[] = [];
	const labels = issue.labels.map((l) => l.name).join(", ");
	const assignees = issue.assignees.map((a) => a.login).join(", ");

	lines.push(`${"═".repeat(60)}`);
	lines.push(`${stateIcon(issue.state)} Issue #${issue.number}: ${issue.title}`);
	lines.push(`${"═".repeat(60)}`);
	lines.push("");
	lines.push(`State:      ${issue.state}`);
	lines.push(`Author:     @${issue.author.login}`);
	lines.push(`Created:    ${formatDate(issue.createdAt)}`);
	lines.push(`Updated:    ${formatDate(issue.updatedAt)}`);
	if (issue.closedAt) lines.push(`Closed:     ${formatDate(issue.closedAt)}`);
	if (labels) lines.push(`Labels:     ${labels}`);
	if (assignees) lines.push(`Assignees:  ${assignees}`);
	if (issue.milestone) lines.push(`Milestone:  ${issue.milestone.title}`);
	lines.push(`URL:        ${issue.url}`);
	lines.push("");

	lines.push(`${"─".repeat(60)}`);
	lines.push("Description:");
	lines.push(`${"─".repeat(60)}`);
	lines.push(issue.body || "(no description)");
	lines.push("");

	if (issue.commentsList.length > 0) {
		lines.push(`${"─".repeat(60)}`);
		lines.push(`Comments (${issue.commentsList.length}):`);
		lines.push(`${"─".repeat(60)}`);
		lines.push("");

		for (const comment of issue.commentsList) {
			lines.push(`  💬 @${comment.author.login} — ${formatDate(comment.createdAt)}`);
			// Indent the comment body
			const bodyLines = (comment.body || "").split("\n");
			for (const bl of bodyLines) {
				lines.push(`     ${bl}`);
			}
			lines.push("");
		}
	}

	return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
	// Helper to run gh CLI
	async function gh(args: string[], signal?: AbortSignal): Promise<string> {
		const result = await pi.exec("gh", args, { signal, timeout: 30000 });
		if (result.code !== 0) {
			throw new Error(`gh ${args.join(" ")} failed (exit ${result.code}): ${result.stderr}`);
		}
		return result.stdout;
	}

	async function listIssues(
		opts: { repo?: string; state?: string; labels?: string; assignee?: string; author?: string; search?: string; limit?: number },
		signal?: AbortSignal,
	): Promise<Issue[]> {
		const args = ["issue", "list", "--json", "number,title,state,author,labels,assignees,milestone,createdAt,updatedAt,closedAt,body,comments,url"];

		if (opts.repo) args.push("--repo", opts.repo);
		if (opts.state) args.push("--state", opts.state);
		if (opts.labels) args.push("--label", opts.labels);
		if (opts.assignee) args.push("--assignee", opts.assignee);
		if (opts.author) args.push("--author", opts.author);
		if (opts.search) args.push("--search", opts.search);
		args.push("--limit", String(opts.limit || 30));

		const output = await gh(args, signal);
		return JSON.parse(output) as Issue[];
	}

	async function viewIssue(
		issueNumber: number,
		opts: { repo?: string },
		signal?: AbortSignal,
	): Promise<IssueWithComments> {
		const args = ["issue", "view", String(issueNumber), "--json", "number,title,state,author,labels,assignees,milestone,createdAt,updatedAt,closedAt,body,comments,url"];
		if (opts.repo) args.push("--repo", opts.repo);

		const output = await gh(args, signal);
		const raw = JSON.parse(output);

		return {
			number: raw.number,
			title: raw.title,
			state: raw.state,
			author: raw.author,
			labels: raw.labels,
			assignees: raw.assignees,
			milestone: raw.milestone,
			createdAt: raw.createdAt,
			updatedAt: raw.updatedAt,
			closedAt: raw.closedAt,
			body: raw.body,
			comments: raw.comments || [],
			url: raw.url,
			commentsList: raw.comments || [],
		} as IssueWithComments;
	}

	// Register the tool for the LLM
	pi.registerTool({
		name: "github_issues",
		label: "GitHub Issues",
		description: `Look up GitHub issues for the current repo or a specified repo. Can list, search, and view issue details including comments. Uses the gh CLI. Output truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		parameters: Type.Object({
			action: StringEnum(["list", "view", "search"] as const, {
				description: "Action: 'list' to list issues, 'view' to view a specific issue with comments, 'search' to search issues",
			}),
			repo: Type.Optional(Type.String({ description: "Repository in owner/repo format. Omit to use the current repo." })),
			issue_number: Type.Optional(Type.Number({ description: "Issue number (required for 'view' action)" })),
			state: Type.Optional(StringEnum(["open", "closed", "all"] as const, { description: "Filter by state (default: open)" })),
			labels: Type.Optional(Type.String({ description: "Filter by label name" })),
			assignee: Type.Optional(Type.String({ description: "Filter by assignee username" })),
			author: Type.Optional(Type.String({ description: "Filter by author username" })),
			search: Type.Optional(Type.String({ description: "Search query for 'search' action" })),
			limit: Type.Optional(Type.Number({ description: "Max results to return (default: 30, max: 100)" })),
		}),

		async execute(_toolCallId, params, signal, onUpdate, _ctx) {
			const { action, repo, issue_number, state, labels, assignee, author, search, limit } = params;

			onUpdate?.({ content: [{ type: "text", text: "Fetching issues..." }] });

			try {
				let resultText: string;
				const details: IssueDetails = { action, repo };

				if (action === "view") {
					if (!issue_number) {
						return {
							content: [{ type: "text", text: "Error: issue_number is required for 'view' action" }],
							details: { action, repo },
							isError: true,
						};
					}
					const issue = await viewIssue(issue_number, { repo }, signal);
					resultText = formatIssueDetail(issue);
					details.issueNumber = issue_number;
				} else {
					const opts = {
						repo,
						state: state || "open",
						labels,
						assignee,
						author,
						search: action === "search" ? search : undefined,
						limit: Math.min(limit || 30, 100),
					};
					const issues = await listIssues(opts, signal);
					resultText = formatIssueList(issues);
					details.issueCount = issues.length;
				}

				// Truncate if needed
				const truncation = truncateHead(resultText, {
					maxLines: DEFAULT_MAX_LINES,
					maxBytes: DEFAULT_MAX_BYTES,
				});

				let finalText = truncation.content;
				if (truncation.truncated) {
					details.truncated = true;
					finalText += `\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
				}

				return {
					content: [{ type: "text", text: finalText }],
					details,
				};
			} catch (err: any) {
				return {
					content: [{ type: "text", text: `Error: ${err.message}` }],
					details: { action, repo },
					isError: true,
				};
			}
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("github_issues "));

			if (args.action === "view") {
				text += theme.fg("accent", `#${args.issue_number}`);
			} else if (args.action === "search") {
				text += theme.fg("accent", `search "${args.search || ""}"`);
			} else {
				text += theme.fg("accent", "list");
				if (args.state && args.state !== "open") text += theme.fg("dim", ` --state=${args.state}`);
				if (args.labels) text += theme.fg("dim", ` --label=${args.labels}`);
			}
			if (args.repo) text += theme.fg("muted", ` (${args.repo})`);

			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme) {
			const details = result.details as IssueDetails | undefined;

			if (isPartial) {
				return new Text(theme.fg("warning", "⏳ Fetching issues..."), 0, 0);
			}

			if (result.isError) {
				const errText = result.content[0]?.type === "text" ? result.content[0].text : "Unknown error";
				return new Text(theme.fg("error", `✗ ${errText}`), 0, 0);
			}

			if (!details) {
				return new Text(theme.fg("dim", "No details"), 0, 0);
			}

			let text: string;

			if (details.action === "view") {
				text = theme.fg("success", `✓ Issue #${details.issueNumber}`);
			} else {
				const count = details.issueCount ?? 0;
				text = theme.fg("success", `✓ ${count} issue(s) found`);
			}

			if (details.truncated) {
				text += theme.fg("warning", " (truncated)");
			}

			if (expanded) {
				const content = result.content[0];
				if (content?.type === "text") {
					const lines = content.text.split("\n").slice(0, 40);
					for (const line of lines) {
						text += `\n${theme.fg("dim", line)}`;
					}
					if (content.text.split("\n").length > 40) {
						text += `\n${theme.fg("muted", "... (expand tool output to see more)")}`;
					}
				}
			}

			return new Text(text, 0, 0);
		},
	});

	// Register /issues command for interactive browsing
	pi.registerCommand("issues", {
		description: "Browse GitHub issues interactively",
		handler: async (args, ctx) => {
			try {
				const parts = (args || "").trim().split(/\s+/);
				let repo: string | undefined;
				let state = "open";

				// Parse simple args: /issues [repo] [--state=open|closed|all]
				for (const part of parts) {
					if (part.startsWith("--state=")) {
						state = part.replace("--state=", "");
					} else if (part.includes("/") && !part.startsWith("--")) {
						repo = part;
					}
				}

				const issues = await listIssues({ repo, state, limit: 50 });

				if (issues.length === 0) {
					ctx.ui.notify("No issues found", "info");
					return;
				}

				const options = issues.map((issue) => {
					const labels = issue.labels.map((l) => l.name).join(", ");
					const meta = [formatRelative(issue.updatedAt), `${issue.comments.length} comments`];
					if (labels) meta.push(labels);
					return `${stateIcon(issue.state)} #${issue.number}: ${issue.title}  (${meta.join(" · ")})`;
				});

				const choice = await ctx.ui.select("Select an issue to view:", options);

				if (choice !== undefined) {
					const selectedIndex = options.indexOf(choice);
					const selected = issues[selectedIndex];
					const detail = await viewIssue(selected.number, { repo });
					const report = formatIssueDetail(detail);

					// Send the issue details as a user message for the LLM to discuss/work on
					pi.sendUserMessage(
						`Here is GitHub issue #${selected.number} for discussion:\n\n${report}\n\nPlease review this issue and let me know your thoughts. What would be the best approach to address it?`,
					);
				}
			} catch (err: any) {
				ctx.ui.notify(`Error: ${err.message}`, "error");
			}
		},
	});
}
