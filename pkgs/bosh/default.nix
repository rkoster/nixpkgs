{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh";
  version = "6.4.17";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-cli";
    rev = "v${version}";
    sha256 = "sha256-oVL7tBtdFJt6ktctSZiNZMd6g1LEWQ/Hra4rcGM6BnQ=";
  };

  vendorSha256 = null;

  doCheck = false;

  preBuild = ''
    sed 's/\[DEV BUILD\]/'"${version}-nix"'/' cmd/version.go > cmd/version.tmp && mv cmd/version{.tmp,.go}
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main bosh
  ''; 

  meta = with lib; {
    description = "BOSH CLI v2+";
    homepage = "https://github.com/cloudfoundry/bosh-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
