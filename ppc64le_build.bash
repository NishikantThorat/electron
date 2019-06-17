#!/bin/bash

echo "#####################"
echo "IT IS RECOMMENDED TO RUN THIS BUILD SCRIPT ON UBUNTU BIONIC!"
echo "#####################"
echo "If any error occurs, please refer to https://wiki.raptorcs.com/wiki/Porting/Chromium for missing dependencies or others."
echo "#####################"

set -eux

sudo apt-get update
sudo apt-get install -y build-essential clang git vim cmake python libcups2-dev pkg-config libnss3-dev libssl-dev libglib2.0-dev libgnome-keyring-dev libpango1.0-dev libdbus-1-dev libatk1.0-dev libatk-bridge2.0-dev libgtk-3-dev libkrb5-dev libpulse-dev libxss-dev re2c subversion curl libasound2-dev libpci-dev mesa-common-dev gperf bison uuid-dev clang-format libatspi2.0-dev libnotify-dev libgconf2-dev libcap-dev libxtst-dev libxss1 python-dbusmock openjdk-8-jre ninja-build

VERSION=v12.4.0
DISTRO=linux-ppc64le

wget "https://nodejs.org/dist/$VERSION/node-$VERSION-$DISTRO.tar.xz"
tar -xJvf node-$VERSION-$DISTRO.tar.xz
PATH=$(pwd)/node-$VERSION-$DISTRO/bin:$PATH

git clone https://gn.googlesource.com/gn
cd gn
git checkout 81ee1967d3fcbc829bac1c005c3da59739c88df9
python build/gen.py
ninja -C out
cd ../

DEPOT_TOOLS_GN="$(pwd)/gn/out/gn"

REVISION=$(grep -Po "(?<=CLANG_SVN_REVISION = ')\d+(?=')" src/tools/clang/scripts/update.py)

svn checkout --force "https://llvm.org/svn/llvm-project/llvm/trunk@$REVISION" llvm
svn checkout --force "https://llvm.org/svn/llvm-project/cfe/trunk@$REVISION" llvm/tools/clang
svn checkout --force "https://llvm.org/svn/llvm-project/compiler-rt/trunk@$REVISION" llvm/compiler-rt

mkdir -p llvm_build
cd llvm_build

LLVM_BUILD_DIR=$(pwd)

cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="PowerPC" -G "Unix Makefiles" ../llvm
make -j$(nproc)

cd ../

git clone https://github.com/leo-lb/depot_tools
git checkout ppc64le

PATH="$PATH:$(pwd)/depot_tools"
VPYTHON_BYPASS="manually managed python not supported by chrome operations"
GYP_DEFINES="disable_nacl=1"

mkdir -p electron-gn && cd electron-gn
gclient config --name "src/electron" --unmanaged https://github.com/leo-lb/electron@electron-ppc64le
gclient sync --with_branch_heads --with_tags

cd src

cd third_party/libvpx
mkdir -p source/config/linux/ppc64
./generate_gni.sh
cd ../../

cd third_party/ffmpeg
./chromium/scripts/build_ffmpeg.py linux ppc64
./chromium/scripts/generate_gn.py
./chromium/scripts/copy_config.sh
cd ../../

gn gen out/Release --args="import(\"//electron/build/args/release.gn\") clang_base_path = \"$LLVM_BUILD_DIR\""
ninja -C out/Release electron
electron/script/strip-binaries.py -d out/Release
ninja -C out/Release electron:electron_dist_zip

echo "Distributable zip file located at: $(pwd)/out/Release/dist.zip"
