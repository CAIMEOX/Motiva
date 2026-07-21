// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "CAIMEOX/Motiva"

version = "0.3.0"

readme = "README.mbt.md"

repository = "https://github.com/caimeox/motiva"

license = "Apache-2.0"

keywords = [ "animation", "manim", "graphics", "timeline" ]

description = "A MoonBit animation engine inspired by Manim."

import {
  "CAIMEOX/cairoon@0.2.0",
  "moonbitlang/async@0.19.1",
  "moonbit-community/XMLParser@0.2.5",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
