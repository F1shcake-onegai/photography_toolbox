import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var fileIntentChannel: FlutterMethodChannel?
    var eventSink: FlutterEventSink?
    var initialFilePath: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController

        fileIntentChannel = FlutterMethodChannel(
            name: "photography_toolbox/file_intent",
            binaryMessenger: controller.binaryMessenger
        )
        fileIntentChannel?.setMethodCallHandler { [weak self] call, result in
            if call.method == "getInitialFile" {
                result(self?.initialFilePath)
                self?.initialFilePath = nil
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        let eventChannel = FlutterEventChannel(
            name: "photography_toolbox/file_intent/events",
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(FileIntentStreamHandler(delegate: self))

        // Handle cold start URL from launchOptions
        if let url = launchOptions?[.url] as? URL {
            handleIncomingFile(url: url)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if handleIncomingFile(url: url) {
            return true
        }
        return super.application(app, open: url, options: options)
    }

    @discardableResult
    func handleIncomingFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ["ptrecipe", "ptroll", "json", "zip"].contains(ext) else { return false }

        // Copy to a temp location accessible by Dart
        let tempDir = NSTemporaryDirectory()
        let tempPath = "\(tempDir)intent_import_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)"
        let tempURL = URL(fileURLWithPath: tempPath)

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if FileManager.default.fileExists(atPath: tempPath) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            return false
        }

        if let sink = eventSink {
            sink(tempPath)
        } else {
            initialFilePath = tempPath
        }
        return true
    }
}

class FileIntentStreamHandler: NSObject, FlutterStreamHandler {
    weak var delegate: AppDelegate?

    init(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        delegate?.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        delegate?.eventSink = nil
        return nil
    }
}
