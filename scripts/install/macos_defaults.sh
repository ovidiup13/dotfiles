#!/usr/bin/env bash

set -euo pipefail

restart_dock=0
restart_finder=0

normalize_macos_default_value() {
  local type="$1"
  local value="$2"

  case "$type" in
    -bool)
      value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
      case "$value" in
        1|yes|true)
          printf 'true\n'
          ;;
        0|no|false)
          printf 'false\n'
          ;;
        *)
          printf '%s\n' "$value"
          ;;
      esac
      ;;
    -int)
      printf '%s\n' "$(printf '%s' "$value" | tr -d '[:space:]')"
      ;;
    -string)
      printf '%s\n' "$value"
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

macos_default_matches() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local expected="$4"
  local use_sudo="${5:-0}"
  local current

  if [ "$use_sudo" -eq 1 ]; then
    if ! current="$(sudo defaults read "$domain" "$key" 2>/dev/null)"; then
      return 1
    fi
  else
    if ! current="$(defaults read "$domain" "$key" 2>/dev/null)"; then
      return 1
    fi
  fi

  current="$(normalize_macos_default_value "$type" "$current")"
  expected="$(normalize_macos_default_value "$type" "$expected")"
  [ "$current" = "$expected" ]
}

mark_macos_service_restart() {
  local domain="$1"

  case "$domain" in
    com.apple.dock)
      restart_dock=1
      ;;
    com.apple.finder)
      restart_finder=1
      ;;
  esac
}

write_macos_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local value="$4"
  local message="$5"
  local use_sudo="${6:-0}"

  if macos_default_matches "$domain" "$key" "$type" "$value" "$use_sudo"; then
    return 1
  fi

  log_info "$message"
  if [ "$use_sudo" -eq 1 ]; then
    sudo defaults write "$domain" "$key" "$type" "$value"
  else
    defaults write "$domain" "$key" "$type" "$value"
  fi

  mark_macos_service_restart "$domain"
  return 0
}

set_macos_default_browser() {
  local script_path
  local firefox_bundle_id

  firefox_bundle_id="org.mozilla.firefox"

  if ! command_exists swift; then
    log_warn "Skipping default browser setup because swift is not installed."
    return
  fi

  script_path="$REPO_ROOT/scripts/install/set_default_browser.swift"

  if [ ! -f "$script_path" ]; then
    log_warn "Skipping default browser setup because $script_path was not found."
    return
  fi

  if [ ! -d "/Applications/Firefox.app" ]; then
    log_warn "Skipping default browser setup because Firefox is not installed."
    return
  fi

  if swift "$script_path" --is-default "$firefox_bundle_id"; then
    return
  fi

  log_info "Setting Firefox as the default browser"
  if ! swift "$script_path" "$firefox_bundle_id"; then
    log_warn "Skipping default browser setup because Launch Services rejected the update."
  fi
}

apply_macos_power_settings() {
  log_info "Setting standby delay to 24 hours"
  sudo pmset -a standbydelay 86400
}

apply_macos_startup_settings() {
  log_info "Disabling boot sound"
  sudo nvram SystemAudioVolume=" "
  write_macos_default /Library/Preferences/com.apple.loginwindow AdminHostInfo -string HostName "Showing host info in the login window clock" 1 || true
}

apply_macos_screenshot_settings() {
  mkdir -p "$HOME/Documents/Screenshots"
  write_macos_default com.apple.screencapture location -string "$HOME/Documents/Screenshots" "Saving screenshots to ~/Documents/Screenshots" || true
  write_macos_default com.apple.screencapture type -string png "Saving screenshots in PNG format" || true
}

apply_macos_safari_settings() {
  if pgrep -x Safari >/dev/null 2>&1; then
    log_warn "Skipping Safari defaults because Safari is running. Quit Safari and rerun ./install --macos-defaults."
    return
  fi

  if ! defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true >/dev/null 2>&1; then
    log_warn "Skipping Safari defaults because Safari preferences are not writable right now."
    return
  fi

  write_macos_default com.apple.Safari ShowFullURLInSmartSearchField -bool true "Showing full URL in Safari smart search field" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari UniversalSearchEnabled -bool false "Disabling Safari search query sharing and suggestions" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari SuppressSearchSuggestions -bool true "Disabling Safari search query sharing and suggestions" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari HomePage -string about:blank "Setting Safari home page to about:blank" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari IncludeInternalDebugMenu -bool true "Enabling Safari internal debug menu" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari IncludeDevelopMenu -bool true "Enabling Safari Develop menu and Web Inspector" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true "Enabling Safari Develop menu and Web Inspector" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true "Enabling Safari Develop menu and Web Inspector" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari AutoFillFromAddressBook -bool false "Disabling Safari AutoFill" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari AutoFillPasswords -bool false "Disabling Safari AutoFill" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari AutoFillCreditCardData -bool false "Disabling Safari AutoFill" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari AutoFillMiscellaneousForms -bool false "Disabling Safari AutoFill" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari WebKitJavaEnabled -bool false "Disabling Safari Java support" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false "Disabling Safari Java support" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari SendDoNotTrackHTTPHeader -bool true "Enabling Safari Do Not Track and extension auto-updates" >/dev/null 2>&1 || true
  write_macos_default com.apple.Safari InstallExtensionUpdatesAutomatically -bool true "Enabling Safari Do Not Track and extension auto-updates" >/dev/null 2>&1 || true
}

