{ lib, python39Packages }:
with python39Packages;

buildPythonPackage rec {
  pname = "osspi_signer";
  version = "0.0.3";
  format = "setuptools";

  src = fetchTarball {
    url = "https://build-artifactory.eng.vmware.com/api/pypi/rdoss-pypi-local/osspi-signer/${version}/osspi_signer-${version}.tar.gz";
    sha256 = "025n5iqdnf1jvsdkzbhhslkmprkrkj21897ww2kciwvpsd7ilcq1";
  };

  meta = with lib; {
    description = "osspi_signer";
    maintainers = with maintainers; [ rkoster ];
  };
}
