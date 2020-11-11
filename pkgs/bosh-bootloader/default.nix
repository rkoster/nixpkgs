{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh-bootloader";
  version = "8.4.1";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-bootloader";
    rev = "v${version}";
    sha256 = "19xr608q9w0sjwi7xagpami9b0x9kwpc78p8d83wfj3l82xd4xkd";
  };

  vendorSha256 = null;

  doCheck = false;

  buildFlagsArray = ''
    -ldflags=
      -X main.Version=v${version}"
  '';

  preBuild = ''
    go mod init github.com/cloudfoundry/bosh-bootloader
  '';

  subPackages = [ "bbl" ];

  # postBuild = ''
  #    cd "$GOPATH/bin"
  #    mv main bosh
  # ''; 

  meta = with lib; {
    description = "Command line utility for standing up a BOSH director on an IAAS of your choice.";
    homepage = "https://github.com/cloudfoundry/bosh-bootloader";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
