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

  vendorSha256 = "0hnq87ds4aijrgr01rbgvyblw4jbvwdli125pyprry6gpyscbgfw";

  doCheck = false;

  subPackages = [ "cmd/dyff" ];

  buildFlagsArray = ''
    -ldflags=
    -X github.com/homeport/dyff/internal/cmd.version=${version}
  '';
  
  meta = with lib; {
    description = "/ˈdʏf/ - diff tool for YAML files, and sometimes JSON";
    homepage = "https://github.com/homeport/dyff";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
