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

`web/icons/*` and `web/favicon.png` are rendered from these SVGs with headless
Chrome at 512, then downscaled:

    chrome --headless --disable-gpu --force-device-scale-factor=1 \
      --virtual-time-budget=3000 --default-background-color=00000000 \
      --screenshot=Icon-512.png --window-size=512,512 design/logo.svg

Render at 512 and scale down — Chrome will not lay out a window smaller than
its minimum width, so a `--window-size=192,192` shot comes out cropped.
