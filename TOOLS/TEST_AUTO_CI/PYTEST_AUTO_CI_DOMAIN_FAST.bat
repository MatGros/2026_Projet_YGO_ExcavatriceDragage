@echo off
pushd "%~dp0..\.."
python -m pytest TOOLS/TEST_AUTO_CI/TEST_AUTO_CI_DOMAIN -s -rP
popd

