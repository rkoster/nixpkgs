{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "vendir";
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "vmware-tanzu";
    repo = "carvel-vendir";
    rev = "v${version}";
    sha256 = "1mbh4zp9d8hia962fg84y25y4qb9zkln4fk1fcygflrvac0yvb02";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "cmd/vendir" ];

  meta = with lib; {
    description = "Easy way to vendor portions of git repos, github releases, helm charts, docker image contents, etc. declaratively";
    homepage = "https://carvel.dev/";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
