let
  pkgs = import <nixpkgs> {};
  src = ./.;
in pkgs.mkShell {
  buildInputs = with pkgs; [
    crystal
    shards
    pcre2
    xxHash
    gcc
    gnumake
  ];

  shellHook = ''
    export CRYSTAL_PATH="${toString src}"
    export CRYSTAL_CACHE_DIR="/tmp/.crystal"
    echo "Dev shell ready — run: shards install && crystal spec"
  '';
}
