{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "spruce";
  version = "1.27.0";

  src = fetchFromGitHub {
    owner = "geofffranks";
    repo = "spruce";
    rev =  "v${version}";
    sha256 = "01zg44zf77k63rl9jf2ckjnbzv166v0x1p08x77vg9ckkfr6ldmz";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "./cmd/spruce" ];

  preBuild = ''
    unset GOPROXY
    go mod tidy
    go mod vendor
  '';

  buildFlagsArray = ''
    -ldflags=
    -X main.Version=${version}
  '';

  meta = with lib; {
    description = "A BOSH template merge tool";
    homepage = "https://github.com/geofffranks/spruce";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
