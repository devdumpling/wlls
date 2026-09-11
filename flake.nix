{
  description = "Development environment for wlls.dev";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Change the ref below to use another Odin tag/branch, e.g.:
    #   github:odin-lang/Odin/dev-2026-06
    #   github:odin-lang/Odin/master
    # odin-src = {
    #   url = "github:odin-lang/Odin/dev-2026-06";
    #   flake = false;
    # };
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
            buildPkgs.buildGoModule {
              pname = "wlls";
              version = "0.1.0";
              src = self;
              vendorHash = "sha256-Jr3sTnyz1qixLtoB3wvsQ7SRUK0D9vMb5qHFxOUefyA=";
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
              # Application developmodinent.
              odin

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
          };
        }
      );
    };
}
