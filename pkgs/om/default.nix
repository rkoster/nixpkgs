{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "om";
  version = "7.8.2";

  src = fetchFromGitHub {
    owner = "pivotal-cf";
    repo = "om";
    rev = version;
    sha256 = "sha256-2Zy9kF0dmUBJOELMwxfID5zn1McMy/g8oEVHeJEJbCg=";
  };

  vendorHash = "sha256-SFrRgW15bbG+pt7clDFIqgYvxhgvtIN14lWm3IiZQk4=";

  doCheck = false;

  # preBuild = ''
  #   sed 's/unknown/'"${version}-nix"'/' main.go > main.tmp && mv main{.tmp,.go}
  # '';

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
