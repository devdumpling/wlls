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
            in
            buildPkgs.stdenv.mkDerivation {
              pname = "wlls";
              version = "0.1.0";
              src = self;
              nativeBuildInputs = [ buildPkgs.buildPackages.odin tempo ];
              buildInputs = [ buildPkgs.cmark-gfm ];
              dontConfigure = true;

              buildPhase = ''
                runHook preBuild
                tempo generate src/views -runtime=tempo:runtime
                ${
                  if cross then
                    ''
                      odin build src -collection:tempo=${tempo-src} -extra-linker-flags:"-L${buildPkgs.cmark-gfm}/lib" -target:linux_amd64 -build-mode:obj -out:wlls.obj -o:speed -define:TINA_ASSERTS=false -thread-count:1
                      $CC wlls.obj -o wlls -L${buildPkgs.cmark-gfm}/lib -lcmark-gfm-extensions -lcmark-gfm -lm -ldl -pthread
                    ''
                  else
                    ''odin build src -collection:tempo=${tempo-src} -extra-linker-flags:"-L${buildPkgs.cmark-gfm}/lib" -out:wlls -o:speed -define:TINA_ASSERTS=false -thread-count:1''
                }
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall
                mkdir -p "$out/bin"
                install -m 0755 wlls "$out/bin/wlls"
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
            '';
          };
        }
      );
    };
}
