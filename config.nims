switch("path", "meta")

## Build presets: configs/default.toml, plus configs/<name>.toml with -d:preset=<name>.
when fileExists(thisDir() & "/../Nimble-Tasks/src/preset.nims"):
  include "../Nimble-Tasks/src/preset.nims"
elif fileExists(thisDir() & "/submodules/Nimble-Tasks/src/preset.nims"):
  include "submodules/Nimble-Tasks/src/preset.nims"
else:
  proc applyPreset() = echo "config.nims: Nimble-Tasks/src/preset.nims not found; configs/*.toml ignored."
applyPreset()
