{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "gh";
  version = "2.7.0";

  src = fetchFromGitHub {
    owner = "cli";
    repo = "cli";
    rev = "v${version}";
    sha256 = "sha256-edlGJD+80k1ySpyNcKc5c2O0MX+S4fQgH5mwHQUxXM8=";
  };

  vendorSha256 = "sha256-YLkNua0Pz0gVIYnWOzOlV5RuLBaoZ4l7l1Pf4QIfUVQ=";

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
