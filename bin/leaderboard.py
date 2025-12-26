#!/usr/bin/env python3
"""
Git Contributor Statistics Calculator

Analyzes a git repository and generates statistics about contributors including:
- Number of commits
- Lines added/removed/net
- File changes

Usage: leaderboard.py [path_to_repo]
"""

import subprocess
import sys
import os
import shlex
from collections import defaultdict
from typing import Dict, List, Tuple
import argparse


SORT_CHOICES = ['author', 'commits', 'added', 'removed', 'net', 'total']

DEFAULT_BRANCH = 'main'


class GitStats:
    def __init__(self, repo_path: str = ".", ref: str = DEFAULT_BRANCH):
        self.repo_path = repo_path
        self.original_dir = os.getcwd()
        self.ref = ref
        self.ref_arg = shlex.quote(ref)

    def __enter__(self):
        os.chdir(self.repo_path)
        return self

    def __exit__(self, *args):
        os.chdir(self.original_dir)

    def run_git_command(self, command: str) -> str:
        """Execute a git command and return the output."""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            print(f"Error running git command: {e}")
            return ""

    @staticmethod
    def _truncate(text: str, width: int) -> str:
        """Clamp overly long strings so table columns stay aligned."""
        if len(text) <= width or width <= 3:
            return text[:width]
        return text[:width - 3] + "..."

    @staticmethod
    def _header_label(label: str, width: int, active: bool, ascending: bool) -> str:
        """Annotate the active header with an arrow indicator within its width."""
        if not active or width <= 1:
            return label[:width]

        marker = ' ▲' if ascending else ' ▼'
        if len(marker) >= width:
            return label[:width]

        base_width = max(width - len(marker), 1)
        base = label[:base_width]
        return (base + marker)[:width]

    @staticmethod
    def _normalized_name(name: str) -> str:
        """Lowercase author name and strip whitespace for fuzzy matching."""
        return "".join(name.lower().split())

    @classmethod
    def _are_similar_names(cls, name_a: str, name_b: str) -> bool:
        norm_a = cls._normalized_name(name_a)
        norm_b = cls._normalized_name(name_b)

        if not norm_a or not norm_b:
            return False

        if norm_a == norm_b:
            return True

        if len(norm_a) > 5 and (norm_a in norm_b or norm_b in norm_a):
            return True

        if len(norm_b) > 5 and (norm_a in norm_b or norm_b in norm_a):
            return True

        return False

    def get_commit_counts(self) -> Dict[str, int]:
        """Get commit counts per author."""
        output = self.run_git_command(f"git shortlog -sn --no-merges {self.ref_arg}")
        counts = {}

        for line in output.strip().split('\n'):
            if line:
                parts = line.strip().split(None, 1)
                if len(parts) == 2:
                    count, author = parts
                    counts[author] = int(count.strip())

        return counts

    def get_line_stats(self) -> Dict[str, Dict[str, int]]:
        """Get lines added/removed statistics per author."""
        stats = defaultdict(lambda: {'added': 0, 'removed': 0, 'files': 0})

        # Get all authors first
        authors_output = self.run_git_command(
            f"git log {self.ref_arg} --format='%aN' | sort -u"
        )
        authors = [a.strip() for a in authors_output.strip().split('\n') if a.strip()]

        for author in authors:
            # Escape special characters in author name for shell
            escaped_author = author.replace('"', '\\"').replace("'", "\\'")

            # Get stats for this author
            cmd = (
                f'git log {self.ref_arg} --author="{escaped_author}" '
                f"--pretty=tformat: --numstat"
            )
            output = self.run_git_command(cmd)

            for line in output.strip().split('\n'):
                if line and '\t' in line:
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        added = parts[0]
                        removed = parts[1]

                        # Skip binary files (shown as '-')
                        if added != '-' and removed != '-':
                            try:
                                stats[author]['added'] += int(added)
                                stats[author]['removed'] += int(removed)
                                stats[author]['files'] += 1
                            except ValueError:
                                continue

        for author in stats:
            stats[author]['net'] = stats[author]['added'] - stats[author]['removed']

        return dict(stats)

    def merge_similar_authors(self, stats: Dict[str, Dict[str, int]],
                            commits: Dict[str, int]) -> Tuple[Dict[str, Dict[str, int]], Dict[str, int]]:
        """Merge statistics for authors with similar names."""
        merged_stats = {}
        merged_commits = {}
        processed = set()

        authors = sorted(set(list(stats.keys()) + list(commits.keys())), key=str.lower)

        for author in authors:
            if author in processed:
                continue

            # Find similar names (case-insensitive, removing spaces)
            similar = []

            for other in authors:
                if self._are_similar_names(author, other):
                    similar.append(other)
                    processed.add(other)

            # Use the most common form of the name
            canonical_name = max(similar, key=lambda x: commits.get(x, 0))

            # Merge stats
            merged_stats[canonical_name] = {'added': 0, 'removed': 0, 'files': 0, 'net': 0}
            merged_commits[canonical_name] = 0

            for name in similar:
                if name in stats:
                    merged_stats[canonical_name]['added'] += stats[name]['added']
                    merged_stats[canonical_name]['removed'] += stats[name]['removed']
                    merged_stats[canonical_name]['files'] += stats[name]['files']
                if name in commits:
                    merged_commits[canonical_name] += commits[name]

            merged_stats[canonical_name]['net'] = (
                merged_stats[canonical_name]['added'] -
                merged_stats[canonical_name]['removed']
            )

            if len(similar) > 1:
                print(f"Merged similar names: {', '.join(similar)} -> {canonical_name}")

        return merged_stats, merged_commits

    def print_statistics(self, sort_by: str = 'total', reverse_sort: bool = False):
        """Print formatted statistics."""
        author_width = 30
        total_width = 14
        row_format = (
            "{rank:<6} {author:<" + str(author_width) + "} "
            "{commits:<10} {added:<12} {removed:<12} {net:<12} {total:<" + str(total_width) + "}"
        )
        ascending_sort = True if sort_by == 'author' else False
        if reverse_sort:
            ascending_sort = not ascending_sort
        reverse = not ascending_sort
        header = row_format.format(
            rank="Rank",
            author=self._header_label("Author", author_width, sort_by == 'author', ascending_sort),
            commits=self._header_label("Commits", 10, sort_by == 'commits', ascending_sort),
            added=self._header_label("Added", 12, sort_by == 'added', ascending_sort),
            removed=self._header_label("Removed", 12, sort_by == 'removed', ascending_sort),
            net=self._header_label("Net", 12, sort_by == 'net', ascending_sort),
            total=self._header_label("Total Change", total_width, sort_by == 'total', ascending_sort)
        )
        table_width = len(header)

        print("\nAnalyzing git repository...")
        print("=" * table_width)

        # Get data
        commits = self.get_commit_counts()
        line_stats = self.get_line_stats()

        # Merge similar authors
        line_stats, commits = self.merge_similar_authors(line_stats, commits)

        # Combine data
        all_authors = set(commits.keys()) | set(line_stats.keys())
        combined = []

        for author in all_authors:
            added = line_stats.get(author, {}).get('added', 0)
            removed = line_stats.get(author, {}).get('removed', 0)
            combined.append({
                'author': author,
                'commits': commits.get(author, 0),
                'added': added,
                'removed': removed,
                'net': line_stats.get(author, {}).get('net', 0),
                'files': line_stats.get(author, {}).get('files', 0),
                'total_change': added + removed
            })

        # Sort based on criteria
        sort_key_map = {
            'author': lambda x: x['author'].lower(),
            'commits': lambda x: x['commits'],
            'added': lambda x: x['added'],
            'removed': lambda x: x['removed'],
            'net': lambda x: x['net'],
            'total': lambda x: x['total_change']
        }
        combined.sort(key=sort_key_map.get(sort_by, sort_key_map['total']), reverse=reverse)

        print(f"\n{header}")
        print("-" * table_width)

        # Print top contributors
        for i, author_data in enumerate(combined[:20], 1):
            display_author = self._truncate(author_data['author'], author_width)
            print(
                row_format.format(
                    rank=i,
                    author=display_author,
                    commits=author_data['commits'],
                    added=f"{author_data['added']:,}",
                    removed=f"{author_data['removed']:,}",
                    net=f"{author_data['net']:,}",
                    total=f"{author_data['total_change']:,}"
                )
            )

        # Summary statistics
        print("\n" + "=" * table_width)
        print("REPOSITORY SUMMARY")
        print("-" * table_width)
        print(f"Total contributors: {len(combined)}")
        print(f"Total commits: {sum(a['commits'] for a in combined):,}")
        print(f"Total lines added: {sum(a['added'] for a in combined):,}")
        print(f"Total lines removed: {sum(a['removed'] for a in combined):,}")
        print(f"Total net lines: {sum(a['net'] for a in combined):,}")
        print(f"Total lines changed: {sum(a['total_change'] for a in combined):,}")
        print("=" * table_width)


