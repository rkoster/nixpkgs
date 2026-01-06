{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "cloud-provider-kind";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "cloud-provider-kind";
    rev = "v${version}";
    sha256 = "sha256-CB4Qo8fwAwOLuYzN+AmFtaZtlK0CMT2cZVAl9JboP8g=";
  };

  vendorHash = null;

  doCheck = false;

  meta = with lib; {
    description = "Cloud provider for KIND clusters";
    homepage = "https://github.com/kubernetes-sigs/cloud-provider-kind";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
