{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "uaa";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry-incubator";
    repo = "uaa-cli";
    rev = "${version}";
    sha256 = "0n408mwz5w5ahx5dbz351hnn38ggykgcbc7n08f5m33cc88rxckj";
  };

  vendorSha256 = "06gzri7gckna9q9ab9hq8rm8dk0ggmsx74pyjd3cp2ywzscf5ldr";

  doCheck = false;

  subPackages = [ "main.go" ];

  buildFlagsArray = ''
    -ldflags=
    -X code.cloudfoundry.org/uaa-cli/version.Version=${version}
     -X code.cloudfoundry.org/uaa-cli/version.Commit=nix"
  '';

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