def main():
    parser = argparse.ArgumentParser(
        description='Generate contributor statistics for a git repository'
    )
    parser.add_argument(
        'repo_path',
        nargs='?',
        default='.',
        help='Path to git repository (default: current directory)'
    )
    parser.add_argument(
        '--sort',
        choices=SORT_CHOICES,
        default='total',
        help=(
            'Sort results by author, commits, added, removed, net, or total '
            'change (default: total)'
        ),
    )
    parser.add_argument(
        '--ref',
        default=None,
        help=(
            'Git ref/branch to analyze '
            '(default: auto-detected main branch)'
        ),
    )
    parser.add_argument(
        '--reverse',
        action='store_true',
        help='Flip the default sort direction (author defaults ascending, others descending)'
    )

    args = parser.parse_args()

    # Check if path exists
    if not os.path.exists(args.repo_path):
        print(f"Error: Path '{args.repo_path}' does not exist")
        sys.exit(1)

    # Check if it's a git repository
    git_dir = os.path.join(args.repo_path, '.git')
    if not os.path.exists(git_dir):
        print(f"Error: '{args.repo_path}' is not a git repository")
        sys.exit(1)

    # Determine which ref to analyze
    ref = args.ref

    if ref is None:
        # Try origin/HEAD first to respect the default branch
        try:
            result = subprocess.run(
                ['git', 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD'],
                cwd=args.repo_path,
                capture_output=True,
                text=True,
                check=True,
            )
            origin_head = result.stdout.strip()
            if origin_head:
                ref = origin_head.rsplit('/', 1)[-1]
        except subprocess.CalledProcessError:
            ref = None

    if ref is None:
        # Fallback to commonly used trunk branch names
        for candidate in ('main', 'master'):
            try:
                subprocess.run(
                    ['git', 'rev-parse', '--verify', candidate],
                    cwd=args.repo_path,
                    capture_output=True,
                    check=True,
                    text=True,
                )
                ref = candidate
                break
            except subprocess.CalledProcessError:
                continue

    if ref is None:
        # Final fallback: analyze the current HEAD
        ref = 'HEAD'

    # Ensure requested ref exists
    try:
        subprocess.run(
            ['git', 'rev-parse', '--verify', ref],
            cwd=args.repo_path,
            capture_output=True,
            check=True,
            text=True,
        )
    except subprocess.CalledProcessError:
        print(
            f"Error: Git ref '{ref}' not found. "
            "Use --ref to specify an existing branch or commit."
        )
        sys.exit(1)

    # Run analysis
    with GitStats(args.repo_path, ref=ref) as stats:
        stats.print_statistics(sort_by=args.sort, reverse_sort=args.reverse)


if __name__ == "__main__":
    main()