apply_macos_software_update_settings() {
  write_macos_default com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true "Enabling automatic software update checks" || true
  write_macos_default com.apple.SoftwareUpdate ScheduleFrequency -int 1 "Checking for software updates daily" || true
  write_macos_default com.apple.SoftwareUpdate AutomaticDownload -int 1 "Downloading new software updates in the background" || true
  write_macos_default com.apple.SoftwareUpdate CriticalUpdateInstall -int 1 "Installing critical data files and security updates" || true
  write_macos_default com.apple.commerce AutoUpdate -bool true "Enabling App Store app auto-updates" || true
  write_macos_default com.apple.commerce AutoUpdateRestartRequired -bool false "Preventing App Store updates from forcing reboots" || true
}

apply_macos_home_visibility_settings() {
  log_info "Showing ~/Library"
  chflags nohidden "$HOME/Library"
  log_info "Showing /Volumes"
  sudo chflags nohidden /Volumes
}

apply_macos_defaults() {
  log_step "Applying macOS defaults"

  # Dock
  write_macos_default com.apple.dock autohide -bool true "Enabling Dock auto-hide" || true
  write_macos_default com.apple.dock mineffect -string scale "Setting Dock minimize effect to scale" || true
  write_macos_default com.apple.dock minimize-to-application -bool true "Minimizing windows into their application icon" || true
  write_macos_default com.apple.dock scroll-to-open -bool true "Enabling Scroll to Expose app" || true

  # Global
  write_macos_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false "Disabling double-space period substitution" || true
  write_macos_default NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false "Disabling automatic capitalization" || true
  write_macos_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false "Disabling smart dashes" || true
  write_macos_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false "Disabling smart quotes" || true
  write_macos_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false "Disabling auto-correct" || true
  write_macos_default com.apple.desktopservices DSDontWriteNetworkStores -bool true "Avoiding .DS_Store files on network and USB volumes" || true
  write_macos_default com.apple.desktopservices DSDontWriteUSBStores -bool true "Avoiding .DS_Store files on network and USB volumes" || true
  write_macos_default com.apple.frameworks.diskimages auto-open-ro-root -bool true "Opening new Finder windows for newly mounted volumes" || true
  write_macos_default com.apple.frameworks.diskimages auto-open-rw-root -bool true "Opening new Finder windows for newly mounted volumes" || true
  write_macos_default com.apple.finder OpenWindowForNewRemovableDisk -bool true "Opening new Finder windows for newly mounted volumes" || true
  write_macos_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true "Expanding save panels by default" || true
  write_macos_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true "Expanding save panels by default" || true
  write_macos_default NSGlobalDomain PMPrintingExpandedStateForPrint -bool true "Expanding print panels by default" || true
  write_macos_default NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true "Expanding print panels by default" || true
  write_macos_default com.apple.CrashReporter DialogType -string none "Disabling the crash reporter dialog" || true
  write_macos_default com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false "Disabling Apple Intelligence" || true
  write_macos_default com.apple.dock mru-spaces -bool false "Disabling automatic space rearrangement" || true
  write_macos_default com.apple.dock expose-group-apps -bool true "Grouping Mission Control windows by application" || true

  # Finder
  write_macos_default NSGlobalDomain AppleShowAllExtensions -bool true "Showing all Finder filename extensions" || true
  write_macos_default com.apple.finder AppleShowAllFiles -bool true "Showing hidden files in Finder" || true
  write_macos_default com.apple.finder ShowPathbar -bool true "Showing Finder path bar" || true
  write_macos_default com.apple.finder ShowStatusBar -bool true "Showing Finder status bar" || true
  write_macos_default com.apple.finder _FXShowPosixPathInTitle -bool true "Showing full POSIX path in Finder window titles" || true
  write_macos_default com.apple.finder FXEnableExtensionChangeWarning -bool false "Disabling the file extension change warning" || true
  write_macos_default com.apple.finder _FXSortFoldersFirst -bool true "Sorting Finder folders first" || true
  write_macos_default com.apple.finder FXDefaultSearchScope -string SCcf "Setting Finder search scope to current folder" || true
  write_macos_default com.apple.finder FXRemoveOldTrashItems -bool true "Removing trash items after 30 days" || true
  write_macos_default com.apple.finder WarnOnEmptyTrash -bool false "Disabling the warning before emptying the Trash" || true
  write_macos_default com.apple.finder FXPreferredViewStyle -string Nlsv "Setting Finder preferred view style to Nlsv" || true

  # TextEdit
  write_macos_default com.apple.TextEdit RichText -int 0 "Use plain text mode for new TextEdit documents" || true
  write_macos_default com.apple.TextEdit PlainTextEncoding -int 4 "Open and save files as UTF-8 in TextEdit" || true
  write_macos_default com.apple.TextEdit PlainTextEncodingForWrite -int 4 "Open and save files as UTF-8 in TextEdit" || true

  # Activity Monitor
  write_macos_default com.apple.ActivityMonitor OpenMainWindow -bool true "Show the main window when launching Activity Monitor" || true
  write_macos_default com.apple.ActivityMonitor ShowCategory -int 0 "Show all processes in Activity Monitor" || true
  write_macos_default com.apple.ActivityMonitor SortColumn -string CPUUsage "Sort Activity Monitor results by CPU usage" || true
  write_macos_default com.apple.ActivityMonitor SortDirection -int 0 "Sort Activity Monitor results by CPU usage" || true

  # Default browser
  set_macos_default_browser
  apply_macos_power_settings
  apply_macos_startup_settings
  apply_macos_screenshot_settings
  apply_macos_safari_settings
  apply_macos_software_update_settings
  apply_macos_home_visibility_settings

  # Kill all affected apps
  if [ "$restart_dock" -eq 1 ]; then
    killall Dock >/dev/null 2>&1 || true
  fi

  if [ "$restart_finder" -eq 1 ]; then
    killall Finder >/dev/null 2>&1 || true
  fi

  log_warn "Some macOS defaults may require logging out or restarting to fully apply."
}
