{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "safe";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "starkandwayne";
    repo = "safe";
    rev =  "v${version}";
    sha256 = "0gy73xmg8crdymclxr5vxhg4qfnd42azxd0b279l6hxjxfw6s3m7";
  };

  vendorHash = "1pp8x9nzrb9jj82yinrb20yki90ygpxbl8d5s3cwjybrj4cq324s";

  doCheck = false;

  subPackages = [ "." ];

  ldflags = [
    "-X main.Version=${version}"
  ];

  meta = with lib; {
    description = "A Vault CLI";
    homepage = "https://github.com/starkandwayne/safe";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
