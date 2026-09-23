import SwiftUI
import Cocoa

enum InputField: Int {
    case xmr, fiat, btc
}

struct CalculatorView: View {
    @ObservedObject var priceManager: PriceManager
    @State private var fiatValue: String = ""
    @State private var xmrValue: String = ""
    @State private var btcValue: String = ""
    @State private var activeField: InputField?

    private var fiatSymbol: String {
        PriceManager.fiatSymbol(for: priceManager.selectedFiat)
    }

    private var btcPriceText: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        let p = priceManager.btcPrices[priceManager.selectedFiat] ?? 0
        return fmt.string(from: NSNumber(value: p))
            ?? String(format: "%.2f", p)
    }

    private var xmrBtcPriceText: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 6
        fmt.maximumFractionDigits = 8
        return fmt.string(from: NSNumber(value: priceManager.xmrBtcPrice))
            ?? String(format: "%.8f", priceManager.xmrBtcPrice)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header with XMR logo and title (centered)
            HStack(spacing: 10) {
                Spacer()
                if let logo = NSImage(named: "xmr_logo") ?? loadLogoFallback() {
                    Image(nsImage: logo)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text("XMR Calculator")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .frame(height: 32)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // Three rows: label + field, each row aligned independently
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("XMR")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 48, alignment: .leading)

                    NumberTextField(
                        value: $xmrValue,
                        placeholder: "0." + String(repeating: "0", count: 6)
                    ) { text in
                        onXmrChanged(text)
                    }
                }
                .frame(height: 22)

                HStack(spacing: 8) {
                    FiatDropdown(priceManager: priceManager) {
                        activeField = .fiat
                        onFiatChanged(fiatValue)
                    }
                    .frame(width: 48)

                    NumberTextField(
                        value: $fiatValue,
                        placeholder: fiatSymbol + "0." + String(repeating: "0", count: 2)
                    ) { text in
                        onFiatChanged(text)
                    }
                }
                .frame(height: 22)

                HStack(spacing: 8) {
                    Text("BTC")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 48, alignment: .leading)

                    NumberTextField(
                        value: $btcValue,
                        placeholder: "0." + String(repeating: "0", count: 8)
                    ) { text in
                        onBtcChanged(text)
                    }
                }
                .frame(height: 22)
            }
            .padding(.horizontal, 12)

            Divider()
                .padding(.horizontal, 12)

            // Settings row: Monerochan companion on/off
            MoneroChanToggle()
                .padding(.horizontal, 12)

            // Version + manual update check (only contacts GitHub when clicked)
            HStack {
                Text("Version \(Updater.shared.currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Check for Updates") { Updater.shared.checkForUpdates() }
                    .font(.caption)
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 4)

            // Footer: prices left, quit button right
            HStack {
                if (priceManager.btcPrices[priceManager.selectedFiat] ?? 0) > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1 BTC = \(fiatSymbol)\(btcPriceText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("1 XMR = \(xmrBtcPriceText) BTC")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .frame(width: 300, height: 286)
    }

    // MARK: - Formatting

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = decimals
        fmt.maximumFractionDigits = decimals
        return fmt.string(from: NSNumber(value: value))
            ?? String(format: "%.*f", decimals, value)
    }

    private func parseNumber(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: "")
        return Double(clean)
    }

    // MARK: - Conversion handlers

    private func onXmrChanged(_ text: String) {
        activeField = .xmr
        guard let num = parseNumber(text), num >= 0 else { return }
        fiatValue = formatNumber(priceManager.xmrToFiat(num), decimals: 2)
        btcValue = formatNumber(priceManager.xmrToBtc(num), decimals: 8)
        xmrValue = formatNumber(num, decimals: 6)
    }

    private func onFiatChanged(_ text: String) {
        activeField = .fiat
        guard let num = parseNumber(text), num >= 0 else { return }
        xmrValue = formatNumber(priceManager.fiatToXmr(num), decimals: 6)
        btcValue = formatNumber(priceManager.fiatToBtc(num), decimals: 8)
        fiatValue = formatNumber(num, decimals: 2)
    }

    private func onBtcChanged(_ text: String) {
        activeField = .btc
        guard let num = parseNumber(text), num >= 0 else { return }
        fiatValue = formatNumber(priceManager.btcToFiat(num), decimals: 2)
        xmrValue = formatNumber(priceManager.btcToXmr(num), decimals: 6)
        btcValue = formatNumber(num, decimals: 8)
    }

    private func loadLogoFallback() -> NSImage? {
        if let path = Bundle.main.path(forResource: "xmr_logo", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }
}

// MARK: - CopyPasteTextField (NSTextField subclass with cmd+c/v/x/a)

class CopyPasteTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, event.modifierFlags.contains(.command),
           let editor = currentEditor() {
            switch event.charactersIgnoringModifiers {
            case "c":
                editor.copy(nil)
                return true
            case "v":
                editor.paste(nil)
                return true
            case "x":
                editor.cut(nil)
                return true
            case "a":
                editor.selectAll(nil)
                return true
            case "z":
                undoManager?.undo()
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - NumberTextField (NSViewRepresentable wrapper)

struct NumberTextField: NSViewRepresentable {
    @Binding var value: String
    var placeholder: String = ""
    var onCommit: ((String) -> Void)?

    func makeNSView(context: Context) -> CopyPasteTextField {
        let tf = CopyPasteTextField()
        tf.placeholderString = placeholder
        tf.alignment = .right
        tf.isEditable = true
        tf.isSelectable = true
        tf.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.focusRingType = .default
        tf.bezelStyle = .roundedBezel
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ tf: CopyPasteTextField, context: Context) {
        if tf.stringValue != value {
            tf.stringValue = value
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: NumberTextField
        init(_ parent: NumberTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.value = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit?(parent.value)
                return true
            }
            return false
        }
    }
}

// MARK: - Monerochan on/off switch

struct MoneroChanToggle: View {
    @State private var on = UserDefaults.standard.bool(forKey: AppDelegate.moneroChanKey)

    var body: some View {
        HStack(spacing: 8) {
            Text("Monerochan")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Toggle("", isOn: Binding(
                get: { on },
                set: { v in
                    on = v
                    (NSApp.delegate as? AppDelegate)?.moneroChanEnabled = v
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.orange)
        }
        .frame(height: 22)
        .help("Show Monerochan running around your screen")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoneroChanChanged"))) { _ in
            on = UserDefaults.standard.bool(forKey: AppDelegate.moneroChanKey)
        }
    }
}

// MARK: - Fiat Dropdown (NSPopUpButton for small native arrow)

struct FiatDropdown: NSViewRepresentable {
    @ObservedObject var priceManager: PriceManager
    let onChange: () -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.alignment = .left
        button.autoresizingMask = [.width, .height]

        for fiat in PriceManager.fiats {
            let item = NSMenuItem(title: fiat.uppercased(), action: nil, keyEquivalent: "")
            item.representedObject = fiat
            button.menu?.addItem(item)
        }

        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let target = priceManager.selectedFiat.uppercased()
        let idx = button.indexOfItem(withTitle: target)
        if idx >= 0 {
            button.selectItem(at: idx)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: FiatDropdown
        init(_ parent: FiatDropdown) { self.parent = parent }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            let code = (sender.selectedItem?.representedObject as? String) ?? "usd"
            parent.priceManager.selectedFiat = code
            parent.onChange()
        }
    }
}
