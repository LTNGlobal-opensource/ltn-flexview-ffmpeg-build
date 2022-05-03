#!/bin/sh

set -x

# Bail out if any command fails...
set -e

[ -z "$FFMPEG_REPO" ] && FFMPEG_REPO=https://github.com/LTNGlobal-opensource/FFmpeg-ltn.git
[ -z "$FFMPEG_BRANCH" ] && FFMPEG_BRANCH=n4.4.1-ltn-flexview1

# Dependencies
[ -z "$SRT_REPO" ] && SRT_REPO=https://github.com/Haivision/srt.git
[ -z "$SRT_BRANCH" ] && SRT_BRANCH=v1.4.4

[ -z "$FREETYPE2_REPO" ] && FREETYPE2_REPO=https://github.com/LTNGlobal-opensource/freetype2.git
[ -z "$FREETYPE2_BRANCH" ] && FREETYPE2_BRANCH=VER-2-9-1
[ -z "$OPENSSL_REPO" ] && OPENSSL_REPO=https://github.com/openssl/openssl.git
[ -z "$OPENSSL_BRANCH" ] && OPENSSL_BRANCH=OpenSSL_1_1_1n
[ -z "$SDL2_REPO" ] && SDL2_REPO=https://github.com/libsdl-org/SDL.git
[ -z "$SDL2_BRANCH" ] && SDL2_BRANCH=release-2.0.20


export PKGVERSION=`git describe --tags`

# Master, as of 2018-01-05
X264_REPO=git@github.com:LTN-Global/x264.git
X264_BRANCH=b00bcafe53a166b63a179a2f41470cd13b59f927

DEP_BUILDROOT=$PWD/deps-buildroot
export PKG_CONFIG_PATH=$DEP_BUILDROOT/lib/pkgconfig:$DEP_BUILDROOT/lib64/pkgconfig
export PKG_CONFIG_LIBDIR=$DEP_BUILDROOT/lib/pkgconfig

if [ `uname -s` = "Linux" ]; then
    # Disable NDI build even on Linux because it isn't in newer releases
    BUILD_NDI=0
    BUILD_SDL2=0
    BUILD_OPENSSL=1
    OPENSSL_PLATFORM=linux-x86_64
elif [ `uname -s` = "Darwin" ]; then
    # MacOS
    BUILD_NDI=0
    BUILD_SDL2=1
    BUILD_OPENSSL=1
    ARCH=`uname -m`
    OPENSSL_PLATFORM="darwin64-$ARCH-cc -mmacosx-version-min=10.15"
    SDK_PATH=`xcrun --sdk macosx --show-sdk-path`
    EXTRA_CFLAGS="-arch $ARCH -target $ARCH-apple-darwin10.15 -mmacosx-version-min=10.15 -I${SDK_PATH}/usr/include"
    EXTRA_LDFLAGS="-arch $ARCH -march=$ARCH -target $ARCH-apple-darwin10.15 -isysroot ${SDK_PATH} -mmacosx-version-min=10.15"
elif [ `uname -o` = "Msys" ]; then
    BUILD_NDI=0
    BUILD_SDL2=1
    BUILD_OPENSSL=1
    OPENSSL_PLATFORM=mingw64
else
    echo "Unsupported platform.  Cannot continue"
    exit 1
fi
NDI_SDK=$PWD/ndi_sdk

mkdir -p $DEP_BUILDROOT/lib
mkdir -p $DEP_BUILDROOT/include

if [ $BUILD_OPENSSL -eq 1 ]; then
    if [ ! -d openssl ]; then
	git clone $OPENSSL_REPO
	cd openssl
	if [ "$OPENSSL_BRANCH" != "" ]; then
	    echo "Switching to branch [$OPENSSL_BRANCH]..."
	    git checkout $OPENSSL_BRANCH
	fi

	./Configure no-shared --prefix=${DEP_BUILDROOT} ${OPENSSL_PLATFORM}
	make -j4
	make install_sw
	cd ..
    fi
fi

