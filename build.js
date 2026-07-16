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

const supported = runPkgConfig(["--atleast-version=1.56", "pangocairo"]);
const cflags =
  supported === null ? null : runPkgConfig(["--cflags", "pangocairo"]);
const libs =
  supported === null ? null : runPkgConfig(["--libs", "pangocairo"]);
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
              link_flags: libs,
            },
          ],
  }),
);
