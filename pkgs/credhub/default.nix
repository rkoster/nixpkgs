{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "credhub";
  version = "2.9.7";

  src = fetchFromGitHub {
    owner = "cloudfoundry-incubator";
    repo = "credhub-cli";
    rev = version;
    sha256 = "sha256-7C6lx1AEUnfwsK9pq/iKjTg/n4RGsW2F3YKRbroaMt4=";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main credhub
  ''; 

  meta = with lib; {
    description = "CredHub CLI provides a command line interface to interact with CredHub servers";
    homepage = "https://github.com/cloudfoundry-incubator/credhub-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
