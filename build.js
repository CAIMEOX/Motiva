const { execFileSync } = require("child_process");

const pkgConfig = process.env.PKG_CONFIG || "pkg-config";

function runPkgConfig(args) {
  try {
    return execFileSync(pkgConfig, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch (_) {
    return null;
  }
}

function withoutCairoLibrary(flags) {
  return flags.replace(/(^|\s)-lcairo(?=\s|$)/g, "$1").trim();
}

function platformLinkFlags(flags) {
  if (process.platform !== "darwin") {
    return flags;
  }
  // Moon's synthetic black-box runner repeats a native-stub package's flags.
  return `${flags} -Wl,-no_warn_duplicate_libraries`;
}

const supported = runPkgConfig(["--atleast-version=1.56", "pangocairo"]);
const cflags =
  supported === null ? null : runPkgConfig(["--cflags", "pangocairo"]);
const discoveredLibs =
  supported === null ? null : runPkgConfig(["--libs", "pangocairo"]);
const libs =
  discoveredLibs === null ? null : withoutCairoLibrary(discoveredLibs);
const available = cflags !== null && libs !== null;

console.log(
  JSON.stringify({
    vars: {
      PANGOCAIRO_CC_FLAGS: available
        ? `-DMOTIVA_PANGO_VERSION_OK=1 ${cflags}`.trim()
        : "",
    },
    link_configs:
      !available
        ? []
        : [
            {
              package: "CAIMEOX/Motiva/pango_native",
              link_flags: platformLinkFlags(libs),
            },
          ],
  }),
);
