{ buildGo122Module, fetchFromGitHub, stdenv, lib, writeText }:

buildGo122Module rec {
  pname = "cf";
  version = "8.7.10";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "cli";
    rev = "v${version}";
    sha256 = "sha256-hzXNaaL6CLVRIy88lCJ87q0V6A+ld1GPDcUagsvMXY0=";
  };

  vendorHash = "sha256-zDE+9OsnX3S7SPTVW3hR1rO++6Wdk00zy2msu+jUNlw=";

  doCheck = false;

  subPackages = [ "." ];

  ldflags = [
    "-X code.cloudfoundry.org/cli/version.binaryVersion=${version}"
  ];

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
