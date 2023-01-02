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

  vendorSha256 = "sha256-LOykebwL3pKJQoZ/iJHQhE8Hfrp263FvkpLtZWfdnr4=";

  doCheck = false;

  ldflags = "-X github.com/cloudfoundry/cloud-service-broker/utils.Version=${version}";

  meta = with lib; {
    description = "OSBAPI service broker that uses Terraform to provision and bind services.";
    homepage = "https://github.com/cloudfoundry/cloud-service-broker";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
