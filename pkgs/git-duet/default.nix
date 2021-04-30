{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "git-duet";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "git-duet";
    repo = "git-duet";
    # rev = version;
    rev = "ffae4ac"; # master has go mod supporto
    sha256 = "193vsdvvl8w6lqw4qlwyiamhidicwb54ir9nksyc7xps98wcy3jc";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "..." ];

  buildFlagsArray = ''
    -ldflags=
    -X main.VersionString=${version} -X main.RevisionString=ffae4ac
  '';

  meta = with lib; {
    description = "Support for pairing with git";
    homepage = "https://github.com/git-duet/git-duet";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
