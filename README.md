# ltn-flexview-ffmpeg-build

This build script generates an ffmpeg/ffplay build that contains
third-party dependencies commonly needed for LTN workflows.  It
also includes various backports of patches from the LTED ffmpeg
tree.

Functionality common to all platforms:
* SRT support
* OpenSSL encryption support

Functionality common to desktop platforms that leverage ffplay (MacOS/Windows)
* SDL

Encoding Support:

|             |Linux  |MacOS   |Windows |
|-------------|  :--: |  :--:  |  :---: |
|Intel QSV    |       |        |   X    |
|VideoToolbox |       |   X    |        |
|AMD AMF      |       |        |   X    |
|Nvidia NVENC |   X   |        |        |
|X264         |   X   |        |   X    |

Features not found in upstream ffmpeg project:
* Backport of "UDP monitor" feedback
* TS statistics made available via UDP monitor for both SRT and UDP inputs (total bitrate, Per pid stats for CC count, packets received)
* SRT statistics made available via UDP monitor (various stats related to ARQ, packet loss rates, window sizes, etc)
* Ability to stream input feed to an arbitrary UDP port (for both SRT and UDP input).  This allows analysis of the stream with external tools even if the stream is not multicast or if it is encrypted.  Referred to internally as "UDP mirroring"

Future Enhancements proposed:
* Backport Captioning fixes from LTED ffmpeg tree
* Merge NDI support patch into tree
* Blackmagic SDI input/output support
* Passthrough of SCTE-35/SMPTE 2038 streams
* Get X264 building on MacOS platform
