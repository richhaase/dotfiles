# ============================================================================
# AWS & Cloud Tools
# ============================================================================

# AWS profile selector
awsp() {
  export AWS_PROFILE=$(aws configure list-profiles | fzf)
}