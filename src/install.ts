#!/usr/bin/env bun

import { spawnSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, readlinkSync, renameSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir, arch as osArch, platform as osPlatform } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { fileURLToPath } from "node:url";

type Command = "install" | "check" | "doctor" | "link" | "secrets" | "skills" | "macos-defaults" | "help";
type Platform = "auto" | "macos" | "ubuntu" | "linux" | "windows" | "unsupported";
type Profile = "personal" | "worker";

interface Options {
  command: Command;
  profile: Profile;
  platformOverride: Platform;
  onePasswordEnvironment: string;
  dryRun: boolean;
}

interface DetectedPlatform {
  platform: Platform;
  distro: string;
  arch: string;
}

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const home = homedir();

function logStep(message: string): void {
  console.log(`\n==> ${message}`);
}

function logInfo(message: string): void {
  console.log(`  - ${message}`);
}

function logWarn(message: string): void {
  console.log(`  ! ${message}`);
}

function logSuccess(message: string): void {
  console.log(`  + ${message}`);
}

function fail(message: string): never {
  console.error(`  x ${message}`);
  process.exit(1);
}

function usage(): string {
  return `Usage: ./install [command] [options]

Commands:
  install, apply      Run the full install or re-apply path (default)
  check, doctor      Show detected platform, profile, and planned steps
  link               Re-link managed files from home/ into $HOME
  secrets            Sync 1Password Environment secrets only
  skills             Sync macOS agent skills only
  macos-defaults     Apply macOS defaults only
  help               Show this help

Options:
  --profile <name>              personal|worker (env: DOTFILES_PROFILE)
  --platform <name>             auto|macos|ubuntu|linux|windows
  --1password-environment <id>  Override DOTFILES_1PASSWORD_ENVIRONMENT
  --dry-run                    Print planned actions without applying them
  --help                       Show this help

`;
}

function isTruthy(value: string | undefined): boolean {
  if (!value) {
    return false;
  }

  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

function readOption(args: string[], index: number, flag: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    fail(`Missing value for ${flag}.`);
  }
  return value;
}

function normalizeCommand(command: string): Command {
  switch (command) {
    case "install":
    case "apply":
      return "install";
    case "check":
      return "check";
    case "doctor":
      return "doctor";
    case "link":
      return "link";
    case "secrets":
      return "secrets";
    case "skills":
      return "skills";
    case "macos-defaults":
      return "macos-defaults";
    case "help":
      return "help";
    default:
      fail(`Unknown install command: ${command}`);
  }
}

function normalizeProfile(rawProfile: string | undefined): Profile {
  const profile = rawProfile || "personal";

  switch (profile) {
    case "personal":
      return "personal";
    case "worker":
      return "worker";
    default:
      fail(`Invalid profile: ${profile}. Expected personal or worker.`);
  }
}

function normalizePlatform(rawPlatform: string | undefined): Platform {
  const platform = rawPlatform || "auto";

  switch (platform) {
    case "auto":
    case "macos":
    case "ubuntu":
    case "linux":
    case "windows":
      return platform;
    default:
      fail(`Invalid platform: ${platform}. Expected auto, macos, ubuntu, linux, or windows.`);
  }
}

function parseArgs(args: string[]): Options {
  let command: Command = "install";
  let commandSet = false;
  let rawProfile = process.env.DOTFILES_PROFILE;
  let rawPlatform = process.env.DOTFILES_PLATFORM || "auto";
  let onePasswordEnvironment = process.env.DOTFILES_1PASSWORD_ENVIRONMENT || "";
  let dryRun = isTruthy(process.env.DOTFILES_DRY_RUN);

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    switch (arg) {
      case "-h":
      case "--help":
        command = "help";
        commandSet = true;
        break;
      case "--dry-run":
        dryRun = true;
        break;
      case "--profile":
        rawProfile = readOption(args, index, arg);
        index += 1;
        break;
      case "--platform":
        rawPlatform = readOption(args, index, arg);
        index += 1;
        break;
      case "--1password-environment":
        onePasswordEnvironment = readOption(args, index, arg);
        index += 1;
        break;
      default:
        if (arg.startsWith("--")) {
          fail(`Unknown install option: ${arg}`);
        }
        if (commandSet) {
          fail(`Unexpected argument: ${arg}`);
        }
        command = normalizeCommand(arg);
        commandSet = true;
        break;
    }
  }

  const normalizedProfile = normalizeProfile(rawProfile);

  return {
    command,
    profile: normalizedProfile,
    platformOverride: normalizePlatform(rawPlatform),
    onePasswordEnvironment,
    dryRun,
  };
}

