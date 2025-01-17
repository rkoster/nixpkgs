{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText, pkgs }:

buildGoModule rec {
  pname = "tanzu-sm-installer";
  version = "v10.1.0-jan-2025-rc.492-v488942c";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/ensemble-self-managed.git";
    ref = "master";
    rev = "488942c647b5b0ac2e2982f77df12949764e7414"; # release-tpsm-jan-2025-test-rc
  };

  vendorHash = "sha256-kpPdr5yATMa8dytm+wGINWS9/88gBoP32XlVimyr/uI=";

  doCheck = false;

  ldflags = [
    "-X github.com/vmware-tanzu/tanzu-plugin-runtime/plugin/buildinfo.Version=${version}"
  ];

  preBuild = ''
    cp ../carvel-packages/hub-self-managed/config/schema.yml pkg/install/resources/config
    cp ../config.yaml pkg/install/resources/config
    ${pkgs.ytt}/bin/ytt -f ../carvel-packages/hub-self-managed/config/schema.yml \
      --data-values-schema-inspect --output openapi-v3 > pkg/install/resources/config/openapi-schema.yml
  '';

  subPackages = [ "cmd/plugin/tanzu-sm-installer" ];
  modRoot = "installer";

  # postBuild = ''
  #    cd "$GOPATH/bin"
  #    mv main shepherd
  # ''; [

  meta = with lib; {
    description = "Tanzu Platform Self Managed Installer CLI";
    homepage = "https://github.gwd.broadcom.net/TNZ/ensemble-self-managed/tree/master/installer";
    maintainers = with maintainers; [ rkoster ];
  };
}
