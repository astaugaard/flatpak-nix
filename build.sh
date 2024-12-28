#!/usr/bin/env bash

id=$1
derv=$2


nix --extra-experimental-features nix-command copy --to ./nixflake $derv --no-check-sigs

cat >$id.yml <<EOL
id: ${id}
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk # will change this in the future for now just use this as the default
command: hello
modules:
  - name: hello
    buildsystem: simple
    build-commands:
    - echo got here
    - cp -r ./nixflake/nix/store /app/nix/store
    sources:
    - type: dir
      path: ./nixflake/nix/store/
EOL

flatpak-builder --force-clean --user --install-deps-from=flathub --install buildir ${id}.yml -v