function detectPlatform(platformOverride: Platform): DetectedPlatform {
  const arch = osArch();
  if (platformOverride !== "auto") {
    return { platform: platformOverride, distro: platformOverride, arch };
  }

  const platform = osPlatform();
  if (platform === "darwin") {
    return { platform: "macos", distro: "macos", arch };
  }

  if (platform === "win32") {
    return { platform: "windows", distro: "windows", arch };
  }

  if (platform === "linux") {
    const osReleasePath = "/etc/os-release";
    const osRelease = existsSync(osReleasePath) ? readFileSync(osReleasePath, "utf8") : "";
    if (/^(ID|ID_LIKE)=.*(ubuntu|debian)/m.test(osRelease)) {
      return { platform: "ubuntu", distro: readDistroId(osRelease), arch };
    }
    return { platform: "linux", distro: readDistroId(osRelease) || "linux", arch };
  }

  return { platform: "unsupported", distro: platform, arch };
}

function readDistroId(osRelease: string): string {
  const match = osRelease.match(/^ID=(.*)$/m);
  if (!match) {
    return "";
  }
  return match[1].replace(/^"|"$/g, "");
}

function shellScript(path: string): string {
  return join(repoRoot, path);
}

function runCommand(label: string, command: string, args: string[], options: Options): void {
  if (options.dryRun) {
    logInfo(`[dry-run] ${label}: ${[command, ...args].join(" ")}`);
    return;
  }

  logStep(label);
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env: {
      ...process.env,
      DOTFILES_1PASSWORD_ENVIRONMENT: options.onePasswordEnvironment || process.env.DOTFILES_1PASSWORD_ENVIRONMENT || "",
    },
    stdio: "inherit",
  });

  if (result.error) {
    fail(result.error.message);
  }

  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

function planLines(options: Options, detected: DetectedPlatform): string[] {
  const lines = [
    `repo: ${repoRoot}`,
    `platform: ${detected.platform}`,
    `distro: ${detected.distro}`,
    `arch: ${detected.arch}`,
    `profile: ${options.profile}`,
    `command: ${options.command}`,
    `dry-run: ${options.dryRun ? "yes" : "no"}`,
  ];

  return lines;
}

function printCheck(options: Options, detected: DetectedPlatform): void {
  logStep("Dotfiles installer plan");
  for (const line of planLines(options, detected)) {
    logInfo(line);
  }

  logStep("Planned steps");
  for (const step of plannedSteps(options, detected)) {
    logInfo(step);
  }
}

function plannedSteps(options: Options, detected: DetectedPlatform): string[] {
  switch (options.command) {
    case "help":
      return ["Print usage."];
    case "check":
    case "doctor":
      return ["Inspect platform/profile and exit without changes."];
    case "secrets":
      return ["Run scripts/install/secrets.sh through the secrets provider."];
    case "link":
      return ["Link managed files from home/ into $HOME."];
    case "skills":
      return ["Run .macos --post-link for the selected macOS profile."];
    case "macos-defaults":
      return ["Run .macos --defaults for the personal macOS profile."];
    case "install":
      if (detected.platform === "macos") {
        return [
          `Run .macos full --profile ${options.profile}.`,
          "Link managed files from home/ into $HOME.",
          "Sync 1Password Environment secrets.",
          "Configure Git identity.",
          `Run .macos --post-link --profile ${options.profile}.`,
        ];
      }
      if (detected.platform === "ubuntu") {
        return [
          "Run .ubuntu.",
          "Link managed files from home/ into $HOME.",
          "Sync 1Password Environment secrets.",
          "Configure Git identity.",
        ];
      }
      return ["Unsupported platform; no install plan is available yet."];
  }
}

