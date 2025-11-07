#!/usr/bin/env python3
"""
Git Contributor Statistics Calculator

Analyzes a git repository and generates statistics about contributors including:
- Number of commits
- Lines added/removed/net
- File changes

Usage: python git-contributor-stats.py [path_to_repo]
"""

import subprocess
import sys
import os
from collections import defaultdict
from typing import Dict, List, Tuple
import argparse


class GitStats:
    def __init__(self, repo_path: str = "."):
        self.repo_path = repo_path
        self.original_dir = os.getcwd()

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

    def get_commit_counts(self) -> Dict[str, int]:
        """Get commit counts per author."""
        output = self.run_git_command("git shortlog -sn --all --no-merges")
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
        authors_output = self.run_git_command("git log --all --format='%aN' | sort -u")
        authors = [a.strip() for a in authors_output.strip().split('\n') if a.strip()]

        for author in authors:
            # Escape special characters in author name for shell
            escaped_author = author.replace('"', '\\"').replace("'", "\\'")

            # Get stats for this author
            cmd = f'git log --all --author="{escaped_author}" --pretty=tformat: --numstat'
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

        authors = list(stats.keys()) + list(commits.keys())
        authors = list(set(authors))  # Remove duplicates

        for author in authors:
            if author in processed:
                continue

            # Find similar names (case-insensitive, removing spaces)
            base_name = author.lower().replace(' ', '')
            similar = []

            for other in authors:
                other_base = other.lower().replace(' ', '')
                if other_base == base_name or \
                   (len(base_name) > 5 and (base_name in other_base or other_base in base_name)):
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

    def print_statistics(self, sort_by: str = 'commits'):
        """Print formatted statistics."""
        print("\nAnalyzing git repository...")
        print("=" * 80)

        # Get data
        commits = self.get_commit_counts()
        line_stats = self.get_line_stats()

        # Merge similar authors
        line_stats, commits = self.merge_similar_authors(line_stats, commits)

        # Combine data
        all_authors = set(commits.keys()) | set(line_stats.keys())
        combined = []

        for author in all_authors:
            combined.append({
                'author': author,
                'commits': commits.get(author, 0),
                'added': line_stats.get(author, {}).get('added', 0),
                'removed': line_stats.get(author, {}).get('removed', 0),
                'net': line_stats.get(author, {}).get('net', 0),
                'files': line_stats.get(author, {}).get('files', 0)
            })

        # Sort based on criteria
        if sort_by == 'commits':
            combined.sort(key=lambda x: x['commits'], reverse=True)
        elif sort_by == 'added':
            combined.sort(key=lambda x: x['added'], reverse=True)
        elif sort_by == 'net':
            combined.sort(key=lambda x: x['net'], reverse=True)

        # Print header
        print(f"\n{'Rank':<6} {'Author':<30} {'Commits':<10} {'Added':<12} {'Removed':<12} {'Net':<12}")
        print("-" * 80)

        # Print top contributors
        for i, author_data in enumerate(combined[:20], 1):
            print(f"{i:<6} {author_data['author']:<30} "
                  f"{author_data['commits']:<10} "
                  f"{author_data['added']:<12,} "
                  f"{author_data['removed']:<12,} "
                  f"{author_data['net']:<12,}")

        # Summary statistics
        print("\n" + "=" * 80)
        print("REPOSITORY SUMMARY")
        print("-" * 80)
        print(f"Total contributors: {len(combined)}")
        print(f"Total commits: {sum(a['commits'] for a in combined):,}")
        print(f"Total lines added: {sum(a['added'] for a in combined):,}")
        print(f"Total lines removed: {sum(a['removed'] for a in combined):,}")
        print(f"Total lines changed: {sum(a['net'] for a in combined):,}")
        print("=" * 80)


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
        choices=['commits', 'added', 'net'],
        default='commits',
        help='Sort results by commits, lines added, or weighted contribution (default: commits)'
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

    # Run analysis
    with GitStats(args.repo_path) as stats:
        stats.print_statistics(sort_by=args.sort)


if __name__ == "__main__":
    main()
