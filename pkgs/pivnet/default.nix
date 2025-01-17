{ buildGoModule, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "pivnet";
  version = "4.1.1";

  src = fetchFromGitHub {
    owner = "pivotal-cf";
    repo = "pivnet-cli";
    rev = "v${version}";
    sha256 = "sha256-HmkTDHBayulGpgGdjK/HLgtdKT27ilaoeJ63JUjMOqs=";
  };

  vendorHash = "sha256-Z4Re42XnviVuycrJIClx+V0qVNOFJez3fKfca+plcMc=";

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  ldflags = [
   "-X github.com/pivotal-cf/pivnet-cli/v3/version.Version=${version}"
  ];

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main pivnet
  '';

  meta = with lib; {
    description = "CLI to interact with Tanzu Network API V2 interface.";
    homepage = "https://github.com/pivotal-cf/pivnet-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