function assertPlatform(detected: DetectedPlatform, allowed: Platform[], message: string): void {
  if (!allowed.includes(detected.platform)) {
    fail(message);
  }
}

function runSecrets(options: Options): void {
  const args = ["-c", `. "${shellScript("scripts/lib/common.sh")}"; . "${shellScript("scripts/install/secrets.sh")}"; sync_1password_secrets "$1"`, "sync-secrets", options.onePasswordEnvironment];
  runCommand("Syncing 1Password Environment secrets", "bash", args, options);
  if (!options.dryRun) {
    logSuccess("Secrets sync complete");
  }
}

function runMacosSkills(options: Options, detected: DetectedPlatform): void {
  assertPlatform(detected, ["macos"], "Skills sync is currently supported only on macOS.");
  runCommand("Syncing macOS agent skills", "bash", [shellScript(".macos"), "--post-link", "--profile", options.profile], options);
  if (!options.dryRun) {
    logSuccess("Skills sync complete");
  }
}

function runMacosDefaults(options: Options, detected: DetectedPlatform): void {
  assertPlatform(detected, ["macos"], "macOS defaults sync is currently supported only on macOS.");
  if (options.profile === "worker") {
    fail("macOS defaults only support the personal macOS profile.");
  }
  runCommand("Applying macOS defaults", "bash", [shellScript(".macos"), "--defaults", "--profile", "personal"], options);
  if (!options.dryRun) {
    logSuccess("macOS defaults applied");
  }
}

function runPlatformInstall(options: Options, detected: DetectedPlatform): void {
  if (detected.platform === "macos") {
    runCommand("Running macOS setup", "bash", [shellScript(".macos"), "full", "--profile", options.profile], options);
    return;
  }

  if (detected.platform === "ubuntu") {
    runCommand("Running Ubuntu setup", "bash", [shellScript(".ubuntu")], options);
    return;
  }

  if (detected.platform === "windows") {
    fail("Windows is detected but no Windows install provider exists yet.");
  }

  fail("Unsupported platform. This installer currently supports macOS and Ubuntu-style systems.");
}

function linkHomeTree(options: Options): void {
  const sourceRoot = join(repoRoot, "home");
  if (!existsSync(sourceRoot)) {
    fail(`Managed home directory not found: ${sourceRoot}`);
  }

  const backupRoot = join(home, ".dotfiles-backups", timestamp());

  logStep(`Linking managed dotfiles into ${home}`);
  for (const source of listFiles(sourceRoot)) {
    const rel = relative(sourceRoot, source);
    const target = join(home, rel);
    const targetDir = dirname(target);

    if (options.dryRun) {
      logInfo(`[dry-run] link ${target} -> ${source}`);
      continue;
    }

    mkdirSync(targetDir, { recursive: true });

    if (existsSync(target) || isSymlink(target)) {
      if (isSymlink(target) && readlinkSync(target) === source) {
        logInfo(`Linked ${target}`);
        continue;
      }

      const backupTarget = join(backupRoot, rel);
      mkdirSync(dirname(backupTarget), { recursive: true });
      renameSync(target, backupTarget);
      logWarn(`Backed up existing ${target} to ${backupTarget}`);
    }

    symlinkSync(source, target);
    logSuccess(`Linked ${target}`);
  }
}

function listFiles(root: string): string[] {
  const results: string[] = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const entryPath = join(root, entry.name);
    if (entry.isDirectory()) {
      results.push(...listFiles(entryPath));
    } else if (entry.isFile() || entry.isSymbolicLink()) {
      results.push(entryPath);
    }
  }
  return results;
}

