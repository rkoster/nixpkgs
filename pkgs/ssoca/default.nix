{ stdenv, fetchFromGitHub, git, go }:

stdenv.mkDerivation {
  name = "ssoca";
  version = "0.19.2";

  src = fetchFromGitHub {
    owner = "dpb587";
    repo = "ssoca";
    rev = "v0.19.2";
    sha256 = "1yhacjf41j3vmvl5ns5a6lb4bz74mb2y189qki29aw3dddl5nrhx";
  };

  buildInputs = [
    go
  ];

  buildPhase = ''
    export GOCACHE="$TMPDIR/go-cache"
    export GOPATH="$TMPDIR/go"
    go build -mod=vendor \
        -ldflags "
          -X main.appSemver=0.19.2 \
        " \
        -o $GOPATH/bin/ssoca \
        cli/client/client.go
  '';

  installPhase = ''
    mkdir -p $out
    dir="$GOPATH/bin"
    cp -r $dir $out
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/dpb587/ssoca";
    description = "SSO for services that use CA-based authentication.";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
