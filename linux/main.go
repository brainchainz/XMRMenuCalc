package main

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
	"golang.org/x/image/font"
	"golang.org/x/image/font/basicfont"
	"golang.org/x/image/math/fixed"
)

var (
	pm      = NewPriceManager()
	myApp   fyne.App
	win     fyne.Window
	visible bool

	// Entry references
	xmrEntry  *widget.Entry
	fiatEntry *widget.Entry
	btcEntry  *widget.Entry
	fiatBtn   *widget.Button

	activeField = "xmr"
)

func main() {
	myApp = app.NewWithID("com.monero.xmrmencalc")
	myApp.SetIcon(makeMoneroIcon())

	win = myApp.NewWindow("XMRMenuCalc")
	win.SetFixedSize(true)
	win.Resize(fyne.NewSize(380, 320))
	win.SetContent(buildCalculator())
	win.SetCloseIntercept(func() {
		win.Hide()
		visible = false
	})

	// System tray
	if desk, ok := myApp.(desktop.App); ok {
		m := fyne.NewMenu("XMRMenuCalc",
			fyne.NewMenuItem("Show Calculator", func() {
				toggleWindow()
			}),
			fyne.NewMenuItemSeparator(),
			fyne.NewMenuItem("Quit", func() {
				myApp.Quit()
			}),
		)
		desk.SetSystemTrayMenu(m)
		desk.SetSystemTrayIcon(makeMoneroIcon())
	}

	// Price updates refresh the tray tooltip and title
	pm.onUpdate = func() {
		if desk, ok := myApp.(desktop.App); ok {
			desk.SetSystemTrayIcon(makeMoneroIcon())
		}
	}

	pm.Start()
	myApp.Run()
}

func toggleWindow() {
	if visible {
		win.Hide()
		visible = false
	} else {
		win.Show()
		win.RequestFocus()
		visible = true
	}
}

func buildCalculator() fyne.CanvasObject {
	// Title
	title := widget.NewLabelWithStyle("XMRMenuCalc", fyne.TextAlignCenter, fyne.TextStyle{Bold: true})

	// Fiat dropdown
	fiatBtn = widget.NewButton(strings.ToUpper(pm.SelectedFiat()), func() {
		showFiatPicker()
	})
	fiatBtn.Importance = widget.LowImportance

	// Entries
	xmrEntry = widget.NewEntry()
	xmrEntry.SetPlaceHolder("0.00")
	xmrEntry.OnChanged = func(s string) {
		if activeField != "xmr" {
			return
		}
		v := parseInput(s)
		updateFromXMR(v)
	}

	fiatEntry = widget.NewEntry()
	fiatEntry.SetPlaceHolder("0.00")
	fiatEntry.OnChanged = func(s string) {
		if activeField != "fiat" {
			return
		}
		v := parseInput(s)
		updateFromFiat(v)
	}

	btcEntry = widget.NewEntry()
	btcEntry.SetPlaceHolder("0.00000000")
	btcEntry.OnChanged = func(s string) {
		if activeField != "btc" {
			return
		}
		v := parseInput(s)
		updateFromBTC(v)
	}

	// Rows
	xmrRow := container.NewBorder(nil, nil, widget.NewLabel("XMR"), nil, xmrEntry)
	fiatSym := widget.NewLabel(fiatSymbol(pm.SelectedFiat()))
	fiatRow := container.NewBorder(nil, nil, container.NewHBox(fiatSym, fiatBtn), nil, fiatEntry)
	btcRow := container.NewBorder(nil, nil, widget.NewLabel("BTC"), nil, btcEntry)

	content := container.NewVBox(
		title,
		widget.NewSeparator(),
		layout.NewSpacer(),
		xmrRow,
		fiatRow,
		btcRow,
		layout.NewSpacer(),
	)

	return container.NewPadded(content)
}

func showFiatPicker() {
	popup := myApp.NewWindow("Select Currency")
	popup.SetFixedSize(true)
	popup.Resize(fyne.NewSize(300, 500))

	var list *widget.List
	list = widget.NewList(
		func() int { return len(fiats) },
		func() fyne.CanvasObject {
			return widget.NewLabel("Currency")
		},
		func(i widget.ListItemID, o fyne.CanvasObject) {
			code := fiats[i]
			label := o.(*widget.Label)
			label.SetText(fmt.Sprintf("%s  %s", strings.ToUpper(code), fiatSymbol(code)))
		},
	)
	list.OnSelected = func(id widget.ListItemID) {
		pm.SetSelectedFiat(fiats[id])
		fiatBtn.SetText(strings.ToUpper(fiats[id]))
		popup.Close()
	}

	popup.SetContent(list)
	popup.Show()
}

func updateFromXMR(v float64) {
	if v == 0 {
		fiatEntry.SetText("")
		btcEntry.SetText("")
		return
	}
	fiat := pm.SelectedFiat()
	price := pm.XMRPrice(fiat)
	fiatEntry.SetText(formatPrice(v * price))
	btcPrice := pm.XMRBTCPrice()
	btcEntry.SetText(fmt.Sprintf("%.8f", v*btcPrice))
}

func updateFromFiat(v float64) {
	if v == 0 {
		xmrEntry.SetText("")
		btcEntry.SetText("")
		return
	}
	fiat := pm.SelectedFiat()
	price := pm.XMRPrice(fiat)
	if price == 0 {
		return
	}
	xmr := v / price
	xmrEntry.SetText(fmt.Sprintf("%.8f", xmr))
	btcPrice := pm.XMRBTCPrice()
	btcEntry.SetText(fmt.Sprintf("%.8f", xmr*btcPrice))
}

func updateFromBTC(v float64) {
	if v == 0 {
		xmrEntry.SetText("")
		fiatEntry.SetText("")
		return
	}
	btcPrice := pm.XMRBTCPrice()
	if btcPrice == 0 {
		return
	}
	xmr := v / btcPrice
	xmrEntry.SetText(fmt.Sprintf("%.8f", xmr))
	fiat := pm.SelectedFiat()
	price := pm.XMRPrice(fiat)
	fiatEntry.SetText(formatPrice(xmr * price))
}

// makeMoneroIcon creates a simple orange circle with "X" for the tray
func makeMoneroIcon() fyne.Resource {
	// Try to load file-based icon first
	if _, err := os.Stat("xmr_logo.png"); err == nil {
		if res, err := fyne.LoadResourceFromPath("xmr_logo.png"); err == nil {
			return res
		}
	}

	// Fallback: render a simple icon
	size := 64
	img := image.NewRGBA(image.Rect(0, 0, size, size))

	// Orange background circle
	center := size / 2
	radius := size/2 - 2
	orange := color.RGBA{255, 102, 0, 255}
	white := color.RGBA{255, 255, 255, 255}

	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			dx := x - center
			dy := y - center
			if dx*dx+dy*dy <= radius*radius {
				img.Set(x, y, orange)
			}
		}
	}

	// Draw "X" in white
	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(white),
		Face: basicfont.Face7x13,
		Dot:  fixed.P(size/2-4, size/2+5),
	}
	d.DrawString("X")

	var buf bytes.Buffer
	png.Encode(&buf, img)
	return fyne.NewStaticResource("icon.png", buf.Bytes())
}

// stubs to satisfy build until we wire real imports
func _() {}
