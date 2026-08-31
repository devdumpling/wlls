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
