import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let priceManager = PriceManager.shared
    private var popover: NSPopover?
    private var moneroChan: MoneroChanCompanion?

    static let moneroChanKey = "MoneroChanEnabled"

    var moneroChanEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.moneroChanKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.moneroChanKey)
            applyMoneroChan()
            NotificationCenter.default.post(name: NSNotification.Name("MoneroChanChanged"), object: nil)
        }
    }

    private func applyMoneroChan() {
        if moneroChanEnabled {
            if moneroChan == nil, let dir = Bundle.main.resourceURL?.appendingPathComponent("MoneroChanFrames") {
                let chan = MoneroChanCompanion(framesDir: dir)
                chan.onTurnOff = { [weak self] in self?.moneroChanEnabled = false }
                moneroChan = chan
            }
            moneroChan?.start()
        } else {
            moneroChan?.stop()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("=== XMRMenuCalc launching ===")

        NSApp.setActivationPolicy(.accessory)
        NSLog("Set activation policy to .accessory")

        popover = NSPopover()
        // size the popover to exactly fit its content (no empty gaps)
        let fit = NSHostingController(rootView: CalculatorView(priceManager: priceManager)).view.fittingSize
        popover?.contentSize = NSSize(width: 300, height: ceil(fit.height))
        popover?.behavior = .transient
        popover?.contentViewController = CalculatorHostingController(
            rootView: CalculatorView(priceManager: priceManager)
        )
        NSLog("Created popover")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("Status item created")

        guard let button = statusItem?.button else {
            NSLog("ERROR: Could not create status bar button!")
            return
        }

        if let path = Bundle.main.path(forResource: "xmr_logo", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            NSLog("Logo set")
        } else {
            NSLog("Logo not found")
        }

        button.title = "XMR"
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "XMR Price Calculator"
        NSLog("Button configured: \(button.title), frame: \(button.frame)")

        priceManager.startUpdating()

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateStatusButton()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updateStatusButton()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusButton),
            name: NSNotification.Name("FiatChanged"),
            object: nil
        )

        applyMoneroChan()

        NSLog("=== XMRMenuCalc launch complete ===")
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else {
            NSLog("togglePopover: missing button or popover")
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            priceManager.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSLog("Popover shown: \(popover.isShown)")
        }
    }

    @objc private func updateStatusButton() {
        guard let button = statusItem?.button else {
            NSLog("updateStatusButton: button is nil!")
            return
        }

        let symbol = PriceManager.fiatSymbol(for: priceManager.selectedFiat)
        let price = priceManager.xmrPrices[priceManager.selectedFiat] ?? 0
        if price > 0 {
            let fmt = NumberFormatter()
            fmt.numberStyle = .decimal
            fmt.minimumFractionDigits = 2
            fmt.maximumFractionDigits = 2
            let priceStr = fmt.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
            button.title = "\(symbol)\(priceStr)"
        } else {
            button.title = "XMR"
        }

        NSLog("Status bar updated: \(button.title)")
    }
}

class CalculatorHostingController: NSViewController {
    init(rootView: CalculatorView) {
        super.init(nibName: nil, bundle: nil)
        let hosting = NSHostingController(rootView: rootView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.width, .height]
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let child = children.first {
            child.view.frame = view.bounds
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
