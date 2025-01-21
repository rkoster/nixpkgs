{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "bosh-bootloader";
  version = "9.0.29";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "bosh-bootloader";
    rev = "v${version}";
    sha256 = "sha256-lDUcfJ5HvvLjMisyhvIOrXoIkE2WyuUpFDVOP2R+G/o=";
    fetchSubmodules = true;
  };

  vendorHash = null;

  doCheck = false;

  ldflags = [
    "-X main.Version=v${version}"
  ];

  subPackages = [ "bbl" ];

  meta = with lib; {
    description = "Command line utility for standing up a BOSH director on an IAAS of your choice.";
    homepage = "https://github.com/cloudfoundry/bosh-bootloader";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
