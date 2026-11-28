# Jospar local patch

Upstream: https://pub.dev/packages/liquid_glass_fx/versions/0.0.2
License: MIT, preserved in LICENSE.

The upstream shader-enabled LiquidGlass.build captures its mutable `content`
variable inside a LayoutBuilder and subsequently assigns that LayoutBuilder to
`content`. This makes the returned BackdropFilter contain the same LayoutBuilder
recursively, causing layout failures when the shader is available on Impeller.
Store the already-built blur subtree as an immutable child on a separate
LiquidGlassShaderBackdrop widget before the assignment. Its layout is covered by
test/core/widgets/liquid_glass_layout_test.dart without requiring Impeller.

The shader loader also uses the package-qualified asset key so application code
does not need to copy the shader into its own assets.

Keep these fixes until an upstream release includes them. Widget tests on Skia
exercise fallback rendering; test the full shader on an Impeller device as well.
