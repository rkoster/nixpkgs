{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "nsc";
  version = "2.6.1";

  src = fetchFromGitHub {
    owner = "nats-io";
    repo = "nsc";
    rev = version;
    sha256 = "sha256-I1RV0as+MgxuREYtljWSFvTxaUDx+WxR/6utA5FymmA=";
  };

  vendorHash = null;

  doCheck = false;

  ldflags = "-s -w -X main.version=v${version}";

  meta = with lib; {
    description = "Tool for creating nkey/jwt based configurations";
    homepage = "https://github.com/nats-io/nsc";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
