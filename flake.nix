{
  description = "Mykyta Nikitenko's CV — vendored, self-contained HTML → PDF";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.just
          pkgs.chromium
          pkgs.nodePackages.tailwindcss
          pkgs.python3
          pkgs.poppler_utils
          pkgs.qpdf
        ];
      };
    };
}
