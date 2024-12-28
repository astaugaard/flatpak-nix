#!/usr/bin/env bash

nix build ".#flatpak-cowsay.x86_64-linux"
flatpak build-export outrepo ./result
flatpak update

