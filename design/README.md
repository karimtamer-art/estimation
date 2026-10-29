# Logo

`logo.svg` is the mark: four cards fanned — four seats at the table — with the
front one gold and carrying a spade. `logo-maskable.svg` is the same artwork
full-bleed and pulled into the 80% safe zone Android launchers mask against.
`logo-favicon.svg` drops the fan for a single card, because the fan's edges turn
to mush below about 48px.
`logo-adaptive-foreground.svg` and `logo-adaptive-background.svg` are the two
layers of the Android 8+ adaptive icon: the fan alone, centred and scaled to
0.62 so it stays inside the 66dp-of-108dp circle every launcher mask keeps, and
the navy tile alone.

Style is the app's navy game look:
- Tile: radial gradient `#2C4F92` → `#16305F` → `#0A1633`, centred at 40% / 32%.
- Back cards: white faces (`#FFFFFF` → `#E4E1D8`) with a corner suit (♥ `#D9301F`,
  ♣ `#1A1A17`, ♦ `#D9301F`).
- Front card: gold gradient `#FFE871` → `#F8C21A` → `#D99A06`, with a white sheen
  on the top third at 22% and the spade in `#14182A`.
- Every card has a 12px `#050505` outline and a hard shadow (the same card
  shape, offset 10px down, `#050505` at 45%).

The card geometry, fan angles and spade path are unchanged from the previous logo.

The Flutter home screen draws the same geometry in `LogoMark`
(`lib/widgets.dart`) rather than shipping a raster, so it stays sharp at any
size. Both live in the same 512 box — change one, change the other.

## Regenerating the PNGs

    tool/render_icons.sh

That writes every file under `design/icons/` — web, android and ios — from the
SVGs above, then `tool/apply_branding.sh` copies them into a generated `web/`,
`android/` or `ios/`.

Do not screenshot a `.svg` directly. Chrome opens it in an image document that
does not stretch to the window, so a `--window-size=512,512` shot of a 512 box
lands the artwork in the top-left quarter of the canvas at half scale — which
is exactly what every committed icon looked like until this script replaced
that command. The script wraps the SVG in a page that pins it to `100vw`
instead, and takes the size from `--force-device-scale-factor` (window stays at
512), so each icon is rasterised from the vector at its final resolution rather
than downscaled.

The ios set comes from `logo-square.svg` on an opaque background and is
flattened to 24-bit RGB by `tool/strip_alpha.sh`, because App Store Connect
rejects an app icon carrying an alpha channel.