function isSymlink(path: string): boolean {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch (error) {
    return false;
  }
}

function timestamp(): string {
  const now = new Date();
  const pad = (value: number) => value.toString().padStart(2, "0");
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

function readExistingIdentity(key: "user.name" | "user.email"): string {
  const identityFile = join(home, ".gitconfig.local");
  if (!existsSync(identityFile)) {
    return "";
  }

  const result = spawnSync("git", ["config", "--file", identityFile, key], { encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : "";
}

function readGlobalIdentity(key: "user.name" | "user.email"): string {
  const result = spawnSync("git", ["config", "--global", key], { encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : "";
}

async function configureGitIdentity(options: Options): Promise<void> {
  const identityFile = join(home, ".gitconfig.local");
  const envName = process.env.DOTFILES_GIT_NAME || "";
  const envEmail = process.env.DOTFILES_GIT_EMAIL || "";
  let gitName = envName || readGlobalIdentity("user.name");
  let gitEmail = envEmail || readGlobalIdentity("user.email");

  if (!envName && !envEmail) {
    const existingName = readExistingIdentity("user.name");
    const existingEmail = readExistingIdentity("user.email");
    if (existingName && existingEmail) {
      logInfo(`Git identity already configured in ${identityFile}`);
      return;
    }
  }

  if (options.dryRun) {
    if (gitName && gitEmail) {
      logInfo(`[dry-run] write Git identity to ${identityFile}`);
    } else {
      logInfo("[dry-run] skip Git identity prompt");
    }
    return;
  }

  if ((!gitName || !gitEmail) && process.stdin.isTTY && process.stdout.isTTY) {
    logStep("Configuring Git identity");
    const readline = createInterface({ input: process.stdin, output: process.stdout });
    try {
      const namePrompt = gitName ? `Git user.name [${gitName}]: ` : "Git user.name: ";
      const emailPrompt = gitEmail ? `Git user.email [${gitEmail}]: ` : "Git user.email: ";
      gitName = (await readline.question(namePrompt)) || gitName;
      gitEmail = (await readline.question(emailPrompt)) || gitEmail;
    } finally {
      readline.close();
    }
  }

  if (!gitName || !gitEmail) {
    logWarn("Skipping Git identity setup. Set DOTFILES_GIT_NAME and DOTFILES_GIT_EMAIL or configure git globally.");
    return;
  }

  writeFileSync(identityFile, `[user]\n\tname = ${gitName}\n\temail = ${gitEmail}\n`);
  logSuccess(`Wrote Git identity to ${identityFile}`);
}

async function runInstall(options: Options, detected: DetectedPlatform): Promise<void> {
  runPlatformInstall(options, detected);
  linkHomeTree(options);
  runSecrets(options);
  await configureGitIdentity(options);

  if (detected.platform === "macos") {
    runMacosSkills(options, detected);
  }

  if (!options.dryRun) {
    logSuccess("Install complete");
    logInfo("Open a new shell session to pick up all changes.");
  }
}

function assertNotRoot(): void {
  if (process.getuid && process.getuid() === 0) {
    fail("Run this installer as your normal user, not as root.");
  }
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const detected = detectPlatform(options.platformOverride);

  if (options.command === "help") {
    process.stdout.write(usage());
    return;
  }

  if (options.command === "check" || options.command === "doctor") {
    printCheck(options, detected);
    return;
  }

  assertNotRoot();

  switch (options.command) {
    case "install":
      await runInstall(options, detected);
      break;
    case "link":
      linkHomeTree(options);
      break;
    case "secrets":
      runSecrets(options);
      break;
    case "skills":
      runMacosSkills(options, detected);
      break;
    case "macos-defaults":
      runMacosDefaults(options, detected);
      break;
    case "help":
    case "check":
    case "doctor":
      break;
  }
}

main().catch((error: unknown) => {
  fail(error instanceof Error ? error.message : String(error));
});
