import CoreServices
import Foundation

enum BrowserSetterError: Error {
  case missingBundleId
  case appNotInstalled(String)
  case failed(String, OSStatus)
}

extension BrowserSetterError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .missingBundleId:
      return "missing browser bundle identifier argument"
    case let .appNotInstalled(bundleId):
      return "application is not installed for bundle id: \(bundleId)"
    case let .failed(target, status):
      return "failed to set default handler for \(target) (OSStatus \(status))"
    }
  }
}

func setDefaultHandler(for scheme: String, bundleId: String) throws {
  let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleId as CFString)
  if status != noErr {
    throw BrowserSetterError.failed(scheme, status)
  }
}

func defaultHandler(for scheme: String) -> String? {
  LSCopyDefaultHandlerForURLScheme(scheme as CFString)?.takeRetainedValue() as String?
}

func isDefaultBrowser(_ bundleId: String) -> Bool {
  defaultHandler(for: "http") == bundleId && defaultHandler(for: "https") == bundleId
}

do {
  let args = CommandLine.arguments

  if args.count == 3, args[1] == "--is-default" {
    exit(isDefaultBrowser(args[2]) ? 0 : 1)
  }

  guard args.count == 2 else {
    throw BrowserSetterError.missingBundleId
  }

  let bundleId = args[1]
  let appUrls = LSCopyApplicationURLsForBundleIdentifier(bundleId as CFString, nil)?.takeRetainedValue() as? [URL]

  guard let urls = appUrls, !urls.isEmpty else {
    throw BrowserSetterError.appNotInstalled(bundleId)
  }

  if isDefaultBrowser(bundleId) {
    exit(0)
  }

  try setDefaultHandler(for: "http", bundleId: bundleId)
  try setDefaultHandler(for: "https", bundleId: bundleId)
} catch {
  FileHandle.standardError.write(Data("set_default_browser: \(error.localizedDescription)\n".utf8))
  exit(1)
}
