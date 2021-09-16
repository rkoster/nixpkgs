{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "om";
  version = "7.3.0";

  src = fetchFromGitHub {
    owner = "pivotal-cf";
    repo = "om";
    rev = version;
    sha256 = "1cq7gcwc0q18gbn3jgxfsxlcnfaj1p12gf2p3ia7pj49qy5sl17m";
  };

  vendorSha256 = "0v06gkyys640zni2jdh72wxx7ivi67hyvi4lsy68phmcyc33djss";

  doCheck = false;

  preBuild = ''
    sed 's/unknown/'"${version}-nix"'/' main.go > main.tmp && mv main{.tmp,.go}
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main om
  ''; 

  meta = with lib; {
    description = "General command line utility for working with VMware Tanzu Operations Manager";
    homepage = "https://github.com/pivotal-cf/om";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
