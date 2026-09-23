package main

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/draw"
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
	pm           = NewPriceManager()
	myApp        fyne.App
	win          fyne.Window
	visible      bool

	// Entry references
	xmrEntry     *widget.Entry
	fiatEntry    *widget.Entry
	btcEntry     *widget.Entry
	fiatBtn      *widget.Button
	fiatSymLabel *widget.Label

	activeField = "xmr"
)

func main() {
	myApp = app.NewWithID("com.monero.xmrmencalc")
	myApp.SetIcon(loadMoneroLogo())

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
		desk.SetSystemTrayIcon(loadMoneroLogo())
	}

	// Price updates refresh the tray icon with logo + live price text
	pm.onUpdate = func() {
		if desk, ok := myApp.(desktop.App); ok {
			price := pm.XMRPrice(pm.SelectedFiat())
			sym := fiatSymbol(pm.SelectedFiat())
			desk.SetSystemTrayIcon(makeCompositeIcon(price, sym))
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
	fiatSymLabel = widget.NewLabel(fiatSymbol(pm.SelectedFiat()))
	fiatRow := container.NewBorder(nil, nil, container.NewHBox(fiatSymLabel, fiatBtn), nil, fiatEntry)
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
		fiatSymLabel.SetText(fiatSymbol(fiats[id]))
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

// loadMoneroLogo loads xmr_logo.png or falls back to a generated icon.
func loadMoneroLogo() fyne.Resource {
	for _, path := range []string{"xmr_logo.png", "linux/xmr_logo.png"} {
		if _, err := os.Stat(path); err == nil {
			if res, err := fyne.LoadResourceFromPath(path); err == nil {
				return res
			}
		}
	}
	return makeFallbackIcon()
}

// makeCompositeIcon renders the Monero logo (scaled) + price text on a wide tray icon.
// Transparent background blends with panel color, white text for contrast on dark panels.
func makeCompositeIcon(price float64, symbol string) fyne.Resource {
	iconSize := 18
	padding := 4
	textWidth := 52
	width := iconSize + padding + textWidth
	height := 22
	canvas := image.NewRGBA(image.Rect(0, 0, width, height))

	// Transparent background
	clearRect(canvas, canvas.Bounds(), color.RGBA{0, 0, 0, 0})

	// Load and draw scaled Monero logo
	logoImg, err := loadLogoImage()
	if err == nil {
		scaled := scaleBox(logoImg, iconSize, iconSize)
		yOff := (height - iconSize) / 2
		draw.Draw(canvas, image.Rect(0, yOff, iconSize, yOff+iconSize), scaled, image.Point{}, draw.Over)
	}

	// Price text in white (macOS menu bar text color)
	text := "XMR"
	if price > 0 {
		text = formatTrayPrice(price, symbol)
	}
	tw := len(text) * 7
	xPos := iconSize + padding + (textWidth-tw)/2
	if xPos < iconSize+padding {
		xPos = iconSize + padding
	}

	d := &font.Drawer{
		Dst:  canvas,
		Src:  image.NewUniform(color.RGBA{255, 255, 255, 255}),
		Face: basicfont.Face7x13,
		Dot:  fixed.P(xPos, 16),
	}
	d.DrawString(text)

	var buf bytes.Buffer
	png.Encode(&buf, canvas)
	return fyne.NewStaticResource("composite.png", buf.Bytes())
}

func loadLogoImage() (image.Image, error) {
	for _, path := range []string{"xmr_logo.png", "linux/xmr_logo.png"} {
		data, err := os.ReadFile(path)
		if err == nil {
			img, err := png.Decode(bytes.NewReader(data))
			if err == nil {
				return img, nil
			}
		}
	}
	return nil, fmt.Errorf("logo not found")
}

// scaleBox downscales using a simple box filter (average of pixel block).
// Produces smoother results than nearest-neighbor for photo/logos.
func scaleBox(src image.Image, w, h int) image.Image {
	dst := image.NewRGBA(image.Rect(0, 0, w, h))
	sw := src.Bounds().Dx()
	sh := src.Bounds().Dy()
	sx0 := src.Bounds().Min.X
	sy0 := src.Bounds().Min.Y

	for y := 0; y < h; y++ {
		syStart := y * sh / h
		syEnd := (y + 1) * sh / h
		if syEnd == syStart {
			syEnd = syStart + 1
		}
		for x := 0; x < w; x++ {
			sxStart := x * sw / w
			sxEnd := (x + 1) * sw / w
			if sxEnd == sxStart {
				sxEnd = sxStart + 1
			}

			var r, g, b, a uint32
			count := uint32(0)
			for yy := syStart; yy < syEnd; yy++ {
				for xx := sxStart; xx < sxEnd; xx++ {
					pr, pg, pb, pa := src.At(sx0+xx, sy0+yy).RGBA()
					r += pr >> 8
					g += pg >> 8
					b += pb >> 8
					a += pa >> 8
					count++
				}
			}
			if count > 0 {
				dst.Set(x, y, color.RGBA{
					R: uint8(r / count),
					G: uint8(g / count),
					B: uint8(b / count),
					A: uint8(a / count),
				})
			}
		}
	}
	return dst
}

func clearRect(img *image.RGBA, r image.Rectangle, c color.Color) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			img.Set(x, y, c)
		}
	}
}

func formatTrayPrice(price float64, symbol string) string {
	if price >= 100 {
		return fmt.Sprintf("%s%.0f", symbol, price)
	}
	if price >= 10 {
		return fmt.Sprintf("%s%.1f", symbol, price)
	}
	return fmt.Sprintf("%s%.2f", symbol, price)
}

// makeFallbackIcon creates a simple orange circle with "M" for when logo is missing.
func makeFallbackIcon() fyne.Resource {
	size := 64
	img := image.NewRGBA(image.Rect(0, 0, size, size))

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

	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(white),
		Face: basicfont.Face7x13,
		Dot:  fixed.P(size/2-5, size/2+5),
	}
	d.DrawString("M")

	var buf bytes.Buffer
	png.Encode(&buf, img)
	return fyne.NewStaticResource("icon.png", buf.Bytes())
}
