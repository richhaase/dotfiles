# ============================================================================
# Aliases & Helpers
# ============================================================================

# System
alias b="bat"
alias refresh='exec zsh'

# Files
alias ll="eza -la --icons --group-directories-first"

# Tools
alias lg="lazygit"
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# File manager integration - open yazi and cd to selected directory
y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
