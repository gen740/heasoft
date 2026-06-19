# heasoft-nix

Nix flake that packages the X-ray astronomy software stack as reproducible Nix
derivations:

| Package   | Upstream                              | Version (default) |
| --------- | ------------------------------------- | ----------------- |
| `heasoft` | NASA/GSFC HEASARC — HEASoft           | 6.36              |
| `xmmsas`  | ESA — XMM-Newton SAS                  | 22.1.0            |
| `caldb`   | NASA/GSFC HEASARC — CALDB setup files | —                 |

The flake builds the software from sources/binaries downloaded directly from the
official HEASARC/ESA servers. It does **not** redistribute that software — see
[License](#license) below.

## Supported systems

- `x86_64-linux`
- `aarch64-darwin`
- `x86_64-darwin`

> **Note:** HEASoft is built from source and the XMM-SAS binary tarballs are
> patched for the Nix store, so the first build can take a while.

## Usage

This is a [flake-parts](https://flake.parts) flake. It exposes the packaging
logic both as ready-to-import **flake modules** (`flake.flakeModules.*`) and as
**parameterised module functions** (`flake.mkFlakeModules.*`) that let you
override the upstream source (version / URL / hash).

### As packages

```console
$ nix build github:gen740/heasoft#heasoft
$ nix build github:gen740/heasoft#xmmsas
$ nix build github:gen740/heasoft#caldb
```

### Importing the flake modules into your own flake

```nix
{
  inputs.heasoft.url = "github:gen740/heasoft";

  outputs = inputs@{ flake-parts, heasoft, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        heasoft.flakeModules.heasoft
        heasoft.flakeModules.xmmsas
        heasoft.flakeModules.caldb
      ];

      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
    };
}
```

This adds `heasoft`, `xmmsas`, and `caldb` to `perSystem.packages`.

### Overriding the upstream source

Use `mkFlakeModules.*` to pin a different version, URL, or hash:

```nix
imports = [
  (heasoft.mkFlakeModules.heasoft {
    heasoftSrc = {
      version = "6.36";
      url = "https://heasarc.gsfc.nasa.gov/FTP/software/lheasoft/lheasoft6.36/heasoft-6.36src.tar.gz";
      sha256 = "sha256-9QkjHxyPqNyaqsPZDRRs5ogGUT1V/g8OHRZQjplUvos=";
    };
  })
];
```

`xmmsas.mkFlakeModules.xmmsas` takes a per-system `xmmsasSrc` attrset, and
`caldb.mkFlakeModules.caldb` accepts `caldbSrc` plus a `caldbData` list of
`{ url; sha256; }` calibration archives to unpack alongside the setup files.

## Environment setup

Each package ships a Nix setup hook, so adding it to a `devShell` (or any
environment that sources `nix-support/setup-hook`) configures the relevant
environment variables automatically:

- `heasoft` → exports `HEADAS` and sources `headas-init.sh`
- `xmmsas`  → exports `SAS_DIR` and sources `sas-setup.sh`
- `caldb`   → exports `CALDB` and sources `caldbinit.sh`

```nix
perSystem = { pkgs, config, ... }: {
  devShells.default = pkgs.mkShell {
    packages = [
      config.packages.heasoft
      config.packages.xmmsas
      config.packages.caldb
    ];
  };
};
```

Then:

```console
$ nix develop
$ fversion          # HEASoft (FTOOLS)
$ sasversion        # XMM-SAS
$ echo $CALDB       # CALDB root
```

## Repository layout

```
flake.nix                 # flake-parts entry point, wires the three modules
src/heasoft.nix           # HEASoft derivation (built from source)
src/xmmsas.nix            # XMM-SAS derivation (binary tarball, store-patched)
src/caldb.nix             # CALDB setup files (+ optional calibration data)
src/*-setup-hook.sh       # environment hooks (HEADAS / SAS_DIR / CALDB)
src/*.patch               # build fixes applied during the HEASoft build
```

## License

The **packaging code** in this repository (the Nix expressions, flake
definitions, setup hooks, and patches) is licensed under the
[MIT License](./LICENSE).

The MIT License covers **only** this packaging code. HEASoft, the CALDB setup
files, and XMM-Newton SAS are third-party software downloaded from their
official upstream servers at build time; they are **not** redistributed here and
are governed by their own licenses and terms of use. By building or installing
them through this flake you are obtaining them from their upstream distributor
and are responsible for complying with those terms. See the `SCOPE OF THIS
LICENSE / NOTICE ON THIRD-PARTY SOFTWARE` section in [LICENSE](./LICENSE) for the
upstream sources and license pointers.
