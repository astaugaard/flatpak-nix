{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      in
      {
        devShell =
          with pkgs;
          mkShell {
            buildInputs = [
              flatpak-builder
            ];
          };

        buildFlatpakBasic =
          {
            derv,
            id,
            bin,
          }:
          (pkgs.stdenv.mkDerivation {
            name = id;
            unpackPhase = "true";
            dontFixup = true;

            buildPhase =
              let
                run-script = pkgs.writeText "$out/exe" ''
                  #!/bin/bash
                  echo hello
                  mkdir /nix/
                  mkdir /nix/store/

                  ln -s /app/nix/store/* /nix/store/

                  exec ${derv}/bin/${bin}
                '';

                metadata = pkgs.writeText "$out/metadata" ''
                  [Application]
                  name=${id}
                  runtime=org.freedesktop.Platform/x86_64/23.08
                  sdk=org.freedesktop.Sdk/x86_64/23.08
                  command=${bin}
                '';
              in
              ''
                cat ${pkgs.writeClosure derv}

                mkdir $out

                mkdir $out/files
                mkdir $out/var
                mkdir $out/var/tmp
                ln -s /run/ $out/var/run # check if can remove var folder

                mkdir $out/files/nix/
                mkdir $out/files/bin/
                mkdir $out/files/export/

                cat ${pkgs.writeClosure derv} | xargs tar -c | tar -xC $out/files/

                cat ${run-script}
                install -Dm755 ${run-script} $out/files/bin/${bin}
                cp ${metadata} $out/metadata


                ${pkgs.flatpak}/bin/flatpak build-finish --command ${bin} $out
              '';
          });

        flatpak-cowsay = self.buildFlatpakBasic.x86_64-linux {
          derv = pkgs.cowsay;
          id = "org.flatpak.Cowsay";
          bin = "cowsay";
        };

        flatpak-cowsay-closure = (
          pkgs.stdenv.mkDerivation {
            name = "flatpak-cowsay-closure";
            unpackPhase = "true";

            buildPhase = ''
              mkdir $out
              cp -r ${pkgs.writeClosure pkgs.cowsay} $out/nixflake
            '';
          }
        );
      }
    );
}
