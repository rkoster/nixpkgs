{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "shepherd";
  version = "0.7.6";

  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:shepherd/shepherd2.git";
    ref = "main";
    rev = "1388fdf71dff41f258ee40d257cdd88ab840f76e"; # 0.7.6
  };  

  vendorHash = "sha256-Kq1Dgt61q2C933GzzjHP7QRx4lD7dqz7embnSBTItxU=";

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
