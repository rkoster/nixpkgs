{ buildGo123Module, fetchFromGitHub, stdenv, lib, writeText }:

buildGo123Module rec {
  pname = "cf";
  version = "8.11.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "cli";
    rev = "v${version}";
    sha256 = "sha256-1OJWkhXw/VYerQgaYFgX6mPIAtD3GKDhI+/a8TJS5Yg=";
  };

  vendorHash = "sha256-c0RThHxnT/OU+sFZlACKoFYmFM1P3XItvF0XiGKBVZ8=";

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
