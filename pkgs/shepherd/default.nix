{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "shepherd";
  version = "0.6.6";

  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:shepherd/shepherd2.git";
    ref = "main";
    rev = "dbda0ae5cc7873c3a98446d01d3598a8195732ce"; # 2.2.0
  };  

  vendorHash = "sha256-GpGP6z4GOVmnz3FZSSCTzZRTKCUnqiHXwB6McxFReis=";

  doCheck = false;

  ldflags = [
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.Version=${version}"
    "-X gitlab.eng.vmware.com/shepherd/shepherd2/client/cli/cmd.DefaultLocation=https://v2.shepherd.run"
  ];

  subPackages = [ "main.go" ];
  modRoot = "client/cli";

  postBuild = ''
     cd "$GOPATH/bin"
     mv main shepherd
  ''; 

  meta = with lib; {
    description = "shepherd: CLI for the Shepherd v2 environment management system";
    homepage = "https://gitlab.eng.vmware.com/shepherd/shepherd2/-/tree/main/documentation/public-docs";
    maintainers = with maintainers; [ rkoster ];
  };
}
