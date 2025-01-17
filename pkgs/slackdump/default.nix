{ buildGo122Module, fetchFromGitHub, installShellFiles, stdenv, lib, writeText }:

buildGo122Module rec {
  pname = "slackdump";
  version = "2.5.11";

  src = fetchFromGitHub {
    owner = "rusq";
    repo = "slackdump";
    # rev = "v${version}";
    rev = "cafaee525acf22e20a33b3ec7336912fbf88c10d"; # master
    sha256 = "sha256-2Gpn1kJfr+Bwaid2/Ko4j7kn7aKoP2gv4z9IikZktkg=";
  };

  vendorHash = "sha256-hf0lvuVpji+hkOywfrBOpXywr/AiTUTQBlkQWaJu36E=";

  ldflags = [
    "-X main.build=${version}"
  ];

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [ "cmd/slackdump" ];

  meta = with lib; {
    description = "Save or export your private and public Slack messages, threads, files, and users locally without admin privileges.";
    homepage = "https://github.com/rusq/slackdump";
    license = licenses.gpl3;
    maintainers = with maintainers; [ rkoster ];
  };
}
