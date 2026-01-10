{ lib, stdenv, rustPlatform, fetchCrate }:

rustPlatform.buildRustPackage rec {
  pname = "jless";
  version = "0.7.1";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-StuyYZhE+Fws0owjUGbFZqW7iQs/4BVtfVxHftylupE=";
  };

  cargoHash = "sha256-TrTtUdS4YrIizTURrT9zIfaH676j1gKcbldI+RcSPFk=";

  meta = with lib; {
    description = "A command-line pager for JSON data.";
    homepage = "https://pauljuliusmartinez.github.io";
    maintainers = with maintainers; [ rkoster ];
    license = with licenses; [ mit ];
  };
}
