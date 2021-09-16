{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh";
  version = "6.4.6";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-cli";
    rev = "v${version}";
    sha256 = "1r1i94174mmbgydjnrfwrahgnl820m22117x9474sbxv521krlrh";
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
