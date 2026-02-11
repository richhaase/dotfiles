# ============================================================================
# File Management
# ============================================================================

# File and directory aliases
alias ll="eza -la --icons --group-directories-first"

# File manager integration - open yazi and cd to selected directory
y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}