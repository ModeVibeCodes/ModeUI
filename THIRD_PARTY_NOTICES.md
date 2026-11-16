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

Geist-Regular.ttf, Geist-Medium.ttf, Geist-SemiBold.ttf and Geist-Bold.ttf (ModeUI/Media/Fonts/Geist)
are unmodified static Geist font software v1.9.2, Copyright 2026 The Geist Project
Authors (https://github.com/vercel/geist-font), SIL Open Font License 1.1, with
no reserved font name. Full terms: LICENSES/Geist-OFL.txt, also next to the fonts.
Source: https://github.com/vercel/geist-font/releases/download/v1.9.2/geist-font-v1.9.2.zip.
SHA-256: Geist-Regular.ttf 2c460a7a71063e53491f343d44b382267bc0cf496e31db64865f962af3152e68; Geist-Medium.ttf e9099e006d4934cae4a8c7d14a1ca2ea724ee2f69f9bdd5b2ffe715baf5524fc; Geist-SemiBold.ttf 01923aa148e5202ae70a2e11b2ab4dc41b80bcc374aedccc913d47bb2f591c06; Geist-Bold.ttf 1c24df313b8ddc9550e060cfe5321c6374997f2892880af303b5ded45fed2582; 
Geist is the Mode design language's fallback typeface (docs/DESIGN_LANGUAGE.md),
used when the client has no Expressway.

Expressway is the Mode typeface when the client has it, and only by reference:
ModeUI uses a verified font asset from an installed EllesmereUI/AyijeUI
(Expressway and Expressway Bold), or an existing LibSharedMedia registration.
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

The nameplate textures (ModeUI/Media/Textures/Nameplates) and the ModeFlat
settings fill (ModeUI/Media/Textures/Mode/Flat.tga) are original procedural
assets from tools/build_shape_textures.lua, Copyright (c) 2026 Mode, MIT. They
contain no third-party artwork.
