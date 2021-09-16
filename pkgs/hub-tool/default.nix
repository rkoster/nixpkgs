{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "hub-tool";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "docker";
    repo = "hub-tool";
    rev = "v${version}";
    sha256 = "1y9ih2rgpypj8kwsclw9yg5m4vjzsl7ipwnmqfc7ywimd7q12ssb";
  };

  vendorSha256 = "0rdppbjvy05f175sz3brpzhx2br5vsgn6cn3p0idrk5xrapbyv15";

  doCheck = false;

  buildFlagsArray = ''
    -ldflags=
    -X github.com/docker/hub-tool/internal.Version=${version}
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main hub-tool
  ''; 

  meta = with lib; {
    description = "Docker Hub experimental CLI tool";
    homepage = "https://github.com/docker/hub-tool";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
