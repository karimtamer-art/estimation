# Logo

`logo.svg` is the mark: four cards fanned — four seats at the table — with the
front one gold and carrying a spade. `logo-maskable.svg` is the same artwork
full-bleed and pulled into the 80% safe zone Android launchers mask against.
`logo-favicon.svg` drops the fan for a single card, because the fan's edges turn
to mush below about 48px.

Palette is the app's own: `#0F1C22` tile, `#D9A441` gold, `#132229` for the
back cards so their edges read against the tile.

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
