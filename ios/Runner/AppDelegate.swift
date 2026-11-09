import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.applicationSupportsShakeToEdit = false // Disable shake to undo
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "CoupleSpaceMediaPicker"
    ) {
      CoupleSpaceMediaPicker.register(with: registrar)
    }
  }
}

private final class CoupleSpaceMediaPicker: NSObject, PHPickerViewControllerDelegate {
  private static let channelName = "hyper_piliplus/couple_space_media"
  private weak var viewController: UIViewController?
  private var pendingResult: FlutterResult?
  private var activePicker: PHPickerViewController?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = CoupleSpaceMediaPicker(viewController: registrar.viewController)
    channel.setMethodCallHandler(instance.handle)
    registrar.publish(instance)
  }

  private init(viewController: UIViewController?) {
    self.viewController = viewController
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickMedia" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "PICK_IN_PROGRESS",
          message: "已有照片选择器正在使用",
          details: nil
        )
      )
      return
    }
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "NO_VIEW_CONTROLLER",
          message: "无法打开系统照片选择器",
          details: nil
        )
      )
      return
    }

    let arguments = call.arguments as? [String: Any]
    let requestedLimit = arguments?["limit"] as? Int ?? 9
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = min(max(requestedLimit, 1), 9)
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    activePicker = picker
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      if results.isEmpty {
        self.finish([])
        return
      }
      self.export(results)
    }
  }

  private func export(_ results: [PHPickerResult]) {
    let group = DispatchGroup()
    let lock = NSLock()
    var exported = Array<[String: Any]?>(repeating: nil, count: results.count)
    var firstError: Error?

    for (index, pickerResult) in results.enumerated() {
      group.enter()
      export(pickerResult) { itemResult in
        lock.lock()
        defer {
          lock.unlock()
          group.leave()
        }
        switch itemResult {
        case .success(let item):
          exported[index] = item
        case .failure(let error):
          if firstError == nil { firstError = error }
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      if let firstError {
        self.removeExportedFiles(exported.compactMap { $0 })
        self.finish(
          FlutterError(
            code: "MEDIA_EXPORT_FAILED",
            message: "动态照片导出失败：\(firstError.localizedDescription)",
            details: nil
          )
        )
        return
      }
      self.finish(exported.compactMap { $0 })
    }
  }

  private func export(
    _ result: PHPickerResult,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let provider = result.itemProvider
    if provider.hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier) {
      provider.loadFileRepresentation(
        forTypeIdentifier: UTType.livePhoto.identifier
      ) { [weak self] url, error in
        guard let self else { return }
        completion(self.copyLivePhotoPackage(url: url, error: error))
      }
      return
    }

    let imageType = provider.registeredTypeIdentifiers.first {
      UTType($0)?.conforms(to: .image) == true
    } ?? UTType.image.identifier
    provider.loadFileRepresentation(forTypeIdentifier: imageType) {
      [weak self] url, error in
      guard let self else { return }
      completion(self.copyStillImage(url: url, error: error))
    }
  }

  private func copyLivePhotoPackage(
    url: URL?,
    error: Error?
  ) -> Result<[String: Any], Error> {
    if let error { return .failure(error) }
    guard let url else { return .failure(MediaPickerError.missingResource) }
    do {
      let resourceURLs = try containedFiles(url)
      guard let imageURL = resourceURLs.first(where: isImage),
            let videoURL = resourceURLs.first(where: isVideo)
      else {
        throw MediaPickerError.incompleteLivePhoto
      }
      let directory = try makeExportDirectory()
      let copiedImage = try copy(imageURL, into: directory, name: "cover")
      let copiedVideo = try copy(videoURL, into: directory, name: "motion")
      return .success(mediaInfo(imageURL: copiedImage, videoURL: copiedVideo))
    } catch {
      return .failure(error)
    }
  }

  private func copyStillImage(
    url: URL?,
    error: Error?
  ) -> Result<[String: Any], Error> {
    if let error { return .failure(error) }
    guard let url else { return .failure(MediaPickerError.missingResource) }
    do {
      let sourceURL = try containedFiles(url).first(where: isImage) ?? url
      let directory = try makeExportDirectory()
      let copiedImage = try copy(sourceURL, into: directory, name: "image")
      return .success(mediaInfo(imageURL: copiedImage, videoURL: nil))
    } catch {
      return .failure(error)
    }
  }

  private func containedFiles(_ url: URL) throws -> [URL] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      throw MediaPickerError.missingResource
    }
    guard isDirectory.boolValue else { return [url] }
    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      throw MediaPickerError.missingResource
    }
    return enumerator.compactMap { $0 as? URL }
  }

  private func makeExportDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("couple-space-media", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func copy(_ source: URL, into directory: URL, name: String) throws -> URL {
    let fileExtension = source.pathExtension.isEmpty ? "bin" : source.pathExtension
    let destination = directory
      .appendingPathComponent(name)
      .appendingPathExtension(fileExtension)
    try FileManager.default.copyItem(at: source, to: destination)
    return destination
  }

  private func mediaInfo(imageURL: URL, videoURL: URL?) -> [String: Any] {
    var item: [String: Any] = ["imagePath": imageURL.path]
    if let videoURL { item["videoPath"] = videoURL.path }
    if let dimensions = imageDimensions(imageURL) {
      item["width"] = dimensions.width
      item["height"] = dimensions.height
    }
    return item
  }

  private func imageDimensions(_ url: URL) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
    else {
      return nil
    }
    return (width.intValue, height.intValue)
  }

  private func isImage(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
    return type.conforms(to: .image)
  }

  private func isVideo(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
    return type.conforms(to: .movie)
  }

  private func removeExportedFiles(_ items: [[String: Any]]) {
    for item in items {
      for key in ["imagePath", "videoPath"] {
        guard let path = item[key] as? String else { continue }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
      }
    }
  }

  private func finish(_ value: Any) {
    let result = pendingResult
    pendingResult = nil
    activePicker = nil
    result?(value)
  }

  private func topViewController() -> UIViewController? {
    var controller = viewController
    if controller == nil {
      controller = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
    }
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

private enum MediaPickerError: LocalizedError {
  case missingResource
  case incompleteLivePhoto

  var errorDescription: String? {
    switch self {
    case .missingResource:
      return "系统没有返回可读取的照片文件"
    case .incompleteLivePhoto:
      return "Live Photo 缺少封面或配对视频"
    }
  }
}
