{ buildGo123Module, fetchFromGitHub, stdenv, lib, writeText }:

buildGo123Module rec {
  pname = "sheepctl";
  version = "0.26.7";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/shepherd.git";
    ref = "main";
    rev = "9732d1cf03d17cf616433343212b4d4e96d20ea8"; # v0.26.7-cli
  };

  vendorHash = "sha256-y9l950l/OLvFLHXspt0v8tn4yz/UmoUeUUnvr0TmOQ8=";

  doCheck = false;

  subPackages = [ "cli" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv cli sheepctl
  '';

  meta = with lib; {
    description = "sheepctl: CLI for the Shepherd v1 environment management system";
    homepage = "http://docs.shepherd.run/";
    maintainers = with maintainers; [ rkoster ];
  };
}
