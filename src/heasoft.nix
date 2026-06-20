{
  heasoftSrc ? {
    version = "6.36";
    url = "https://heasarc.gsfc.nasa.gov/FTP/software/lheasoft/lheasoft6.36/heasoft-6.36src.tar.gz";
    sha256 = "sha256-9QkjHxyPqNyaqsPZDRRs5ogGUT1V/g8OHRZQjplUvos=";
  },
}:
_: {
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = {
        heasoft = pkgs.stdenv.mkDerivation (
          finalAttrs:
          let
            heasoftPython = (
              pkgs.python3.withPackages (
                ps: with ps; [
                  setuptools
                  wheel
                  pip
                  astropy
                  scipy
                  matplotlib
                ]
              )
            );
            mergedXlibs = pkgs.buildEnv {
              name = "merged-xlibs";
              paths = with pkgs; [
                libX11.dev
                libX11
                libXt.dev
                libXt
              ];
            };

          in
          {
            pname = "heasoft";
            version = heasoftSrc.version;
            src = pkgs.fetchurl {
              url = heasoftSrc.url;
              sha256 = heasoftSrc.sha256;
            };
            hardeningDisable = [ "all" ];
            nativeBuildInputs = with pkgs; [
              which
              inetutils
              file
              ripgrep
              perl
              patchelf
            ];
            patches = [
              ./heasoftpy-install.patch
              ./xspec-model-copy-component-groups.patch
            ];
            buildInputs =
              with pkgs;
              [
                gcc
                gfortran
                curl.dev
                readline
                ncurses5
                heasoftPython
                tcsh
                tcl
                wget
                lynx
                xorgproto
                mergedXlibs
                libpng.dev
                openblas
              ]
              ++ (lib.optional (!stdenv.isDarwin) lsb-release);
            postPatch = ''
              substituteInPlace \
                ftools/guis/fitsTcl/configure.in \
                ftools/guis/fitsTcl/configure \
                --replace-fail "/usr/bin/curl-config" "curl-config"
              substituteInPlace BUILD_DIR/hwrap \
                --replace-fail '/bin/ls' 'ls'
              substituteInPlace swift/xrt/tasks/xrtpipeline/xrtpipeline \
                --replace-fail '/bin/cp' 'cp'
              substituteInPlace ftools/xselect/xselflib/xsel_utils.f \
                --replace-fail "'/bin/rm -f '" "'rm -f '" \
                --replace-fail "'/bin/mv \"'" "'mv \"'"
              substituteInPlace ftools/xselect/xselflib/xsel_unix.f \
                --replace-fail "'/bin/cp \"'" "'cp \"'" \
                --replace-fail "'/bin/rm -f '" "'rm -f '" \
                --replace-fail "'/bin/mv -f \"'" "'mv -f \"'" \
                --replace-fail "'/bin/cat '" "'cat '"
              substituteInPlace ftools/xselect/xselflib/xsel_unix_c.c \
                --replace-fail '"/bin/ls "' '"ls "'
              patchShebangs .
            '';
            makeFlags = [ "--no-print-directory" ];
            preConfigure = ''
              export PYTHON=${heasoftPython.interpreter}
              export FC=${pkgs.gfortran}/bin/gfortran
              export FCFLAGS="$FCFLAGS -O2 -w"
              export CFLAGS="$CFLAGS -O2 -I${pkgs.xorgproto}/include -w"
              export CXXFLAGS="$CXXFLAGS -O2 -std=c++14 -L${pkgs.libX11}/lib -w"
              export LDFLAGS="$LDFLAGS -L${mergedXlibs}/lib -L${lib.getLib pkgs.gfortran.cc}/lib -lgfortran -L${pkgs.openblas}/lib -lcblas"
              unset MACOSX_DEPLOYMENT_TARGET
              cd BUILD_DIR
            '';
            preBuild = ''
              export HOME=$(mktemp -d)
              export LC_ALL=C
              export LANG=C
              patchShebangs .
            '';
            postInstall = ''
              mkdir -p "$out/nix-support"

              headas="$(
                find "$out" -maxdepth 1 -type d \
                  \( -name 'aarch64*' -o -name 'x86_64*' \) \
                  | head -n 1
              )"

              if [ -z "$headas" ]; then
                echo "HEASoft HEADAS directory not found under $out" >&2
                exit 1
              fi

              headas_name="$(basename "$headas")"

              ln -s "$headas_name/bin" "$out/bin"

              substituteInPlace "$headas/BUILD_DIR/headas-setup" \
                --replace-fail 'HOST_NAME=`hostname`' 'HOST_NAME=`${pkgs.hostname}/bin/hostname`'
              substitute ${./heasoft-setup-hook.sh} "$out/nix-support/setup-hook" \
                --replace-fail '@heasoft@' "$headas"
            '';
            configureFlags = [
              "--x-includes=${mergedXlibs}/include"
              "--x-libraries=${mergedXlibs}/lib"
            ];
            preFixup = ''
              while IFS= read -r -d "" file; do
                if file "$file" | grep -qE 'ELF .*(shared object|executable)'; then
                  rpath="$(patchelf --print-rpath "$file" 2>/dev/null || true)"

                  if echo "$rpath" | grep -q '/build/'; then
                    echo "Removing /build reference from RPATH: $file"
                    new_rpath="$(
                      echo "$rpath" \
                        | tr ':' '\n' \
                        | grep -v '/build/' \
                        | paste -sd: - \
                        || true
                    )"
                    patchelf --set-rpath "$new_rpath" "$file"
                  fi
                fi
              done < <(find "$out" -type f -print0)
            '';
            meta = {
              description = "Unified release of HEASARC's FTOOLS, XANADU (XSPEC/Xronos/Ximage) and FITSIO software";
              homepage = "https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/";
              # HEASoft is freely available but is fetched from upstream at build
              # time, not redistributed by this flake; its components carry their
              # own terms. See the LICENSE file in this repository for details.
              license = lib.licenses.free;
              sourceProvenance = [ lib.sourceTypes.fromSource ];
              platforms = [
                "x86_64-linux"
                "aarch64-darwin"
                "x86_64-darwin"
              ];
            };
          }
        );
      };
    };
}
