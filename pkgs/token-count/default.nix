{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "token-count";
  version = "0.2.1-unstable-2024-03-24";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "felvin-search";
    repo = "token-count";
    rev = "dfdb19af1a96684b7941920016d6394f121bbb89";
    sha256 = lib.fakeSha256;
  };

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    tiktoken
  ];

  # Skip tests since they require network access
  doCheck = false;

  meta = with lib; {
    description = "Count the number of tokens in a text string or file, similar to the Unix 'wc' utility";
    homepage = "https://github.com/felvin-search/token-count";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "token-count";
  };
}