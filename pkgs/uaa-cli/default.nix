{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "uaa";
  version = "0.13.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "uaa-cli";
    rev = "${version}";
    sha256 = "sha256-0otJqWBesKzZ83A+N348kZmoDJSAJKcYTaEsiz3vjbg=";
  };

  vendorHash = "sha256-QKI0trOROhFH5DgyP8Io1h/AsoWbgTJF8/c2eXyClHI=";

  doCheck = false;

  subPackages = [ "main.go" ];

  ldflags = [
    "-X code.cloudfoundry.org/uaa-cli/version.Version=${version}"
    "-X code.cloudfoundry.org/uaa-cli/version.Commit=nix"
  ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main uaa
  ''; 

  meta = with lib; {
    description = "CLI for UAA written in Go";
    homepage = "https://github.com/cloudfoundry-incubator/uaa-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
