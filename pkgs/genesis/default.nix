{ which, perl, git, jq, curl, spruce, safe, vault, bosh, fetchFromGitHub, stdenv, lib, writeText }:

let
  version = "2.7.30";
in stdenv.mkDerivation {
  name = "genesis";

  src = fetchFromGitHub {
    owner = "genesis-community";
    repo = "genesis";
    rev =  "v${version}";
    sha256 = "1s8247w4m3qp9wpq7gr1bl2bbp939b908fv1vgkrci9fa8f5qyj8";
  };

  buildInputs = [ which perl git jq curl spruce safe vault bosh ];

  buildPhase = ''
    # make VERSION=${version} sanity-test release
    make VERSION=${version} release
  '';
  
  installPhase = ''
    mkdir -p "$out/bin"
    # echo "#!${perl}" > "$out/bin/genesis"
    # cat genesis-${version} >> "$out/bin/genesis"
    mv genesis-${version} "$out/bin/genesis"
    chmod +x "$out/bin/genesis"
  '';

  meta = with lib; {
    description = "A BOSH Deployment Paradigm";
    homepage = "https://github.com/genesis-community/genesis";
    license = licenses.mit;
    maintainers = with maintainers; [ rkoster ];
  };
}
