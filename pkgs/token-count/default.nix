{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "token-count";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "felvin-search";
    repo = "token-count";
    rev = "v${version}";
    sha256 = lib.fakeSha256;
  };

  propagatedBuildInputs = with python3Packages; [
    tiktoken
    gitignore-parser
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