{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "pinniped";
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "vmware-tanzu";
    repo = "pinniped";
    rev = "v${version}";
    sha256 = "sha256-FtIS8yKOjg4t5GehfNuaNZRidl4OAnvz+6kSemXXxh8=";
  };

  vendorHash = "sha256-N9+E8xHyUdZ3jZZxOjUrx0Dd8tT5TpN5KZNPBkqaWp0=";

  doCheck = false;

  ldflags = [
    "-X k8s.io/client-go/pkg/version.gitVersion=v${version}"
    "-X k8s.io/component-base/version.gitVersion=v${version}"
  ];

  subPackages = [ "cmd/..." ];

  meta = with lib; {
    description = "Pinniped is the easy, secure way to log in to your Kubernetes clusters.";
    homepage = "https://pinniped.dev";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
