import UIKit
import Flutter
import ActivityKit
import AVFoundation
import CoreLocation
import Metal

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
        name: "ios-delegate-channel",
        binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "isReduceMotionEnabled":
            result(UIAccessibility.isReduceMotionEnabled)
        case "liveActivityStart":
            self?.handleLiveActivityStart(call: call, result: result)
        case "liveActivityUpdate":
            self?.handleLiveActivityUpdate(call: call, result: result)
        case "liveActivityEnd":
            self?.handleLiveActivityEnd(call: call, result: result)
        case "liveActivityCancel":
            self?.handleLiveActivityCancel(call: call, result: result)
        case "getSystemStats":
            self?.handleGetSystemStats(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - Live Activity Handlers

  private func handleLiveActivityStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    BackgroundKeeper.shared.start()
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let transferId = args["transferId"] as? String,
          let direction = args["direction"] as? String,
          let fileName = args["fileName"] as? String,
          let totalBytes = args["totalBytes"] as? Int64 else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityStart", details: nil))
      return
    }
    LiveActivityManager.shared.start(
      transferId: transferId,
      direction: direction,
      fileName: fileName,
      totalBytes: totalBytes
    )
    result(nil)
  }

  private func handleLiveActivityUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let progress = args["progress"] as? Double,
          let transferredBytes = args["transferredBytes"] as? Int64,
          let totalBytes = args["totalBytes"] as? Int64,
          let speed = args["speed"] as? Double,
          let remainingSeconds = args["remainingSeconds"] as? TimeInterval,
          let status = args["status"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityUpdate", details: nil))
      return
    }
    LiveActivityManager.shared.update(
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
      speed: speed,
      remainingSeconds: remainingSeconds,
      status: status
    )
    result(nil)
  }

  private func handleLiveActivityEnd(call: FlutterMethodCall, result: @escaping FlutterResult) {
    BackgroundKeeper.shared.stop()
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let status = args["status"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments for liveActivityEnd", details: nil))
      return
    }
    LiveActivityManager.shared.end(status: status)
    result(nil)
  }

  private func handleLiveActivityCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
    BackgroundKeeper.shared.stop()
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    LiveActivityManager.shared.end()
    result(nil)
  }

  // MARK: - System Stats Monitoring for Dashboard

  private var prevCPUTicks: host_cpu_load_info?

  private func getSystemCPUUsage() -> Double {
      var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
      var cpuLoadInfo = host_cpu_load_info()
      let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
              host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
          }
      }
      
      guard result == KERN_SUCCESS else { return 0.0 }
      
      guard let prev = prevCPUTicks else {
          prevCPUTicks = cpuLoadInfo
          return 0.0
      }
      
      let userDiff = Double(cpuLoadInfo.cpu_ticks.0 - prev.cpu_ticks.0)
      let systemDiff = Double(cpuLoadInfo.cpu_ticks.1 - prev.cpu_ticks.1)
      let idleDiff = Double(cpuLoadInfo.cpu_ticks.2 - prev.cpu_ticks.2)
      let niceDiff = Double(cpuLoadInfo.cpu_ticks.3 - prev.cpu_ticks.3)
      
      prevCPUTicks = cpuLoadInfo
      
      let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
      guard totalDiff > 0 else { return 0.0 }
      
      let activeDiff = userDiff + systemDiff + niceDiff
      return (activeDiff / totalDiff) * 100.0
  }

  private func handleGetSystemStats(result: @escaping FlutterResult) {
      var stats = [String: Any]()
      
      // 1. CPU Usage
      stats["cpuUsage"] = getSystemCPUUsage()
      
      // 2. RAM Info
      let physicalMemory = ProcessInfo.processInfo.physicalMemory
      stats["ramTotal"] = Double(physicalMemory)
      
      var vmStats = vm_statistics_data_t()
      var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
      let hostPort = mach_host_self()
      let status = withUnsafeMutablePointer(to: &vmStats) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
              host_statistics(hostPort, HOST_VM_INFO, $0, &hostSize)
          }
      }
      
      if status == KERN_SUCCESS {
          let pageSize = vm_kernel_page_size
          let free = Double(vmStats.free_count) * Double(pageSize)
          let active = Double(vmStats.active_count) * Double(pageSize)
          let inactive = Double(vmStats.inactive_count) * Double(pageSize)
          let wire = Double(vmStats.wire_count) * Double(pageSize)
          let used = active + inactive + wire
          
          stats["ramUsed"] = used
          stats["ramFree"] = free
      } else {
          stats["ramUsed"] = 0.0
          stats["ramFree"] = 0.0
      }
      
      // 3. Storage Info
      let fileManager = FileManager.default
      if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
          do {
              let values = try fileManager.attributesOfFileSystem(forPath: path)
              let totalStorage = values[.systemSize] as? Int64 ?? 0
              let freeStorage = values[.systemFreeSize] as? Int64 ?? 0
              let usedStorage = totalStorage - freeStorage
              
              stats["storageTotal"] = totalStorage
              stats["storageUsed"] = usedStorage
              stats["storageFree"] = freeStorage
          } catch {
              stats["storageTotal"] = Int64(0)
              stats["storageUsed"] = Int64(0)
              stats["storageFree"] = Int64(0)
          }
      }
      
      // 4. GPU Info
      #if canImport(Metal)
      if let device = MTLCreateSystemDefaultDevice() {
          stats["gpuName"] = device.name
      } else {
          stats["gpuName"] = "Apple GPU (Metal)"
      }
      #else
      stats["gpuName"] = "Apple GPU"
      #endif
      
      // 5. Device and OS version
      stats["deviceName"] = UIDevice.current.name
      stats["systemVersion"] = "iOS " + UIDevice.current.systemVersion
      
      result(stats)
  }
}


