{ buildGoModule, stdenv, lib, writeText, pkgs }:


buildGoModule rec {
  pname = "srpcli";
  version = "0.7.5";

  src = builtins.fetchGit {
    url = "git@gitlab.eng.vmware.com:srp/helix/core/cli/srpcli.git";
    ref = "main";
    rev = "6ff5e40f85e626bec36b8989f051c353025e9ed0"; # 0.7.12
  };

  #  vendorSha256 = "0cnn964g4qkr7jxjp5chzrvq2qx4fk98m0jcgfs5ryxycc68x386";
  vendorSha256 = lib.fakeSha256;

  doCheck = false;

  subPackages = [ "srpcli.go" ];

  buildInputs = [
    pkgs.openssh
  ];

  overrideModAttrs = old: {
    preBuild = ''
      export HOME=$TMPDIR
      # git config --global \
			# 	url.ssh://git@gitlab.eng.vmware.com/.insteadOf \
			#	https://gitlab.eng.vmware.com/
			git config --global \
				url.git@gitlab.eng.vmware.com/.insteadOf \
				https://gitlab.eng.vmware.com/

      export CGO_ENABLED=0
      export GOPRIVATE="gitlab.eng.vmware.com/*"
      export GOPROXY=https://build-artifactory.eng.vmware.com/artifactory/proxy-golang-remote
      export GOSUMDB="sum.golang.org https://build-artifactory.eng.vmware.com/artifactory/go-gosumdb-remote"

      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -vv -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

      IFS=$'\n'
      for dep in $(cat go.mod | grep -P '\tgitlab.eng' | cut -f2); do
          version=$(echo "$dep" | cut -d' ' -f2)
          repo=$(echo "$dep" | cut -d' ' -f1)
          go mod edit -replace "$repo=$repo.git@$version"
          cat go.sum | sed "s@$repo@$repo.git@g" > go.sum.tmp
          mv go.sum.tmp go.sum
      done

      export GIT_CURL_VERBOSE=1
      export GIT_TRACE=1
      '';
    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND" "SOCKS_SERVER" "SSH_AUTH_SOCK"
    ];
  };
  # nativeBuildInputs = [
  #   pkgs.pkgconfig
  # ];

  buildFlagsArray = ''
    -ldflags=
      -X gitlab.eng.vmware.com/srp/helix/srpcli/version.Version=${version} 
      -X gitlab.eng.vmware.com/srp/helix/srpcli/version.ReleaseBuild=nix"
  '';

  meta = with lib; {
    description = "Core CLI tool that manages SRP related data and manages data on SRP Platform (Helix)";
    homepage = "https://confluence.eng.vmware.com/display/SRPIPELINE/SRP+Command+Line+Interface+User+Guide";
    maintainers = with maintainers; [ rkoster ];
  };
}
