{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "gh";
  version = "1.8.1";

  src = fetchFromGitHub {
    owner = "cli";
    repo = "cli";
    rev = "v${version}";
    sha256 = "1q0vc9wr4n813mxkf7jjj3prw1n7xv4l985qd57pg4a2js1dqa1y";
  };

  vendorSha256 = "1wv30z0jg195nkpz3rwvhixyw81lg2wzwwajq9g6s3rfjj8gs9v2";

  doCheck = false;

  subPackages = [ "cmd/gh" ];

  buildFlagsArray = ''
    -ldflags=
    -X github.com/cli/cli/internal/build.Version=${version}
  '';

  meta = with lib; {
    description = "GitHub’s official command line tool";
    homepage = "https://cli.github.com";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
