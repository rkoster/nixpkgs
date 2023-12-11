{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh";
  version = "7.5.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-cli";
    rev = "v${version}";
    sha256 = "sha256-LWfS722V0ubh4QaUNuGwrvFsVAzA9Hd5xLlDfTG0PBs=";
  };

  vendorHash = null;

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
