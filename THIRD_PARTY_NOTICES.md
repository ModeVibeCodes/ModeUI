# Third-party notices and artwork provenance

Original ModeUI code: Copyright (c) 2026 Mode, MIT; see LICENSE. That grant
does not replace third-party ownership or notices below. Most of ModeUI's core
and settings framework comes from Play The Game Tools (Copyright (c) 2026 Mode,
MIT), from the same author.

## Bundled libraries (ModeUI/Libs)

These are unmodified upstream sources:

- LibSharedMedia-3.0, Elkano, LGPL v2.1. Source: https://repos.wowace.com/wow/libsharedmedia-3-0/trunk/LibSharedMedia-3.0/LibSharedMedia-3.0.lua. SHA-256: 147ec190e8aeb46dc4989b4ac890c08dd9f0c293f3e1ff9ea2fbcb607df44fce. Full terms: LICENSES/LGPL-2.1.txt. The Lua source is distributed, and the standalone library files can still be replaced.
- CallbackHandler-1.0 revision 8, Copyright (c) 2008 Hendrik nevcairiel Leppkes. BSD terms in LICENSES/CallbackHandler-BSD.txt. Upstream: https://repos.wowace.com/wow/libsharedmedia-3-0/trunk/CallbackHandler-1.0/CallbackHandler-1.0.lua. SHA-256: 84a15af505e728ac5e5eb6a8eaba8989d1131d5f8ba14d11abcfe4ce086de3c1.
- LibStub revision 2, public domain as stated in its retained source header. Upstream: https://repos.wowace.com/wow/libsharedmedia-3-0/trunk/LibStub/LibStub.lua. SHA-256: f93f7dfbd280c0f8e0328bb194faa6db541c3c50b3d4d37eb064c816f0ec5576.

Because of the LGPL library, the bundled distribution is licensed GPL-3.0-only
(LICENSES/GPL-3.0.txt). The original MIT grants are kept.

## Fonts

Lato-Regular.ttf and Lato-Bold.ttf are unmodified Lato font software, Copyright
(c) 2010–2014 tyPoland Lukasz Dziedzic, SIL Open Font License 1.1, reserved font
name Lato. Full terms: LICENSES/Lato-OFL.txt. Pinned source, hashes and Figma
design provenance: design/mode/README.md. The font terms are separate from the
addon distribution license.

Expressway is only an optional reference. ModeUI uses a verified font asset from
an installed EllesmereUI/AyijeUI, or an existing LibSharedMedia registration.
ModeUI does not copy or redistribute the font file. The installed copy's
embedding license was not established; the current author terms are at
https://typodermicfonts.com/license/.

## Media catalog

Shared/Media/MediaCatalog.lua contains generated media name/path facts from installed
providers. It distributes no provider font or texture files and no
implementation code. Those references stay subject to their original owners'
terms.

## Mode theme and unit frame artwork

The Mode Figma Surface/Border/Selection/control artwork and its RGBA TGA
conversions (ModeUI/Media/Textures/Mode) are Copyright (c) 2026 Mode, MIT; see
design/mode/README.md and tools/build_mode_textures.py. The header logo is the
addon owner's supplied branding artwork, as documented there.

The Unit Frames Onyx textures (ModeUI/Media/Textures/UnitFrames) are original
procedural assets from tools/build_unit_frame_textures.py, Copyright (c) 2026
Mode, MIT. They contain no third-party artwork.

The nameplate rim textures (ModeUI/Media/Textures/Nameplates) are original
procedural assets from tools/build_nameplate_textures.lua, Copyright (c) 2026
Mode, MIT. They contain no third-party artwork.