// MARK: - Background Keeper Service (keeps app alive via silent audio / location)

class BackgroundKeeper: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundKeeper()
    
    private var audioPlayer: AVAudioPlayer?
    private var locationManager: CLLocationManager?
    private var isRunning = false
    
    private override init() {
        super.init()
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        setupAudioSession()
        playSilentAudio()
        startLocationUpdates()
    }
    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set AVAudioSession category: \(error)")
        }
    }
    
    private func playSilentAudio() {
        let silentWavData = createSilentWav()
        do {
            audioPlayer = try AVAudioPlayer(data: silentWavData)
            audioPlayer?.numberOfLoops = -1 // Loop infinitely
            audioPlayer?.volume = 0.01 // Very quiet (silent)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to initialize AVAudioPlayer: \(error)")
        }
    }
    
    private func startLocationUpdates() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager?.distanceFilter = 99999 // Large distance filter to save battery
        
        locationManager?.requestWhenInUseAuthorization()
        
        if #available(iOS 9.0, *) {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Dummy callback to keep app alive
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error)")
    }
    
    // Generates 1 second of silent WAV audio data programmatically
    private func createSilentWav() -> Data {
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let numSamples: Int32 = 8000 // 1 second
        
        let subchunk2Size = numSamples * Int32(numChannels) * Int32(bitsPerSample / 8)
        let chunkSize = 36 + subchunk2Size
        
        var header = Data()
        
        // RIFF header
        header.append("RIFF".data(using: .utf8)!)
        header.append(Swift.withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .utf8)!)
        
        // "fmt " subchunk
        header.append("fmt ".data(using: .utf8)!)
        header.append(Swift.withUnsafeBytes(of: Int32(16).littleEndian) { Data($0) })
        header.append(Swift.withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })
        header.append(Swift.withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        header.append(Swift.withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        
        header.append(Swift.withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(Swift.withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(Swift.withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // "data" subchunk
        header.append("data".data(using: .utf8)!)
        header.append(Swift.withUnsafeBytes(of: subchunk2Size.littleEndian) { Data($0) })
        
        // Data bytes (zeros for silence)
        header.append(Data(repeating: 0, count: Int(subchunk2Size)))
        
        return header
    }
}

