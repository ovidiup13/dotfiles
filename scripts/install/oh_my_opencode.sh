#!/usr/bin/env bash

set -euo pipefail

validate_omo_yes_no_flag() {
  local flag_name="$1"
  local flag_value="$2"

  case "$flag_value" in
    yes|no)
      ;;
    *)
      log_error "$flag_name must be 'yes' or 'no' (got: $flag_value)"
      exit 1
      ;;
  esac
}

validate_omo_claude_flag() {
  local flag_value="$1"

  case "$flag_value" in
    yes|no|max20)
      ;;
    *)
      log_error "DOTFILES_OMO_CLAUDE must be 'yes', 'no', or 'max20' (got: $flag_value)"
      exit 1
      ;;
  esac
}

sanitize_oh_my_opencode_config() {
  local config_file="$HOME/.config/opencode/opencode.json"
  local tmp_file

  if [ ! -f "$config_file" ]; then
    return 0
  fi

  tmp_file="$(mktemp)"

  if ! jq '
    if (.plugin // null) == null then
      .
    else
      .plugin = [
        (.plugin // [])[]
        | select(test("^oh-my-open(agent|code)(@.*)?$") | not)
      ]
      | if (.plugin | length) == 0 then
          del(.plugin)
        else
          .
        end
    end
  ' "$config_file" > "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$config_file"
}

install_macos_oh_my_opencode() {
  local claude_flag="${DOTFILES_OMO_CLAUDE:-no}"
  local openai_flag="${DOTFILES_OMO_OPENAI:-yes}"
  local gemini_flag="${DOTFILES_OMO_GEMINI:-no}"
  local copilot_flag="${DOTFILES_OMO_COPILOT:-no}"
  local opencode_zen_flag="${DOTFILES_OMO_OPENCODE_ZEN:-no}"
  local zai_coding_plan_flag="${DOTFILES_OMO_ZAI_CODING_PLAN:-no}"
  local opencode_go_flag="${DOTFILES_OMO_OPENCODE_GO:-no}"
  local kimi_for_coding_flag="${DOTFILES_OMO_KIMI_FOR_CODING:-no}"
  local vercel_ai_gateway_flag="${DOTFILES_OMO_VERCEL_AI_GATEWAY:-no}"

  validate_omo_claude_flag "$claude_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_OPENAI" "$openai_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_GEMINI" "$gemini_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_COPILOT" "$copilot_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_OPENCODE_ZEN" "$opencode_zen_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_ZAI_CODING_PLAN" "$zai_coding_plan_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_OPENCODE_GO" "$opencode_go_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_KIMI_FOR_CODING" "$kimi_for_coding_flag"
  validate_omo_yes_no_flag "DOTFILES_OMO_VERCEL_AI_GATEWAY" "$vercel_ai_gateway_flag"

  if ! command_exists opencode; then
    log_warn "Skipping Oh My OpenAgent setup because opencode is not installed."
    return
  fi

  if ! command_exists bunx; then
    log_warn "Skipping Oh My OpenAgent setup because bunx is not available."
    return
  fi

  if [ ! -f "$HOME/.config/opencode/opencode.json" ]; then
    log_warn "Skipping Oh My OpenAgent setup because ~/.config/opencode/opencode.json was not found."
    return
  fi

  if ! sanitize_oh_my_opencode_config; then
    log_error "Failed to sanitize ~/.config/opencode/opencode.json before Oh My OpenAgent setup. Plain opencode would not be guaranteed to stay plugin-free."
    return 1
  fi

  if bunx oh-my-openagent doctor >/dev/null 2>&1; then
    log_info "Oh My OpenAgent already installed and healthy"
    return
  fi

  log_step "Installing Oh My OpenAgent"
  if ! bunx oh-my-openagent install \
    --no-tui \
    --skip-auth \
    --claude="$claude_flag" \
    --openai="$openai_flag" \
    --gemini="$gemini_flag" \
    --copilot="$copilot_flag" \
    --opencode-zen="$opencode_zen_flag" \
    --zai-coding-plan="$zai_coding_plan_flag" \
    --opencode-go="$opencode_go_flag" \
    --kimi-for-coding="$kimi_for_coding_flag" \
    --vercel-ai-gateway="$vercel_ai_gateway_flag"; then
    log_warn "Oh My OpenAgent installation failed. Continuing without it."
    return
  fi

  if ! sanitize_oh_my_opencode_config; then
    log_error "Failed to sanitize ~/.config/opencode/opencode.json after Oh My OpenAgent install. Plain opencode would not be guaranteed to stay plugin-free."
    return 1
  fi

  log_step "Verifying Oh My OpenAgent setup"
  if ! bunx oh-my-openagent doctor; then
    log_warn "Oh My OpenAgent doctor verification failed. Continuing without blocking the rest of post-link setup."
  fi
}
