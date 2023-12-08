{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "peribolos";
  version = "bdd4da5";

  src = fetchFromGitHub {
    owner = "kubernetes";
    repo = "test-infra";
    rev = version;
    sha256 = "1rc1hhmwx79q078fi2qgihf60px8x8d89racvgfdkbw9yk5fkq0y";
  };

  vendorHash = "0rm469hmbm2mqbj7b9w28kmy6s3qjbsw3r4gvq30wwdp2l2lg1j6";

  doCheck = false;

  subPackages = [ "prow/cmd/peribolos/main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main peribolos
  ''; 

  meta = with lib; {
    description = ''
      Peribolos allows the org settings, teams and memberships to 
      be declared in a yaml file. GitHub is then updated to match the declared configuration.
    '';
    homepage = "https://github.com/kubernetes/test-infra/blob/master/prow/cmd/peribolos/README.md";
    license = licenses.asl20;
    maintainers = with maintainers; [ rkoster ];
  };
}
