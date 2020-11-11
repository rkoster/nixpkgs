{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "ytt";
  version = "0.30.0";

  src = fetchFromGitHub {
    owner = "k14s";
    repo = "ytt";
    rev = "v${version}";
    sha256 = "0v9wp15aj4r7wif8i897zwj3c6bg41b95kk7vi3a3bzin814qn6l";
  };

  vendorSha256 = null;

  doCheck = false;

  subPackages = [ "cmd/ytt" ];

  meta = with lib; {
    description = "YAML templating tool that works on YAML structure instead of text";
    homepage = "https://github.com/k14s/ytt";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
