{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "dyff";
  version = "1.4.5";

  src = fetchFromGitHub {
    owner = "homeport";
    repo = "dyff";
    rev = "v${version}";
    sha256 = "13hsrbm3napacck273azrsqnna4740sriiwgcgiw2h61jjbsv8ad";
  };

  vendorHash = "sha256-rWJT9/V6iqsWYhNfzOxlMyDHN7xb+4uM+aeCbjn3GMk=";

  doCheck = false;

  subPackages = [ "cmd/dyff" ];

  ldflags = [
    "-X github.com/homeport/dyff/internal/cmd.version=${version}"
  ];
  
  meta = with lib; {
    description = "/ˈdʏf/ - diff tool for YAML files, and sometimes JSON";
    homepage = "https://github.com/homeport/dyff";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
