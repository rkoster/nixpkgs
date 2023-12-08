{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "csb";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "cloudfoundry";
    repo = "cloud-service-broker";
    rev = "v${version}";
    sha256 = "sha256-wrZzXq4coWYYePQoiTcLODzdclvK6TuefI17CuyLvMk=";
  };

  vendorHash = "sha256-LOykebwL3pKJQoZ/iJHQhE8Hfrp263FvkpLtZWfdnr4=";

  doCheck = false;

  preBuild = ''
    sed 's/30*time.Second/2*time.Second/' pkg/client/example_runner.go > pkg/client/example_runner.tmp && mv pkg/client/example_runner{.tmp,.go}
  '';

  ldflags = "-X github.com/cloudfoundry/cloud-service-broker/utils.Version=${version}";

  postBuild = ''
     cd "$GOPATH/bin"
     mv cloud-service-broker csb
  '';

  meta = with lib; {
    description = "OSBAPI service broker that uses Terraform to provision and bind services.";
    homepage = "https://github.com/cloudfoundry/cloud-service-broker";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
