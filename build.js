const { execFileSync } = require("child_process");

const pkgConfig = process.env.PKG_CONFIG || "pkg-config";
let cflags = null;
try {
  execFileSync(pkgConfig, ["--atleast-version=1.56", "pangocairo"], {
    stdio: "ignore",
  });
  cflags = execFileSync(pkgConfig, ["--cflags", "pangocairo"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
} catch (_) {
  // Moon reports the missing native dependency when compiling the renderer.
}

console.log(
  JSON.stringify({
    vars: {
      // The generated PangoRenderer subclass needs headers while compiling.
      // The published binding packages provide their own native link flags.
      PANGOCAIRO_CC_FLAGS: cflags === null ? "" : cflags,
    },
    link_configs: [],
  }),
);
