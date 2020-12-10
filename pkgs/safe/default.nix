{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "safe";
  version = "1.5.8";

  src = fetchFromGitHub {
    owner = "starkandwayne";
    repo = "safe";
    rev =  "v${version}";
    sha256 = "1i13r05x7jj5n5gfh8w64yl5bhg8vgb2wmzyf1hh7rhj926374vm";
  };

  vendorSha256 = "0w6lanp8dnnzg2c4xvpa6lwi4dkqx28lf1fzc2dizgr4jah0jgb3";

  doCheck = false;

  subPackages = [ "." ];

  buildFlagsArray = ''
    -ldflags=
    -X main.Version=${version}
  '';

  meta = with lib; {
    description = "A Vault CLI";
    homepage = "https://github.com/starkandwayne/safe";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
