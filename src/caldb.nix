{
  caldbSrc ? {
    url = "https://heasarc.gsfc.nasa.gov/FTP/caldb/software/tools/caldb_setup_files.tar.Z";
    sha256 = "sha256-BflmrtcV6xX3XLN65vlJUsCPq/IYmUjEVJY8rAYZAco=";
  },
  caldbData ? [ ],
}:
_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
        caldb = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
          name = "caldb";

          src = pkgs.fetchurl {
            inherit (caldbSrc) url sha256;
          };

          data = map (
            source:
            pkgs.fetchurl {
              inherit (source) url sha256;
            }
          ) caldbData;

          installPhase = ''
            mkdir -p $out
            tar -xvzf ${finalAttrs.src} -C $out
          ''
          + builtins.concatStringsSep "\n" (
            map (source: ''
              tar -xvzf ${source} -C $out
            '') finalAttrs.data
          )
          + ''
            mkdir -p $out/nix-support
            substitute ${./caldb-setup-hook.sh} $out/nix-support/setup-hook \
              --replace-fail '@caldb@' "$out"
          '';

          dontUnpack = true;
          dontBuild = true;
          dontFixup = true;
        });
      };
    };
}
