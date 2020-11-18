{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "cf";
  version = "6.53.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "cli";
    rev = "f4eef72"; # "v${version}";
    sha256 = "0g7ripvyg89f831bvc53svhaw4ck3xclkcz93hc2rlfy0029mr1k";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "." ];

  buildFlagsArray = ''
    -ldflags=
    -X code.cloudfoundry.org/cli/version.binaryVersion=${version}
  '';

  postBuild = ''
     cd "$GOPATH/bin"
     mv cli cf
  ''; 

  meta = with lib; {
    description = "The official command line client for Cloud Foundry";
    homepage = "https://github.com/cloudfoundry/cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