if [ ! -d srt ]; then
	git clone $SRT_REPO srt
	cd srt
	if [ "$SRT_BRANCH" != "" ]; then
	    echo "Switching to branch [$SRT_BRANCH]..."
	    git checkout $SRT_BRANCH
	fi
	export OPENSSL_ROOT_DIR=${DEP_BUILDROOT}
	export OPENSSL_LIB_DIR=${DEP_BUILDROOT}/lib
	export OPENSSL_INCLUDE_DIR=${DEP_BUILDROOT}/include

	if [ `uname -s` = "Darwin" ]; then
	    cmake -DCMAKE_C_FLAGS="${EXTRA_CFLAGS}" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 -DCMAKE_CXX_FLAGS="${EXTRA_CFLAGS}" -DCMAKE_EXE_LINKER_FLAGS="${EXTRA_LDFLAGS}" -DCMAKE_INSTALL_PREFIX="${DEP_BUILDROOT}" -DENABLE_SHARED=0
	elif [ `uname -o` = "Msys" ]; then
	    cmake -GNinja \
		  -DCMAKE_INSTALL_PREFIX="${DEP_BUILDROOT}" \
		  -DCMAKE_BUILD_TYPE=Release \
		  -DENABLE_SHARED=OFF \
		  -DENABLE_STATIC=ON \
		  -DENABLE_APPS=OFF \
		  -DENABLE_RELATIVE_LIBPATH=ON \
		  -DUSE_ENCLIB=openssl .
	else
	    ./configure --prefix=${DEP_BUILDROOT} --disable-shared
	fi
	cmake --build .
	cmake --install . --prefix ${DEP_BUILDROOT}
	cd ..
fi

if [ $BUILD_SDL2 -eq 1 ]; then
    if [ ! -d sdl2 ]; then
	git clone $SDL2_REPO sdl2
	cd sdl2
	if [ "$SDL2_BRANCH" != "" ]; then
	    echo "Switching to branch [$SDL2_BRANCH]..."
	    git checkout $SDL2_BRANCH
	fi
	mkdir build && cd build
	CFLAGS="${EXTRA_CFLAGS}" ../configure --prefix=${DEP_BUILDROOT} --disable-shared
	make -j4
	make install
	cd ../..
    fi
fi

if [ $BUILD_NDI -eq 1 ]; then
	if [ ! -f InstallNDISDK_v4_Linux.tar.gz ]; then
		wget https://downloads.ndi.tv/SDK/NDI_SDK_Linux/InstallNDISDK_v4_Linux.tar.gz
	fi
	if [ ! -f InstallNDISDK_v4_Linux.sh ]; then
		tar zxf InstallNDISDK_v4_Linux.tar.gz
	fi
	if [ ! -d $NDI_SDK ]; then
		echo "Y" | ./InstallNDISDK_v4_Linux.sh >/dev/null
		mv 'NDI SDK for Linux' $NDI_SDK
	fi
fi

# Clone ffmpeg
if [ ! -d ffmpeg-ltn ]; then
	git clone $FFMPEG_REPO ffmpeg-ltn
	cd ffmpeg-ltn
	if [ "$FFMPEG_BRANCH" != "" ]; then
	    echo "Switching to branch [$FFMPEG_BRANCH]..."
	    git checkout $FFMPEG_BRANCH
	fi
	cd ..
fi

# Make sure we don't end up with a bunch of extra deps for stuff like X11, ALSA, etc...
# Note: lavfi is needed for FATE testing, even though we don't need it in production deployment
LIBAVDEVICE_OPTS=""

# Tests which are known to fail FATE in our current build (which we don't care about)
FATE_IGNORE_OPTS="--ignore-tests=rgb24-mkv"

EXTRA_CFLAGS="$EXTRA_CFLAGS -I$DEP_BUILDROOT/include"
EXTRA_LDFLAGS="$EXTRA_LDFLAGS -L$DEP_BUILDROOT/lib"

if [ $BUILD_NDI -eq 1 ]; then
    ENABLE_NDI="--enable-libndi_newtek"
    LIBAVDEVICE_OPTS="$LIBAVDEVICE_OPTS --enable-outdev=libndi_newtek"
    EXTRA_CFLAGS="$EXTRA_CFLAGS -I$NDI_SDK/include"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS -L$NDI_SDK/lib/x86_64-linux-gnu"
fi

if [ $BUILD_OPENSSL -eq 1 ]; then
    ENABLE_OPENSSL="--enable-openssl"
fi

EXTERNAL_DEPS="--disable-lzma --disable-libxcb --disable-xlib --disable-zlib --disable-lzma --disable-bzlib --disable-iconv $ENABLE_OPENSSL $ENABLE_NDI --enable-libsrt"

cd ffmpeg-ltn
./configure --disable-doc --enable-gpl --enable-nonfree --enable-debug $EXTERNAL_DEPS --pkg-config-flags=--static --extra-cflags="$EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" $LIBAVDEVICE_OPTS $FATE_IGNORE_OPTS

make clean
make -j8
