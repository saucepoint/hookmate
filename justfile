solc_file := if os() == "macos" { "lib/v4-core/bin/solc-mac" } else { "lib/v4-core/bin/solc-static-linux" }

test *args: (test-forge args)
build *args: (build-forge args)
prep *args: fix (test args)

test-forge *args: install-forge build-forge
    forge test --use {{ solc_file }} {{ args }}

build-forge *args: install-forge
    forge build --use {{ solc_file }} {{ args }}

install-forge:
    forge install

fix:
    forge fmt
