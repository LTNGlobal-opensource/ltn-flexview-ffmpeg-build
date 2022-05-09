# ltn-flexview-ffmpeg-build

This build script generates an ffmpeg/ffplay build that contains
third-party dependencies commonly needed for LTN workflows.  It
also includes various backports of patches from the LTED ffmpeg
tree.

## Functionality common to all platforms
* SRT support
* OpenSSL encryption support

## Functionality common to desktop platforms that leverage ffplay (MacOS/Windows)
* SDL

## Encoding Support

|             |Linux  |MacOS   |Windows |
|-------------|  :--: |  :--:  |  :---: |
|Intel QSV    |       |        |   X    |
|VideoToolbox |       |   X    |        |
|AMD AMF      |       |        |   X    |
|Nvidia NVENC |   X   |        |        |
|X264         |   X   |        |   X    |

## Codec Support

The ffmpeg build contains the standard suite of codecs that are present in the main project.

From a video perspective this includes:

|             |Linux  |MacOS   |Windows |
|-------------|  :--: |  :--:  |  :---: |
|MPEG-2 decode| sw/hw | sw/hw  | sw/hw  |
|MPEG-2 encode| sw/hw | sw/hw  | sw/hw  |
|H.264 decode | sw/hw | sw/hw  | sw/hw  |
|H.264 encode | sw/hw |   hw   | sw/hw  |
|HEVC decode  | sw/hw | sw/hw  | sw/hw  |
|HEVC encode  |   hw  |   hw   |   hw   |

Note: hardware accelerated encoding/decoding typically requires special command line arguments to make use of (e.g. to select which HW acceleration engine to use for the encoding and/or decoding operation).

From an audio perspective all encoding/decoding is done via software codecs, and the following table applies to all platforms:

|             |Encode |Decode  |
|-------------|  :--: |  :--:  |
|MP2          | yes   |  yes   |
|AAC          | yes   |  yes   |
|Dolby AC-3   | yes   |  yes   |
|Dolby AC-4   | no    |  no    |


## Features not found in upstream ffmpeg project
* Backport of "UDP monitor" feedback
* TS statistics made available via UDP monitor for both SRT and UDP inputs (total bitrate, Per pid stats for CC count, packets received)
* SRT statistics made available via UDP monitor (various stats related to ARQ, packet loss rates, window sizes, etc)
* Ability to stream input feed to an arbitrary UDP port (for both SRT and UDP input).  This allows analysis of the stream with external tools even if the stream is not multicast or if it is encrypted.  Referred to internally as "UDP mirroring"

## Future Enhancements proposed
* Backport Captioning fixes from LTED ffmpeg tree
* Backport burnreader/burnwriter support from LTED ffmpeg tree
* Backport interlaced HEVC support from LTED ffmpeg tree
* Merge NDI support patch into tree
* Blackmagic SDI input/output support
* Passthrough of SCTE-35/SMPTE 2038 streams
* Get X264 building on MacOS platform
* Port AC-4 support from dev tree
