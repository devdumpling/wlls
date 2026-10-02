{
  description = "Development environment for wlls.dev";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    tempo-src = {
      url = "github:kalsprite/tempo/9ed296f1f98340bffa9cd237e0403b1e0963a9ae";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      tempo-src,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
      # Mirrors odin_defines in the justfile, with Tina's assertions off.
      releaseDefines = "-define:HTTP_EGRESS_BUFFER_SIZE=16384 -define:TINA_ASSERTS=false";
      packagesFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "terraform" ];
        }
      );
      mkTempo =
        pkgs:
        pkgs.stdenv.mkDerivation {
          pname = "odin-tempo";
          version = "9ed296f";
          src = tempo-src;
          patches = [ ./patches/tempo-core-os.patch ];
          nativeBuildInputs = [ pkgs.odin ];
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            odin build src -out:tempo
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/bin"
            install -m 0755 tempo "$out/bin/tempo"
            runHook postInstall
          '';
        };
    in
    {
      formatter = forAllSystems (system: packagesFor.${system}.nixfmt);

      packages = forAllSystems (
        system:
        let
          pkgs = packagesFor.${system};
          linuxPkgs = if system == "x86_64-linux" then pkgs else pkgs.pkgsCross.gnu64;
          tempo = mkTempo pkgs;
          mkWlls =
            buildPkgs:
            let
              cross = buildPkgs.stdenv.buildPlatform != buildPkgs.stdenv.hostPlatform;
              # SQLite's optional Tcl extension needs Tcl built for the target,
              # which doesn't cross-compile from macOS. The app only needs the
              # C library, so cross builds turn the extension off (as nixpkgs
              # does for static builds).
              sqlite =
                if cross then
                  buildPkgs.sqlite.overrideAttrs (old: {
                    configureFlags = map (
                      flag: if nixpkgs.lib.hasPrefix "--with-tcl=" flag then "--disable-tcl" else flag
                    ) old.configureFlags;
                  })
                else
                  buildPkgs.sqlite;
              # C libraries the app binds with `foreign import`.
              nativeLibs = "-L${buildPkgs.cmark-gfm}/lib -L${sqlite.out}/lib";
            in
            buildPkgs.stdenv.mkDerivation {
              pname = "wlls";
              version = "0.1.0";
              src = self;
              nativeBuildInputs = [
                buildPkgs.buildPackages.odin
                buildPkgs.buildPackages.removeReferencesTo
                tempo
              ];
              buildInputs = [ buildPkgs.cmark-gfm sqlite ];
              dontConfigure = true;

              buildPhase = ''
                runHook preBuild
                tempo generate src/views -runtime=tempo:runtime
                ${
                  if cross then
                    ''
                      odin build src -collection:tempo=${tempo-src} -extra-linker-flags:"${nativeLibs}" -target:linux_amd64 -build-mode:obj -out:wlls.obj -o:speed ${releaseDefines} -thread-count:1
                      $CC wlls.obj -o wlls ${nativeLibs} -lcmark-gfm-extensions -lcmark-gfm -lsqlite3 -lm -ldl -pthread
                    ''
                  else
                    ''odin build src -collection:tempo=${tempo-src} -extra-linker-flags:"${nativeLibs}" -out:wlls -o:speed ${releaseDefines} -thread-count:1''
                }
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall
                mkdir -p "$out/bin"
                install -m 0755 wlls "$out/bin/wlls"
                # Source locations embedded for panics and bounds checks would
                # otherwise pull the compiler and its sources into the runtime.
                remove-references-to \
                  -t ${buildPkgs.buildPackages.odin} \
                  -t ${tempo-src} \
                  "$out/bin/wlls"
                runHook postInstall
              '';
            };
          wlls = mkWlls pkgs;
          wllsLinuxAmd64 = mkWlls linuxPkgs;
        in
        {
          default = wlls;
          inherit wlls;
          runtime = pkgs.symlinkJoin {
            name = "wlls-runtime";
            paths = [
              wlls
              pkgs.caddy
            ];
          };
          runtime-linux-amd64 = linuxPkgs.symlinkJoin {
            name = "wlls-runtime-linux-amd64";
            paths = [
              wllsLinuxAmd64
              linuxPkgs.caddy
            ];
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = packagesFor.${system};
          tempo = mkTempo pkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [ tempo pkgs.cmark-gfm ] ++ (with pkgs; [
              # Application development (pinned by flake.lock).
              odin
              just

              # Runtime and infrastructure.
              caddy
              sqlite
              terraform

              # Source control and deployment utilities.
              git
              openssh
              curl
              jq
              lsof
              direnv
              shellcheck
            ]);
            shellHook = ''
              export TEMPO_SRC=${tempo-src}
              export CMARK_GFM_LIB=${pkgs.cmark-gfm}/lib
              export SQLITE_LIB=${pkgs.sqlite.out}/lib
            '';
          };
        }
      );
    };
}
