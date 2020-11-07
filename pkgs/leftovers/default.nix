{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "lefovers";
  version = "0.62.0";

  src = fetchFromGitHub {
    owner = "genevieve";
    repo = "leftovers";
    rev = "v${version}";
    sha256 = "19q8lq5rw4ab6m2lh9r31zswvl8jjkzr74axq6dfl1y4licbc3kq";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "cmd/leftovers" ];

  buildFlagsArray = ''
    -ldflags=
      -X main.Version=v${version}"
  '';

  meta = with lib; {
    description = "Go cli & library for cleaning up orphaned IAAS resources.";
    homepage = "https://github.com/genevieve/leftovers";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
