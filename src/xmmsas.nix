{
  xmmsasSrc ? {
    x86_64-linux = {
      version = "22.1.0";
      url = "https://heasarc.gsfc.nasa.gov/FTP/xmm/software/sas/22.1.0/Linux/Ubuntu24.04/sas_22.1.0-a8f2c2afa-20250304-ubuntu24.04-gcc13.3.0-x86_64.tgz";
      sha256 = "sha256-+AhdcbAjG5sh/HpFRXRslI9LxZINf6fM6VOytWC+2Iw=";
    };

    aarch64-darwin = {
      version = "22.1.0";
      url = "https://heasarc.gsfc.nasa.gov/FTP/xmm/software/sas/22.1.0/macOS/14.6/sas_22.1.0-a8f2c2afa-20250303-macOS14.6.1-gcc13.3.0-x86_64.tgz";
      sha256 = "sha256-Nd1EdqQtQ/nJfL2S29DSvwbyRQgnaO6XFuTA7GKrfOM=";
    };

    x86_64-darwin = {
      version = "22.1.0";
      url = "https://heasarc.gsfc.nasa.gov/FTP/xmm/software/sas/22.1.0/macOS/14.6/sas_22.1.0-a8f2c2afa-20250303-macOS14.6.1-gcc13.3.0-x86_64.tgz";
      sha256 = "sha256-Nd1EdqQtQ/nJfL2S29DSvwbyRQgnaO6XFuTA7GKrfOM=";
    };
  },
}:
{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      resolvedXmmsasSrc = xmmsasSrc.${system} or (throw "unsupported XMM-SAS system: ${system}");
    in
    {
      packages =
        let
          x86_64DarwinPkgs = import pkgs.path {
            system = "x86_64-darwin";
          };
          xlibs-x86 = pkgs.buildEnv {
            name = "xlibs";
            paths = with x86_64DarwinPkgs; [
              libX11
              libXt
              libXft
              libXmu
              libXext
              libXaw
              libXrender
              libXrandr
              libXcursor
              libXinerama
              libSM
              libICE
              freetype
              fontconfig.lib
            ];
          };
          curlGnuTls = pkgs.curl.override {
            gnutlsSupport = true;
            http3Support = false;
            opensslSupport = false;
          };
          cfitsioLib = lib.getLib pkgs.cfitsio;
          gccRuntimeLib = lib.getLib pkgs.stdenv.cc.cc;
          linuxRuntimeLibs = with pkgs; [
            libX11
            libXext
            libXft
            libXmu
            libXaw
            libXrender
            libXrandr
            libXcursor
            libXinerama
            libSM
            libICE
            freetype
            fontconfig.lib
            cfitsioLib
            (lib.getLib curlGnuTls)
            gccRuntimeLib
            zlib
          ];
        in
        {
          xmmsas = pkgs.stdenvNoCC.mkDerivation (finalAttrs: rec {
            version = resolvedXmmsasSrc.version;
            name = "xmmsas_${version}";
            src = (
              pkgs.fetchurl {
                inherit (resolvedXmmsasSrc) url sha256;
              }
            );
            nativeBuildInputs =
              with pkgs;
              [
                python312
                bash
                which
                file
              ]
              ++ lib.optionals pkgs.stdenv.isDarwin [
                cctools
              ]
              ++ lib.optionals (!pkgs.stdenv.isDarwin) [
                patchelf
              ];
            buildInputs =
              lib.optionals pkgs.stdenv.isDarwin [
                xlibs-x86
              ]
              ++ lib.optionals (!pkgs.stdenv.isDarwin) linuxRuntimeLibs;
            unpackPhase = ''
              tar -xvf $src
            '';
            postPatch = ''
              patchShebangs install.sh

              substituteInPlace install.sh \
                --replace-fail './configure_install' '${pkgs.bash}/bin/bash ./configure_install'
            '';
            installPhase = ''
              export SAS_PERL=${pkgs.perl}/bin/perl
              ./install.sh
              mkdir -p $out
              mv xmmsas_${version}*/* $out
            ''
            + ''
              mkdir -p $out/nix-support
              substitute ${./xmmsas-setup-hook.sh} $out/nix-support/setup-hook \
                --replace-fail '@xmmsas@' "$out"
            '';
            preFixup =
              if pkgs.stdenv.isDarwin then
                ''
                  find "$out" -type f | while read -r file; do
                    if file "$file" | grep -qE 'Mach-O.*(dynamically linked shared library|executable)'; then
                      if otool -L "$file" | grep -q "/opt/X11"; then
                        echo "Patching $file"
                        install_name_tool -add_rpath ${xlibs-x86}/lib "$file"
                        install_name_tool -change "/opt/X11/lib/libX11.6.dylib" "@rpath/libX11.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXt.6.dylib" "@rpath/libXt.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXft.2.dylib" "@rpath/libXft.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXmu.6.dylib" "@rpath/libXmu.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXext.6.dylib" "@rpath/libXext.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXaw.7.dylib" "@rpath/libXaw.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXrender.1.dylib" "@rpath/libXrender.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXrandr.2.dylib" "@rpath/libXrandr.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXcursor.1.dylib" "@rpath/libXcursor.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libXinerama.1.dylib" "@rpath/libXinerama.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libSM.6.dylib" "@rpath/libSM.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libICE.6.dylib" "@rpath/libICE.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libGL.1.dylib" "@rpath/libGL.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libfreetype.6.dylib" "@rpath/libfreetype.dylib" "$file"
                        install_name_tool -change "/opt/X11/lib/libfontconfig.1.dylib" "@rpath/libfontconfig.dylib" "$file"
                        if otool -L "$file" | grep -q "/opt/X11"; then
                          echo "Error: $file still has /opt/X11 in its dependencies"
                          exit 1
                        fi
                      fi
                    fi
                  done
                ''
              else
                ''
                  substituteInPlace "$out/sas-setup.sh" \
                    --replace-fail \
                      'LIBRARY_PATH=$SAS_DIR/libsys:$SAS_DIR/libextra:$LIBRARY_PATH' \
                      'LIBRARY_PATH=${cfitsioLib}/lib:$SAS_DIR/libsys:$SAS_DIR/libextra:$LIBRARY_PATH' \
                    --replace-fail \
                      'LD_LIBRARY_PATH=$SAS_DIR/libsys:$SAS_DIR/libextra:$LD_LIBRARY_PATH' \
                      'LD_LIBRARY_PATH=${cfitsioLib}/lib:$SAS_DIR/libsys:$SAS_DIR/libextra:$LD_LIBRARY_PATH'

                  for libdir in "$out/libsys" "$out/libextra"; do
                    if [ -d "$libdir" ]; then
                      find "$libdir" -maxdepth 1 -name 'libstdc++.so*' -delete
                    fi
                  done

                  while IFS= read -r -d "" file; do
                    if file "$file" | grep -qE 'ELF .*(shared object|executable)'; then
                      patchelf --set-rpath "$out/lib:${cfitsioLib}/lib:$out/libextra:${lib.makeLibraryPath linuxRuntimeLibs}" "$file"

                      if patchelf --print-interpreter "$file" >/dev/null 2>&1; then
                        patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$file"
                      fi
                    fi
                  done < <(find "$out" -type f -print0)
                '';
            dontBuild = true;
          });
        };
    };
}
