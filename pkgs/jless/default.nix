{ lib, stdenv, rustPlatform, fetchCrate }:

rustPlatform.buildRustPackage rec {
  pname = "jless";
  version = "0.7.1";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-StuyYZhE+Fws0owjUGbFZqW7iQs/4BVtfVxHftylupE=";
  };

  cargoHash = "sha256-PbX61RVbrI2kTuyXK+LhQdJDvNo3KjIQH5eBbL6iUBM=";

  meta = with lib; {
    description = "A command-line pager for JSON data.";
    homepage = "https://pauljuliusmartinez.github.io";
    maintainers = with maintainers; [ rkoster ];
    license = with licenses; [ mit ];
  };
}
