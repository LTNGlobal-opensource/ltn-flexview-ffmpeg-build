#!/bin/sh

set -x

# Bail out if any command fails...
set -e

[ -z "$FFMPEG_REPO" ] && FFMPEG_REPO=git@github.com:LTNGlobal-opensource/FFmpeg-ltn.git
[ -z "$FFMPEG_BRANCH" ] && FFMPEG_BRANCH=n4.4.1-ltn-flexview1

# Dependencies
[ -z "$SRT_REPO" ] && SRT_REPO=https://github.com/Haivision/srt.git
[ -z "$SRT_BRANCH" ] && SRT_BRANCH=v1.4.4

[ -z "$FREETYPE2_REPO" ] && FREETYPE2_REPO=https://github.com/LTNGlobal-opensource/freetype2.git
[ -z "$FREETYPE2_BRANCH" ] && FREETYPE2_BRANCH=VER-2-9-1
[ -z "$OPENSSL_REPO" ] && OPENSSL_REPO=https://github.com/openssl/openssl.git
[ -z "$OPENSSL_BRANCH" ] && OPENSSL_BRANCH=OpenSSL_1_1_1n

export PKGVERSION=`git describe --tags`

# Master, as of 2018-01-05
X264_REPO=git@github.com:LTN-Global/x264.git
X264_BRANCH=b00bcafe53a166b63a179a2f41470cd13b59f927

DEP_BUILDROOT=$PWD/deps-buildroot
export PKG_CONFIG_PATH=$DEP_BUILDROOT/lib/pkgconfig

if [ `uname -s` = "Linux" ]; then
    BUILD_NDI=1
    BUILD_OPENSSL=1
    OPENSSL_PLATFORM=linux-x86_64
else
    BUILD_NDI=0
    BUILD_OPENSSL=1
    OPENSSL_PLATFORM=darwin64-x86_64-cc
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
	make install
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
	./configure --prefix=${DEP_BUILDROOT} --disable-shared
	make -j4
	make install
	cd ..
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

EXTRA_CFLAGS="-I$BMSDK_DIR -I$DEP_BUILDROOT/include"
EXTRA_LDFLAGS="-L$DEP_BUILDROOT/lib"

if [ $BUILD_NDI -eq 1 ]; then
    ENABLE_NDI="--enable-libndi_newtek"
    LIBAVDEVICE_OPTS="$LIBAVDEVICE_OPTS --enable-outdev=libndi_newtek"
    EXTRA_CFLAGS="$EXTRA_CFLAGS -I$NDI_SDK/include"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS -L$NDI_SDK/lib/x86_64-linux-gnu"
fi

if [ $BUILD_OPENSSL -eq 1 ]; then
    ENABLE_OPENSSL="--enable-openssl"
fi

cd ffmpeg-ltn
./configure --disable-doc --enable-gpl --enable-libsrt $ENABLE_NDI --enable-nonfree --enable-debug $ENABLE_OPENSSL --pkg-config-flags=--static --extra-cflags="$EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" $LIBAVDEVICE_OPTS $FATE_IGNORE_OPTS

make clean
make -j8
