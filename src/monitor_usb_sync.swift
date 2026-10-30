import Foundation
import IOKit
import IOKit.usb

// Target: Lenovo ThinkVision P32p-20 Internal Realtek USB Hub
let targetVendor = 0x0bda
let targetProduct = 0x5411

// Monitor Display Inputs
let macInput = 17       // HDMI (Mac Mini)
let windowsInput = 16   // USB-C (Windows Laptop)
let m1ddcPath = "/opt/homebrew/bin/m1ddc"

func logMessage(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = formatter.string(from: Date())
    print("[\(timestamp)] \(message)")
    fflush(stdout)
}

func switchDisplay(to input: Int, reason: String) {
    logMessage("Trigger: \(reason) -> Switching display to input \(input)...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: m1ddcPath)
    process.arguments = ["set", "input", String(input)]
    
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            logMessage("Successfully switched display to input \(input).")
        } else {
            logMessage("Warning: m1ddc exited with code \(process.terminationStatus)")
        }
    } catch {
        logMessage("Error executing \(m1ddcPath): \(error.localizedDescription)")
    }
}

func matchesTarget(device: io_service_t) -> Bool {
    guard let vendorRef = IORegistryEntryCreateCFProperty(device, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
          let productRef = IORegistryEntryCreateCFProperty(device, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int else {
        return false
    }
    return vendorRef == targetVendor && productRef == targetProduct
}

var initialScanComplete = false
var isCurrentlyAttached = false
var debounceWorkItem: DispatchWorkItem?

func handleStateChange(attached: Bool) {
    if !initialScanComplete {
        isCurrentlyAttached = attached
        logMessage("Initial state: Monitor USB Hub is \(attached ? "CONNECTED (Mac active)" : "DISCONNECTED (Windows active)")")
        return
    }
    
    guard attached != isCurrentlyAttached else { return }
    isCurrentlyAttached = attached
    
    debounceWorkItem?.cancel()
    let workItem = DispatchWorkItem {
        if attached {
            switchDisplay(to: macInput, reason: "Monitor USB switched back to Mac")
        } else {
            switchDisplay(to: windowsInput, reason: "Monitor USB switched to Windows laptop")
        }
    }
    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
}

let notifyPort = IONotificationPortCreate(kIOMainPortDefault)
let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeRetainedValue()
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

let matchedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
    var found = false
    while case let device = IOIteratorNext(iterator), device != 0 {
        if matchesTarget(device: device) {
            found = true
        }
        IOObjectRelease(device)
    }
    if found {
        handleStateChange(attached: true)
    }
}

let terminatedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
    var found = false
    while case let device = IOIteratorNext(iterator), device != 0 {
        if matchesTarget(device: device) {
            found = true
        }
        IOObjectRelease(device)
    }
    if found {
        handleStateChange(attached: false)
    }
}

var matchIterator: io_iterator_t = 0
var termIterator: io_iterator_t = 0

let matchDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
matchDict["idVendor"] = targetVendor
matchDict["idProduct"] = targetProduct

IOServiceAddMatchingNotification(notifyPort, kIOMatchedNotification, matchDict, matchedCallback, nil, &matchIterator)
matchedCallback(nil, matchIterator)

let termDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
termDict["idVendor"] = targetVendor
termDict["idProduct"] = targetProduct

IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, termDict, terminatedCallback, nil, &termIterator)
terminatedCallback(nil, termIterator)

// Mark initial scan complete after seeding current hardware state
initialScanComplete = true
logMessage("Monitor USB sync service initialized and actively watching for USB KVM events...")

RunLoop.main.run()
