package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

var fiats = []string{
	"usd", "eur", "gbp", "jpy", "cny", "aud", "cad", "chf", "sek", "nzd",
	"krw", "inr", "mxn", "brl", "rub", "try", "zar", "sgd", "nok", "dkk",
	"pln", "huf", "czk", "thb", "myr", "php", "idr", "vnd", "aed", "sar",
	"ils", "hkd", "cop", "ars", "clp", "pen",
}

var fiatSymbols = map[string]string{
	"usd": "$", "eur": "€", "gbp": "£", "jpy": "¥", "cny": "¥",
	"aud": "A$", "cad": "C$", "chf": "Fr", "sek": "kr", "nzd": "NZ$",
	"krw": "₩", "inr": "₹", "mxn": "$", "brl": "R$", "rub": "₽",
	"try": "₺", "zar": "R", "sgd": "S$", "nok": "kr", "dkk": "kr",
	"pln": "zł", "huf": "Ft", "czk": "Kč", "thb": "฿", "myr": "RM",
	"php": "₱", "idr": "Rp", "vnd": "₫", "aed": "د.إ", "sar": "﷼",
	"ils": "₪", "hkd": "HK$", "cop": "$", "ars": "$", "clp": "$",
	"pen": "S/",
}

type PriceManager struct {
	mu           sync.RWMutex
	xmrPrices    map[string]float64
	btcPrices    map[string]float64
	selectedFiat string
	onUpdate     func()
}

func NewPriceManager() *PriceManager {
	return &PriceManager{
		xmrPrices:    make(map[string]float64),
		btcPrices:    make(map[string]float64),
		selectedFiat: "usd",
	}
}

func (pm *PriceManager) Start() {
	pm.fetch()
	ticker := time.NewTicker(60 * time.Second)
	go func() {
		for range ticker.C {
			pm.fetch()
		}
	}()
}

func (pm *PriceManager) fetch() {
	vs := strings.Join(fiats, ",")
	url := fmt.Sprintf("https://api.coingecko.com/api/v3/simple/price?ids=monero,bitcoin&vs_currencies=%s", vs)

	resp, err := http.Get(url)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return
	}

	var data map[string]map[string]float64
	if err := json.Unmarshal(body, &data); err != nil {
		return
	}

	pm.mu.Lock()
	if monero, ok := data["monero"]; ok {
		pm.xmrPrices = monero
	}
	if bitcoin, ok := data["bitcoin"]; ok {
		pm.btcPrices = bitcoin
	}
	pm.mu.Unlock()

	if pm.onUpdate != nil {
		pm.onUpdate()
	}
}

func (pm *PriceManager) XMRPrice(fiat string) float64 {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	return pm.xmrPrices[fiat]
}

func (pm *PriceManager) BTCPrice(fiat string) float64 {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	return pm.btcPrices[fiat]
}

func (pm *PriceManager) XMRBTCPrice() float64 {
	pm.mu.RLock()
	usd := pm.xmrPrices["usd"]
	btcUsd := pm.btcPrices["usd"]
	pm.mu.RUnlock()
	if btcUsd == 0 {
		return 0
	}
	return usd / btcUsd
}

func (pm *PriceManager) SelectedFiat() string {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	return pm.selectedFiat
}

func (pm *PriceManager) SetSelectedFiat(f string) {
	pm.mu.Lock()
	pm.selectedFiat = strings.ToLower(f)
	pm.mu.Unlock()
	if pm.onUpdate != nil {
		pm.onUpdate()
	}
}

func (pm *PriceManager) StatusText() string {
	pm.mu.RLock()
	fiat := pm.selectedFiat
	price := pm.xmrPrices[fiat]
	pm.mu.RUnlock()
	sym := fiatSymbols[fiat]
	if price == 0 {
		return "XMR"
	}
	return fmt.Sprintf("XMR %s%s", sym, formatPrice(price))
}

func formatPrice(p float64) string {
	if p >= 1000 {
		return fmt.Sprintf("%.2f", p)
	}
	if p >= 1 {
		return fmt.Sprintf("%.2f", p)
	}
	return fmt.Sprintf("%.4f", p)
}

func parseInput(s string) float64 {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	f, _ := strconv.ParseFloat(s, 64)
	return f
}

func fiatSymbol(code string) string {
	if s, ok := fiatSymbols[strings.ToLower(code)]; ok {
		return s
	}
	return "$"
}
