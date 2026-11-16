#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
${CXX:-c++} -std=c++11 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined tests/robot_test.cpp -o build/robot_test
./build/robot_test
