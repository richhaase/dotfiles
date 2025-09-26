# ============================================================================
# File Management
# ============================================================================

# File and directory aliases
alias ll="eza -la --icons --group-directories-first"
alias dirs='fd --type d | fzf --preview "eza --tree --color=always {}"'
alias files='fd --type f | fzf --preview "bat --color=always {}"'

# File manager integration - open yazi and cd to selected directory
y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}