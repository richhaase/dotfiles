# ============================================================================
# AWS & Cloud Tools
# ============================================================================

# AWS profile selector
awsp() {
  local profile
  profile=$(aws configure list-profiles | fzf) && [[ -n "$profile" ]] && export AWS_PROFILE="$profile"
}