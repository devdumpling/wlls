{
  description = "Development environment for wlls.dev";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
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
    in
    {
      formatter = forAllSystems (system: packagesFor.${system}.nixfmt);

      packages = forAllSystems (
        system:
        let
          pkgs = packagesFor.${system};
          linuxPkgs = if system == "x86_64-linux" then pkgs else pkgs.pkgsCross.gnu64;
          mkWlls =
            buildPkgs:
            let
              cross = buildPkgs.stdenv.buildPlatform != buildPkgs.stdenv.hostPlatform;
            in
            buildPkgs.stdenv.mkDerivation {
              pname = "wlls";
              version = "0.1.0";
              src = self;
              nativeBuildInputs = [ buildPkgs.buildPackages.odin ];
              dontConfigure = true;

              buildPhase = ''
                runHook preBuild
                ${
                  if cross then
                    ''
                      odin build src -target:linux_amd64 -build-mode:obj -out:wlls.obj -o:speed -define:TINA_ASSERTS=false
                      $CC wlls.obj -o wlls -lm -ldl -pthread
                    ''
                  else
                    ''odin build src -out:wlls -o:speed -define:TINA_ASSERTS=false''
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
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
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
            ];
          };
        }
      );
    };
}
