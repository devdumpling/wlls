{
  description = "Development environment for wlls.dev";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
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
            buildPkgs.buildGoModule {
              pname = "wlls";
              version = "0.1.0";
              src = self;
              vendorHash = "sha256-1kqVqPirpgUb1XVlSb6JykwNKNgNldZzjb2cRMDyksM=";
              subPackages = [ "cmd/wlls" ];
              env.CGO_ENABLED = 0;
              ldflags = [
                "-s"
                "-w"
              ];
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
              # Application development.
              go
              gopls
              delve

              # Runtime and infrastructure.
              caddy
              sqlite
              terraform

              # Source control and deployment utilities.
              git
              openssh
              curl
              jq
              direnv
              shellcheck
            ];

            shellHook = ''
              # Keep Go toolchains and installed Go tools inside the project shell.
              export GOTOOLCHAIN=local
              export GOPATH="''${GOPATH:-$PWD/.go}"
              export GOBIN="$GOPATH/bin"
              export PATH="$GOBIN:$PATH"
            '';
          };
        }
      );
    };
}
