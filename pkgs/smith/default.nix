{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "smith";
  version = "2.9.0";

  # use fetchGit since it supports using ssh private keys for auth
  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/smith.git";
    ref = "main";
    rev = "7f4bca2dc48b40bd54e1a780b152579b3fc57768"; # v2.9.0
  };

  vendorHash = "sha256-cCi6S0VSRJKl2jchL85nSTQhUzXuJOX+KuLnBrpD5i8=";

  doCheck = false;

  preBuild = ''
    sed 's/go 1.23.*/go 1.22.0/g' go.mod > go.mod.tmp && mv go.mod{.tmp,}
    sed 's/development build/'"${version}-nix"'/' main.go > main.tmp && mv main{.tmp,.go}
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main smith
  ''; 

  meta = with lib; {
    description = "The community CLI for Toolsmiths";
    homepage = "https://environments.toolsmiths.cf-app.com";
    maintainers = with maintainers; [ rkoster ];
  };
}
