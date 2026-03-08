{
  description = "Solana RWA Bridge Dev Environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    # Apple Silicon Macを想定（Intel Macの場合は x86_64-darwin に変更してください）
    system = "aarch64-darwin"; 
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        rustup
        nodejs
        yarn
      ];
    };
  };
}