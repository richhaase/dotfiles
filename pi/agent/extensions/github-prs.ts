/**
 * GitHub Pull Requests Extension
 *
 * Provides a `github_prs` tool for the LLM and a `/prs` command for
 * interactive browsing. Supports viewing, approving, requesting changes,
 * and commenting on PRs. Uses the `gh` CLI under the hood.
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

// ── Types ──────────────────────────────────────────────────────────────────

interface PR {
	number: number;
	title: string;
	state: string;
	author: { login: string };
	headRefName: string;
	baseRefName: string;
	labels: { name: string }[];
	assignees: { login: string }[];
	reviewDecision: string;
	isDraft: boolean;
	additions: number;
	deletions: number;
	changedFiles: number;
	createdAt: string;
	updatedAt: string;
	mergedAt?: string | null;
	closedAt?: string | null;
	body: string;
	comments: PRComment[];
	latestReviews: PRReview[];
	url: string;
	mergeable: string;
}

interface PRComment {
	author: { login: string };
	createdAt: string;
	body: string;
}

interface PRReview {
	author: { login: string };
	state: string;
	body: string;
	submittedAt: string;
}

interface PRFile {
	path: string;
	additions: number;
	deletions: number;
}

interface PRDetails {
	action: string;
	repo?: string;
	prCount?: number;
	prNumber?: number;
	truncated?: boolean;
	reviewAction?: string;
}

// ── Formatting helpers ─────────────────────────────────────────────────────

function formatDate(iso: string): string {
	const d = new Date(iso);
	return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
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

function stateIcon(pr: { state: string; isDraft: boolean }): string {
	if (pr.isDraft) return "📝";
	switch (pr.state) {
		case "OPEN": return "🟢";
		case "MERGED": return "🟣";
		case "CLOSED": return "🔴";
		default: return "⚪";
	}
}

function reviewIcon(decision: string): string {
	switch (decision) {
		case "APPROVED": return "✅";
		case "CHANGES_REQUESTED": return "🔄";
		case "REVIEW_REQUIRED": return "👀";
		default: return "";
	}
}

function formatPRList(prs: PR[]): string {
	if (prs.length === 0) return "No pull requests found.";

	const lines: string[] = [];
	lines.push(`Found ${prs.length} pull request(s):\n`);

	for (const pr of prs) {
		const labels = pr.labels.map((l) => l.name).join(", ");
		const review = reviewIcon(pr.reviewDecision);
		const draft = pr.isDraft ? " (draft)" : "";
		const stats = `+${pr.additions} -${pr.deletions} (${pr.changedFiles} files)`;

		lines.push(`${stateIcon(pr)} #${pr.number}: ${pr.title}${draft}  ${review}`);
		lines.push(`   ${pr.headRefName} → ${pr.baseRefName}  |  @${pr.author.login}  |  ${formatRelative(pr.updatedAt)}  |  ${stats}`);
		if (labels) lines.push(`   Labels: ${labels}`);
		lines.push("");
	}

	return lines.join("\n");
}

function formatPRDetail(pr: PR, diff?: string, files?: PRFile[]): string {
	const lines: string[] = [];
	const labels = pr.labels.map((l) => l.name).join(", ");
	const assignees = pr.assignees.map((a) => a.login).join(", ");

	lines.push(`${"═".repeat(60)}`);
	lines.push(`${stateIcon(pr)} PR #${pr.number}: ${pr.title}`);
	lines.push(`${"═".repeat(60)}`);
	lines.push("");
	lines.push(`State:      ${pr.state}${pr.isDraft ? " (draft)" : ""}`);
	lines.push(`Author:     @${pr.author.login}`);
	lines.push(`Branch:     ${pr.headRefName} → ${pr.baseRefName}`);
	lines.push(`Review:     ${pr.reviewDecision || "none"} ${reviewIcon(pr.reviewDecision)}`);
	lines.push(`Mergeable:  ${pr.mergeable}`);
	lines.push(`Changes:    +${pr.additions} -${pr.deletions} (${pr.changedFiles} files)`);
	lines.push(`Created:    ${formatDate(pr.createdAt)}`);
	lines.push(`Updated:    ${formatDate(pr.updatedAt)}`);
	if (pr.mergedAt) lines.push(`Merged:     ${formatDate(pr.mergedAt)}`);
	if (pr.closedAt && !pr.mergedAt) lines.push(`Closed:     ${formatDate(pr.closedAt)}`);
	if (labels) lines.push(`Labels:     ${labels}`);
	if (assignees) lines.push(`Assignees:  ${assignees}`);
	lines.push(`URL:        ${pr.url}`);
	lines.push("");

	lines.push(`${"─".repeat(60)}`);
	lines.push("Description:");
	lines.push(`${"─".repeat(60)}`);
	lines.push(pr.body || "(no description)");
	lines.push("");

	if (files && files.length > 0) {
		lines.push(`${"─".repeat(60)}`);
		lines.push(`Changed Files (${files.length}):`);
		lines.push(`${"─".repeat(60)}`);
		for (const f of files) {
			lines.push(`  +${f.additions} -${f.deletions}  ${f.path}`);
		}
		lines.push("");
	}

	if (pr.latestReviews && pr.latestReviews.length > 0) {
		lines.push(`${"─".repeat(60)}`);
		lines.push(`Reviews (${pr.latestReviews.length}):`);
		lines.push(`${"─".repeat(60)}`);
		lines.push("");
		for (const review of pr.latestReviews) {
			lines.push(`  ${reviewIcon(review.state)} @${review.author.login} — ${review.state} — ${formatDate(review.submittedAt)}`);
			if (review.body) {
				for (const bl of review.body.split("\n")) {
					lines.push(`     ${bl}`);
				}
			}
			lines.push("");
		}
	}

	if (pr.comments && pr.comments.length > 0) {
		lines.push(`${"─".repeat(60)}`);
		lines.push(`Comments (${pr.comments.length}):`);
		lines.push(`${"─".repeat(60)}`);
		lines.push("");
		for (const comment of pr.comments) {
			lines.push(`  💬 @${comment.author.login} — ${formatDate(comment.createdAt)}`);
			for (const bl of (comment.body || "").split("\n")) {
				lines.push(`     ${bl}`);
			}
			lines.push("");
		}
	}

	if (diff) {
		lines.push(`${"─".repeat(60)}`);
		lines.push("Diff:");
		lines.push(`${"─".repeat(60)}`);
		lines.push(diff);
	}

	return lines.join("\n");
}

// ── Extension ──────────────────────────────────────────────────────────────

const PR_LIST_FIELDS = "number,title,state,author,headRefName,baseRefName,labels,assignees,reviewDecision,isDraft,additions,deletions,changedFiles,createdAt,updatedAt,mergedAt,closedAt,body,comments,latestReviews,url,mergeable";

export default function (pi: ExtensionAPI) {

	async function gh(args: string[], signal?: AbortSignal): Promise<string> {
		const result = await pi.exec("gh", args, { signal, timeout: 30000 });
		if (result.code !== 0) {
			throw new Error(`gh ${args.join(" ")} failed (exit ${result.code}): ${result.stderr}`);
		}
		return result.stdout;
	}

	async function listPRs(
		opts: { repo?: string; state?: string; labels?: string; assignee?: string; author?: string; search?: string; limit?: number; base?: string; head?: string },
		signal?: AbortSignal,
	): Promise<PR[]> {
		const args = ["pr", "list", "--json", PR_LIST_FIELDS];
		if (opts.repo) args.push("--repo", opts.repo);
		if (opts.state) args.push("--state", opts.state);
		if (opts.labels) args.push("--label", opts.labels);
		if (opts.assignee) args.push("--assignee", opts.assignee);
		if (opts.author) args.push("--author", opts.author);
		if (opts.search) args.push("--search", opts.search);
		if (opts.base) args.push("--base", opts.base);
		if (opts.head) args.push("--head", opts.head);
		args.push("--limit", String(opts.limit || 30));

		const output = await gh(args, signal);
		return JSON.parse(output) as PR[];
	}

	async function viewPR(
		prNumber: number,
		opts: { repo?: string },
		signal?: AbortSignal,
	): Promise<PR> {
		const args = ["pr", "view", String(prNumber), "--json", PR_LIST_FIELDS];
		if (opts.repo) args.push("--repo", opts.repo);
		const output = await gh(args, signal);
		const raw = JSON.parse(output);
		return {
			...raw,
			comments: raw.comments || [],
			latestReviews: raw.latestReviews || [],
		} as PR;
	}

	async function getPRDiff(
		prNumber: number,
		opts: { repo?: string },
		signal?: AbortSignal,
	): Promise<string> {
		const args = ["pr", "diff", String(prNumber), "--color=never"];
		if (opts.repo) args.push("--repo", opts.repo);
		return gh(args, signal);
	}

	async function getPRFiles(
		prNumber: number,
		opts: { repo?: string },
		signal?: AbortSignal,
	): Promise<PRFile[]> {
		const args = ["pr", "view", String(prNumber), "--json", "files"];
		if (opts.repo) args.push("--repo", opts.repo);
		const output = await gh(args, signal);
		const raw = JSON.parse(output);
		return (raw.files || []) as PRFile[];
	}

	async function reviewPR(
		prNumber: number,
		action: "approve" | "request-changes" | "comment",
		body: string,
		opts: { repo?: string },
		signal?: AbortSignal,
	): Promise<string> {
		const args = ["pr", "review", String(prNumber)];
		switch (action) {
			case "approve": args.push("--approve"); break;
			case "request-changes": args.push("--request-changes"); break;
			case "comment": args.push("--comment"); break;
		}
		if (body) args.push("--body", body);
		if (opts.repo) args.push("--repo", opts.repo);
		return gh(args, signal);
	}

	let cachedUser: string | undefined;
	async function getCurrentUser(signal?: AbortSignal): Promise<string> {
		if (cachedUser) return cachedUser;
		const output = await gh(["api", "user", "--jq", ".login"], signal);
		cachedUser = output.trim();
		return cachedUser;
	}

	async function mergePR(
		prNumber: number,
		method: "merge" | "squash" | "rebase",
		opts: { repo?: string; deleteBranch?: boolean },
		signal?: AbortSignal,
	): Promise<string> {
		const args = ["pr", "merge", String(prNumber), `--${method}`];
		if (opts.deleteBranch) args.push("--delete-branch");
		if (opts.repo) args.push("--repo", opts.repo);
		return gh(args, signal);
	}

	// ── LLM Tool ───────────────────────────────────────────────────────────

	pi.registerTool({
		name: "github_prs",
		label: "GitHub PRs",
		description: `Interact with GitHub pull requests. List, view (with diff), approve, request changes, or comment. Uses the gh CLI. Output truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(DEFAULT_MAX_BYTES)}.`,
		parameters: Type.Object({
			action: StringEnum(["list", "view", "diff", "review", "files"] as const, {
				description: "Action: 'list' PRs, 'view' PR details, 'diff' for PR diff, 'files' for changed files, 'review' to approve/request-changes/comment",
			}),
			repo: Type.Optional(Type.String({ description: "Repository in owner/repo format. Omit for current repo." })),
			pr_number: Type.Optional(Type.Number({ description: "PR number (required for view/diff/review/files)" })),
			state: Type.Optional(StringEnum(["open", "closed", "merged", "all"] as const, { description: "Filter by state (default: open)" })),
			labels: Type.Optional(Type.String({ description: "Filter by label" })),
			assignee: Type.Optional(Type.String({ description: "Filter by assignee" })),
			author: Type.Optional(Type.String({ description: "Filter by author" })),
			search: Type.Optional(Type.String({ description: "Search query" })),
			base: Type.Optional(Type.String({ description: "Filter by base branch" })),
			head: Type.Optional(Type.String({ description: "Filter by head branch" })),
			limit: Type.Optional(Type.Number({ description: "Max results (default: 30, max: 100)" })),
			review_action: Type.Optional(StringEnum(["approve", "request-changes", "comment"] as const, {
				description: "Review action (required when action is 'review')",
			})),
			body: Type.Optional(Type.String({ description: "Review/comment body text" })),
		}),

		async execute(_toolCallId, params, signal, onUpdate, _ctx) {
			const { action, repo, pr_number, state, labels, assignee, author, search, base, head, limit, review_action, body } = params;

			onUpdate?.({ content: [{ type: "text", text: `Processing PR ${action}...` }] });

			try {
				let resultText: string;
				const details: PRDetails = { action, repo };

				switch (action) {
					case "view": {
						if (!pr_number) return { content: [{ type: "text", text: "Error: pr_number is required for 'view'" }], details, isError: true };
						const pr = await viewPR(pr_number, { repo }, signal);
						const files = await getPRFiles(pr_number, { repo }, signal);
						resultText = formatPRDetail(pr, undefined, files);
						details.prNumber = pr_number;
						break;
					}
					case "diff": {
						if (!pr_number) return { content: [{ type: "text", text: "Error: pr_number is required for 'diff'" }], details, isError: true };
						resultText = await getPRDiff(pr_number, { repo }, signal);
						details.prNumber = pr_number;
						break;
					}
					case "files": {
						if (!pr_number) return { content: [{ type: "text", text: "Error: pr_number is required for 'files'" }], details, isError: true };
						const files = await getPRFiles(pr_number, { repo }, signal);
						resultText = files.map((f) => `+${f.additions} -${f.deletions}  ${f.path}`).join("\n") || "No files changed.";
						details.prNumber = pr_number;
						break;
					}
					case "review": {
						if (!pr_number) return { content: [{ type: "text", text: "Error: pr_number is required for 'review'" }], details, isError: true };
						if (!review_action) return { content: [{ type: "text", text: "Error: review_action is required for 'review'" }], details, isError: true };
						resultText = await reviewPR(pr_number, review_action, body || "", { repo }, signal);
						details.prNumber = pr_number;
						details.reviewAction = review_action;
						break;
					}
					default: {
						const prs = await listPRs({ repo, state: state || "open", labels, assignee, author, search, base, head, limit: Math.min(limit || 30, 100) }, signal);
						resultText = formatPRList(prs);
						details.prCount = prs.length;
						break;
					}
				}

				const truncation = truncateHead(resultText, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
				let finalText = truncation.content;
				if (truncation.truncated) {
					details.truncated = true;
					finalText += `\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)})]`;
				}

				return { content: [{ type: "text", text: finalText }], details };
			} catch (err: any) {
				return { content: [{ type: "text", text: `Error: ${err.message}` }], details: { action, repo }, isError: true };
			}
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("github_prs "));
			switch (args.action) {
				case "view": text += theme.fg("accent", `#${args.pr_number}`); break;
				case "diff": text += theme.fg("accent", `diff #${args.pr_number}`); break;
				case "files": text += theme.fg("accent", `files #${args.pr_number}`); break;
				case "review": text += theme.fg("accent", `${args.review_action} #${args.pr_number}`); break;
				default: {
					text += theme.fg("accent", "list");
					if (args.state && args.state !== "open") text += theme.fg("dim", ` --state=${args.state}`);
				}
			}
			if (args.repo) text += theme.fg("muted", ` (${args.repo})`);
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme) {
			const details = result.details as PRDetails | undefined;

			if (isPartial) return new Text(theme.fg("warning", "⏳ Loading..."), 0, 0);
			if (result.isError) {
				const errText = result.content[0]?.type === "text" ? result.content[0].text : "Unknown error";
				return new Text(theme.fg("error", `✗ ${errText}`), 0, 0);
			}
			if (!details) return new Text(theme.fg("dim", "No details"), 0, 0);

			let text: string;
			if (details.reviewAction) {
				text = theme.fg("success", `✓ ${details.reviewAction} PR #${details.prNumber}`);
			} else if (details.action === "view" || details.action === "diff" || details.action === "files") {
				text = theme.fg("success", `✓ PR #${details.prNumber}`);
			} else {
				text = theme.fg("success", `✓ ${details.prCount ?? 0} PR(s) found`);
			}
			if (details.truncated) text += theme.fg("warning", " (truncated)");

			if (expanded) {
				const content = result.content[0];
				if (content?.type === "text") {
					const lines = content.text.split("\n").slice(0, 40);
					for (const line of lines) text += `\n${theme.fg("dim", line)}`;
					if (content.text.split("\n").length > 40) text += `\n${theme.fg("muted", "... (expand to see more)")}`;
				}
			}

			return new Text(text, 0, 0);
		},
	});

	// ── /prs Command ───────────────────────────────────────────────────────

	pi.registerCommand("prs", {
		description: "Browse and review GitHub PRs interactively",
		handler: async (args, ctx) => {
			try {
				const parts = (args || "").trim().split(/\s+/);
				let repo: string | undefined;
				let state = "open";

				for (const part of parts) {
					if (part.startsWith("--state=")) {
						state = part.replace("--state=", "");
					} else if (part.includes("/") && !part.startsWith("--")) {
						repo = part;
					}
				}

				const prs = await listPRs({ repo, state, limit: 50 });

				if (prs.length === 0) {
					ctx.ui.notify("No pull requests found", "info");
					return;
				}

				// ── Select a PR ────────────────────────────────────────────────

				const prOptions = prs.map((pr) => {
					const review = reviewIcon(pr.reviewDecision);
					const draft = pr.isDraft ? " (draft)" : "";
					return `${stateIcon(pr)} #${pr.number}: ${pr.title}${draft}  ${review}  (+${pr.additions}/-${pr.deletions}, ${formatRelative(pr.updatedAt)})`;
				});

				const prChoice = await ctx.ui.select("Select a PR:", prOptions);
				if (prChoice === undefined) return;

				const selectedIndex = prOptions.indexOf(prChoice);
				const selected = prs[selectedIndex];
				if (!selected) return;

				// ── Choose action (context-aware) ──────────────────────────────

				const currentUser = await getCurrentUser();
				const isOwnPR = selected.author.login === currentUser;
				const isOpen = selected.state === "OPEN";

				const actions: { key: string; label: string }[] = [
					{ key: "view", label: "👁️  View — send PR details to chat" },
					{ key: "diff", label: "📄 Diff — send PR diff to chat" },
				];

				if (isOpen) {
					if (!isOwnPR) {
						actions.push({ key: "approve", label: "✅ Approve" });
						actions.push({ key: "request-changes", label: "🔄 Request Changes" });
					}
					actions.push({ key: "merge", label: "🔀 Merge" });
					actions.push({ key: "comment", label: "💬 Comment" });
				}

				const actionChoice = await ctx.ui.select(
					`PR #${selected.number}: ${selected.title}`,
					actions.map((a) => a.label),
				);
				if (actionChoice === undefined) return;

				const actionKey = actions[actions.map((a) => a.label).indexOf(actionChoice)]?.key;
				if (!actionKey) return;

				switch (actionKey) {
					case "view": {
						const pr = await viewPR(selected.number, { repo });
						const files = await getPRFiles(selected.number, { repo });
						const report = formatPRDetail(pr, undefined, files);
						pi.sendUserMessage(
							`Here is PR #${selected.number} for discussion:\n\n${report}\n\nPlease review this PR and share your thoughts.`,
						);
						break;
					}
					case "diff": {
						const diff = await getPRDiff(selected.number, { repo });
						pi.sendUserMessage(
							`Here is the diff for PR #${selected.number} (${selected.title}):\n\n\`\`\`diff\n${diff}\n\`\`\`\n\nPlease review this diff and share your thoughts.`,
						);
						break;
					}
					case "approve": {
						const ok = await ctx.ui.confirm(
							`Approve PR #${selected.number}?`,
							`${selected.title} by @${selected.author.login}`,
						);
						if (ok) {
							const body = await ctx.ui.input("Approval comment (optional):", "LGTM!");
							await reviewPR(selected.number, "approve", body || "", { repo });
							ctx.ui.notify(`✅ Approved PR #${selected.number}`, "info");
						}
						break;
					}
					case "request-changes": {
						const body = await ctx.ui.input("What changes are needed?", "");
						if (body) {
							await reviewPR(selected.number, "request-changes", body, { repo });
							ctx.ui.notify(`🔄 Requested changes on PR #${selected.number}`, "info");
						} else {
							ctx.ui.notify("Cancelled — a body is required for requesting changes", "warning");
						}
						break;
					}
					case "merge": {
						const methods = ["squash", "merge", "rebase"];
						const methodChoice = await ctx.ui.select("Merge method:", methods);
						if (methodChoice === undefined) break;
						const method = methodChoice as "merge" | "squash" | "rebase";

						const deleteBranch = await ctx.ui.confirm("Delete branch after merge?", selected.headRefName);

						const ok = await ctx.ui.confirm(
							`${method} PR #${selected.number}?`,
							`${selected.title} (${selected.headRefName} → ${selected.baseRefName})`,
						);
						if (ok) {
							await mergePR(selected.number, method, { repo, deleteBranch });
							ctx.ui.notify(`🔀 Merged PR #${selected.number} via ${method}`, "info");
						}
						break;
					}
					case "comment": {
						const body = await ctx.ui.input("Comment:", "");
						if (body) {
							await reviewPR(selected.number, "comment", body, { repo });
							ctx.ui.notify(`💬 Commented on PR #${selected.number}`, "info");
						}
						break;
					}
				}
			} catch (err: any) {
				ctx.ui.notify(`Error: ${err.message}`, "error");
			}
		},
	});
}
