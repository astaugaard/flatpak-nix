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

        platformBasic =
          {
            dervs,
            id,
          }:
          with pkgs;
          (
            let
              deps = lib.lists.unique (
                lib.lists.concatMap (
                  derv: lib.strings.splitString "\n" (builtins.readFile (writeClosure derv))
                ) dervs
              );
            in
            {
              build = pkgs.stdenv.mkDerivation {
                name = id;
                unpackPhase = "true";
                dontFixup = true;

                buildPhase =
                  let
                    metadata = pkgs.writeText "$out/metadata" ''
                      [Runtime]
                      name=${id}
                      runtime=${id}/x86_64/master
                      sdk=org.freedesktop.Sdk/x86_64/23.08
                    '';
                  in
                  # runtime=${id}/x86_64/24.08
                  ''
                    mkdir $out

                    mkdir $out/usr
                    mkdir $out/usr/share
                    mkdir $out/var
                    mkdir $out/var/tmp
                    ln -s /run/ $out/var/run # check if can remove var folder

                    mkdir $out/files
                    mkdir $out/usr/share/nix/
                    mkdir $out/usr/share/nix/store/
                    mkdir $out/usr/export/
                    mkdir $out/usr/bin/
                    mkdir $out/usr/lib/

                    cp -r ${pkgs.bash}/ $out/usr/share${pkgs.bash}
                    cp -r ${pkgs.coreutils}/ $out/usr/share${pkgs.coreutils}

                  ''
                  # update this to use the deps generated above
                  + (pkgs.lib.strings.concatMapStrings (derv: ''
                    cat ${pkgs.writeClosure derv} | xargs tar -c | tar --skip-old-files -xC $out/usr/share/
                  '') dervs)
                  + ''

                    ln -s /usr/share${pkgs.bash}/bin/bash $out/usr/bin/
                    ln -s /usr/share${pkgs.coreutils}/bin/ln $out/usr/bin/
                    ln -s /usr/share${pkgs.coreutils}/bin/mkdir $out/usr/bin/

                    cp ${metadata} $out/metadata


                    ${pkgs.flatpak}/bin/flatpak build-finish $out
                  '';
              };
              inherit deps;
              inherit id;
            }
          );

        buildPlatformExtensionBasic =
          {
            dervs,
            id,
            platform,
          }:
          (pkgs.stdenv.mkDerivation {

          });

        buildFlatpakBasic =
          {
            derv,
            id,
            bin,
            platform,
          }:
          (pkgs.stdenv.mkDerivation {
            name = id;
            unpackPhase = "true";
            dontFixup = true;

            buildPhase =
              with pkgs;
              let
                run-exe = pkgs.stdenv.mkDerivation {
                  name = "exe";
                  unpackPhase = "true";
                  dontFixup = true;
                  buildPhase =
                    let
                      file = pkgs.writeText "$out/main.rs" ''
                        // use std::os::unix::fs::*;
                        // use std::os::unix::process::*;
                        // use std::process::*;
                        // use std::fs::*;
                        // use std::*;

                        fn main() -> std::io::Result<()> {
                            println!("making directories");

                            Ok(())
                        //    create_dir("/nix/")?;
                        //    create_dir("/nix/store/")?;

                        //    println!("making symlinks");

                        //    for i in read_dir("/usr/share/nix/store/")? {
                            //    let i = i?;
                            //    symlink(i.path(), format!("/nix/store/{}", i.file_name().into_string().unwrap()))?
                        //    }

                        //    for i in read_dir("/app/nix/store/")? {
                            //    let i = i?;
                            //    symlink(i.path(), format!("/nix/store/{}", i.file_name().into_string().unwrap()))?
                        //    }

                        //    Err(Command::new("${derv}/bin/${bin}").args(env::args()).exec())
                        }
                      '';
                    in
                    ''
                      mkdir -p $out/bin
                      echo "made directory"
                      cat ${file}

                      ${pkgs.rustc}/bin/rustc ${file} -o $out/bin/exe
                      patchelf --set-rpath /usr/share${libgcc}/lib/:/usr/share${glibc}/lib/ $out/bin/exe
                    '';
                };

                # run-script = writeText "$out/exe" ''
                #   #!/bin/bash
                #   echo hello
                #   mkdir /nix/
                #   mkdir /nix/store/

                #   ln -s /usr/nix/store/* /nix/store/
                #   ln -s /app/nix/store/* /nix/store/

                #   exec ${derv}/bin/${bin}
                # '';

                metadata = writeText "$out/metadata" ''
                  [Application]
                  name=${id}
                  runtime=${platform.id}/x86_64/master
                  sdk=org.freedesktop.Sdk/x86_64/23.08
                  command=${bin}
                '';

                platform_closure = platform.deps;
                derv_closure = lib.strings.splitString "\n" (builtins.readFile (writeClosure derv));

                neededDervs = lib.lists.subtractLists platform_closure derv_closure;

                min_closure = writeText "$out/closure" (lib.strings.concatStringsSep "\n" neededDervs);
              in
              ''
                cat ${min_closure}

                mkdir $out

                mkdir $out/files
                mkdir $out/var
                mkdir $out/var/tmp
                ln -s /run/ $out/var/run # check if can remove var folder

                mkdir $out/files/nix/
                mkdir $out/files/bin/
                mkdir $out/files/export/

                cat ${min_closure} | xargs tar -c | tar -xC $out/files/

                install -Dm755 ${run-exe}/bin/exe $out/files/bin/${bin}
                cp ${metadata} $out/metadata


                ${flatpak}/bin/flatpak build-finish --command ${bin} $out
              '';
          });

        flatpak-cowsay = self.buildFlatpakBasic.x86_64-linux {
          derv = pkgs.cowsay;
          id = "org.flatpak.Cowsay";
          bin = "cowsay";
          platform = self.flatpak-nix-platform.x86_64-linux;
        };

        flatpak-nix-platform = self.platformBasic.x86_64-linux {
          dervs = [
            pkgs.libgcc
            pkgs.perl
            pkgs.coreutils
            pkgs.zlib
            pkgs.attr
            pkgs.acl
            pkgs.bash
            pkgs.libidn2
            pkgs.libxcrypt
            pkgs.glibc
          ];
          id = "org.flatpak.nix-cli";
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
