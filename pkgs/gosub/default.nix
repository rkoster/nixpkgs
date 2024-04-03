{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "gosub";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "vito";
    repo = "gosub";
    rev = "master";
    sha256 = "sha256-E34X70kFEWcfxNbREU5vY+4ETtecNEi+0VTumC5pNyk=";
  };

  vendorHash = "sha256-fqNzpgcD7hjpZzXPC+qXSZNQO/89YXo/ttABA02/2Qs=";

  doCheck = false;

  meta = with lib; {
    description = "go dependency submodule automator";
    homepage = "https://github.com/vito/gosub";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
