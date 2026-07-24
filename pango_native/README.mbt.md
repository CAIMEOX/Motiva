# `pango_native`

`pango_native` is Motiva's native text shaping and layout package. It uses an
independent Pango font map and PangoCairo to shape text, then lowers every
visible shaping cluster through a dedicated SVG renderer into a normal Motiva
object family. Cluster identity is explicit and does not depend on Cairo's SVG
serializer output.

The package supports:

- plain `Text` and Pango `MarkupText`;
- Unicode shaping, bidirectional text, fallback fonts, and OpenType features;
- font family, size, slant, weight, stretch, language, and runtime font files;
- foreground/background paint, underline, overline, strikethrough, rise, and
  letter spacing on source ranges;
- width, height, wrapping, ellipsizing, alignment, justification, indentation,
  line spacing, direction, and DPI;
- source fragments, shaping clusters, glyph family paths, line metrics, and
  cluster-aware gradients;
- direct `IntoObject` conversion for Scene animations such as `Write`.

The native target requires `pkg-config`, PangoCairo 1.56 or newer, and Cairo.
Motiva uses `tonyfettes/pango`, `tonyfettes/pangocairo`, and
`tonyfettes/cairo` 0.2.0 for the native API and link configuration. The root
`build.js` discovers the compiler flags needed by the generated renderer
subclass without hardcoding a Homebrew or Linux installation path. Set
`PKG_CONFIG` to select a compatible `pkg-config` executable when
cross-compiling or using a non-default sysroot.

```mbt nocheck
let text = @pango_native.Text::new(
  "Hello  العربية  中文",
  style=@pango_native.TextStyle::new(
    font_size=54.0,
    weight=@pango_native.Bold,
  ),
).set_gradient_by_text(
  "中文",
  [@object.Rgba::yellow(), @object.Rgba::red()],
)

let id = scene.object(text)
scene.play([@scene.Animation::write(id, run_time=1.5)])
```

Use a persistent `PangoTextEngine` when registering private font files. The
returned `FontRegistration` belongs to that engine and is used to unregister
the same file later.

`pango_metrics()`, `PangoTextLine`, `PangoRect`, and
`TextCluster::pango_logical_bounds()` expose coordinates in Pango layout space.
They are useful for inspection and source-to-glyph queries, but they are not
the centered and scaled coordinates of the resulting Motiva `Object`; use the
object's bounds for scene layout.

The cluster-aware renderer is a normal MoonBit GObject subclass in
`pango_native/internal/renderer`. Its generated C file only installs the
`PangoRenderer` subclass and dispatches virtual methods back to MoonBit; Motiva
does not keep a handwritten Pango or Cairo API stub.

Regenerate the two `motiva_pango_svg_renderer.generated.*` files from a
`tonyfettes/g` checkout:

```sh
moon run --target native gir/subclass/main -- \
  --config pango/gir.json \
  --pkg pango \
  --symbol-prefix motiva_pango_native_renderer \
  --gir-dir /path/to/gir-1.0 \
  --output /path/to/Motiva/pango_native/internal/renderer \
  /path/to/Motiva/pango_native/internal/renderer/renderer.mbt
```
