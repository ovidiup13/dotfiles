#!/usr/bin/env bash

set -euo pipefail

set_macos_default_browser() {
  local script_path

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

  log_info "Setting Firefox as the default browser"
  if ! swift "$script_path" org.mozilla.firefox; then
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
  log_info "Showing host info in the login window clock"
  sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
}

apply_macos_screenshot_settings() {
  log_info "Saving screenshots to ~/Documents/Screenshots"
  mkdir -p "$HOME/Documents/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Documents/Screenshots"
  log_info "Saving screenshots in PNG format"
  defaults write com.apple.screencapture type -string png
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

  log_info "Showing full URL in Safari smart search field"
  defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true >/dev/null 2>&1 || true
  log_info "Disabling Safari search query sharing and suggestions"
  defaults write com.apple.Safari UniversalSearchEnabled -bool false >/dev/null 2>&1 || true
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true >/dev/null 2>&1 || true
  log_info "Setting Safari home page to about:blank"
  defaults write com.apple.Safari HomePage -string about:blank >/dev/null 2>&1 || true
  log_info "Enabling Safari internal debug menu"
  defaults write com.apple.Safari IncludeInternalDebugMenu -bool true >/dev/null 2>&1 || true
  log_info "Enabling Safari Develop menu and Web Inspector"
  defaults write com.apple.Safari IncludeDevelopMenu -bool true >/dev/null 2>&1 || true
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true >/dev/null 2>&1 || true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true >/dev/null 2>&1 || true
  log_info "Disabling Safari AutoFill"
  defaults write com.apple.Safari AutoFillFromAddressBook -bool false >/dev/null 2>&1 || true
  defaults write com.apple.Safari AutoFillPasswords -bool false >/dev/null 2>&1 || true
  defaults write com.apple.Safari AutoFillCreditCardData -bool false >/dev/null 2>&1 || true
  defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false >/dev/null 2>&1 || true
  log_info "Disabling Safari Java support"
  defaults write com.apple.Safari WebKitJavaEnabled -bool false >/dev/null 2>&1 || true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false >/dev/null 2>&1 || true
  log_info "Enabling Safari Do Not Track and extension auto-updates"
  defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true >/dev/null 2>&1 || true
  defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true >/dev/null 2>&1 || true
}

apply_macos_software_update_settings() {
  log_info "Enabling automatic software update checks"
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  log_info "Checking for software updates daily"
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  log_info "Downloading new software updates in the background"
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
  log_info "Installing critical data files and security updates"
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
  log_info "Enabling App Store app auto-updates"
  defaults write com.apple.commerce AutoUpdate -bool true
  log_info "Preventing App Store updates from forcing reboots"
  defaults write com.apple.commerce AutoUpdateRestartRequired -bool false
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
  log_info "Enabling Dock auto-hide"
  defaults write com.apple.dock autohide -bool true
  log_info "Setting Dock minimize effect to scale"
  defaults write com.apple.dock mineffect -string scale
  log_info "Minimizing windows into their application icon"
  defaults write com.apple.dock minimize-to-application -bool true
  log_info "Enabling Scroll to Expose app"
  defaults write com.apple.dock scroll-to-open -bool true

  # Global
  log_info "Disabling double-space period substitution"
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  log_info "Disabling automatic capitalization"
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  log_info "Disabling smart dashes"
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  log_info "Disabling smart quotes"
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  log_info "Disabling auto-correct"
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  log_info "Avoiding .DS_Store files on network and USB volumes"
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
  log_info "Opening new Finder windows for newly mounted volumes"
  defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
  defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
  defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true
  log_info "Expanding save panels by default"
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
  log_info "Expanding print panels by default"
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  log_info "Disabling the crash reporter dialog"
  defaults write com.apple.CrashReporter DialogType -string none
  log_info "Disabling Apple Intelligence"
  defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
  log_info "Disabling automatic space rearrangement"
  defaults write com.apple.dock mru-spaces -bool false
  log_info "Grouping Mission Control windows by application"
  defaults write com.apple.dock expose-group-apps -bool true

  # Finder
  log_info "Showing all Finder filename extensions"
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  log_info "Showing hidden files in Finder"
  defaults write com.apple.finder AppleShowAllFiles -bool true
  log_info "Showing Finder path bar"
  defaults write com.apple.finder ShowPathbar -bool true
  log_info "Showing Finder status bar"
  defaults write com.apple.finder ShowStatusBar -bool true
  log_info "Showing full POSIX path in Finder window titles"
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  log_info "Disabling the file extension change warning"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  log_info "Sorting Finder folders first"
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  log_info "Setting Finder search scope to current folder"
  defaults write com.apple.finder FXDefaultSearchScope -string SCcf
  log_info "Removing trash items after 30 days"
  defaults write com.apple.finder FXRemoveOldTrashItems -bool true
  log_info "Disabling the warning before emptying the Trash"
  defaults write com.apple.finder WarnOnEmptyTrash -bool false
  log_info "Setting Finder preferred view style to Nlsv"
  defaults write com.apple.finder "FXPreferredViewStyle" -string "Nlsv"

  # TextEdit
  log_info "Use plain text mode for new TextEdit documents"
  defaults write com.apple.TextEdit RichText -int 0
  log_info "Open and save files as UTF-8 in TextEdit"
  defaults write com.apple.TextEdit PlainTextEncoding -int 4
  log_info "Open and save files as UTF-8 in TextEdit"
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

  # Activity Monitor
  log_info "Show the main window when launching Activity Monitor"
  defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
  log_info "Show all processes in Activity Monitor"
  defaults write com.apple.ActivityMonitor ShowCategory -int 0
  log_info "Sort Activity Monitor results by CPU usage"
  defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
  defaults write com.apple.ActivityMonitor SortDirection -int 0

  # Default browser
  set_macos_default_browser
  apply_macos_power_settings
  apply_macos_startup_settings
  apply_macos_screenshot_settings
  apply_macos_safari_settings
  apply_macos_software_update_settings
  apply_macos_home_visibility_settings

  # Kill all affected apps
  killall Dock >/dev/null 2>&1 || true
  killall Finder >/dev/null 2>&1 || true
  log_warn "Some macOS defaults may require logging out or restarting to fully apply."
}
