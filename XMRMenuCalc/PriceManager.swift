import Foundation

/// Fetches and caches XMR and BTC prices in multiple fiat currencies from CoinGecko
class PriceManager: ObservableObject {
    static let shared = PriceManager()

    static let fiats = [
        "usd", "eur", "gbp", "jpy", "cny", "aud", "cad", "chf", "sek", "nzd",
        "krw", "inr", "mxn", "brl", "rub", "try", "zar", "sgd", "nok", "dkk",
        "pln", "huf", "czk", "thb", "myr", "php", "idr", "vnd", "aed", "sar",
        "ils", "hkd", "cop", "ars", "clp", "pen"
    ]

    @Published var xmrPrices: [String: Double] = [:]
    @Published var btcPrices: [String: Double] = [:]

    @Published var selectedFiat: String {
        didSet {
            UserDefaults.standard.set(selectedFiat, forKey: "selectedFiat")
            NotificationCenter.default.post(name: .init("FiatChanged"), object: nil)
        }
    }

    private var timer: Timer?

    private init() {
        selectedFiat = UserDefaults.standard.string(forKey: "selectedFiat") ?? "usd"
    }

    private var apiURL: URL {
        let vs = Self.fiats.joined(separator: ",")
        return URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=monero,bitcoin&vs_currencies=\(vs)")!
    }

    var xmrUsdPrice: Double { xmrPrices["usd"] ?? 0 }
    var btcUsdPrice: Double { btcPrices["usd"] ?? 0 }

    var xmrBtcPrice: Double {
        guard btcUsdPrice > 0 else { return 0 }
        return xmrUsdPrice / btcUsdPrice
    }

    static func fiatSymbol(for code: String) -> String {
        switch code.lowercased() {
        case "usd": return "$"
        case "eur": return "€"
        case "gbp": return "£"
        case "jpy": return "¥"
        case "cny": return "¥"
        case "aud": return "A$"
        case "cad": return "C$"
        case "chf": return "Fr"
        case "sek": return "kr"
        case "nzd": return "NZ$"
        case "krw": return "₩"
        case "inr": return "₹"
        case "mxn": return "$"
        case "brl": return "R$"
        case "rub": return "₽"
        case "try": return "₺"
        case "zar": return "R"
        case "sgd": return "S$"
        case "nok": return "kr"
        case "dkk": return "kr"
        case "pln": return "zł"
        case "huf": return "Ft"
        case "czk": return "Kč"
        case "thb": return "฿"
        case "myr": return "RM"
        case "php": return "₱"
        case "idr": return "Rp"
        case "vnd": return "₫"
        case "aed": return "د.إ"
        case "sar": return "﷼"
        case "ils": return "₪"
        case "hkd": return "HK$"
        case "cop": return "$"
        case "ars": return "$"
        case "clp": return "$"
        case "pen": return "S/"
        default: return code.uppercased()
        }
    }

    func startUpdating() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let task = URLSession.shared.dataTask(with: apiURL) { [weak self] (data, response, error) in
            guard let data = data else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let monero = json?["monero"] as? [String: Double] {
                    DispatchQueue.main.async {
                        self?.xmrPrices = monero
                    }
                }

                if let bitcoin = json?["bitcoin"] as? [String: Double] {
                    DispatchQueue.main.async {
                        self?.btcPrices = bitcoin
                    }
                }
            } catch {
                print("Price fetch error: \(error)")
            }
        }
        task.resume()
    }

    // MARK: - Conversion helpers

    private func xmrPrice(for currency: String) -> Double {
        xmrPrices[currency.lowercased()] ?? 0
    }

    private func btcPrice(for currency: String) -> Double {
        btcPrices[currency.lowercased()] ?? 0
    }

    func xmrToFiat(_ xmr: Double, currency: String? = nil) -> Double {
        let c = (currency ?? selectedFiat).lowercased()
        return xmr * xmrPrice(for: c)
    }

    func fiatToXmr(_ fiat: Double, currency: String? = nil) -> Double {
        let c = (currency ?? selectedFiat).lowercased()
        let p = xmrPrice(for: c)
        guard p > 0 else { return 0 }
        return fiat / p
    }

    func btcToFiat(_ btc: Double, currency: String? = nil) -> Double {
        let c = (currency ?? selectedFiat).lowercased()
        return btc * btcPrice(for: c)
    }

    func fiatToBtc(_ fiat: Double, currency: String? = nil) -> Double {
        let c = (currency ?? selectedFiat).lowercased()
        let p = btcPrice(for: c)
        guard p > 0 else { return 0 }
        return fiat / p
    }

    func xmrToBtc(_ xmr: Double) -> Double {
        let usd = xmrToFiat(xmr, currency: "usd")
        return fiatToBtc(usd, currency: "usd")
    }

    func btcToXmr(_ btc: Double) -> Double {
        let usd = btcToFiat(btc, currency: "usd")
        return fiatToXmr(usd, currency: "usd")
    }
}
