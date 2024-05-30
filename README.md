# Readme for the package packetprinting

Author: Lukas Heindl (`oss.heindl+latex@protonmail.com`).

CTAN page: not yet

## License
The LaTeX package `packetprinting` is distributed under the LPPL 1.3 license.

## Description

The LaTeX package `packetprinting` provides an environment to draw packet
headers (or bytefields in general). It is quite similar to the
[bytefield package](https://ctan.org/pkg/bytefield) but uses a different style
and uses tikz to draw its items which makes adding e.g. arrows easy.

## Installation

For a manual installation:

* put the files `packetprinting.ins` and `packetprinting.dtx` in the
same directory;
* run `latex packetprinting.ins` in that directory.

The file `packetprinting.sty` will be generated.

In addition to the `packetprinting.sty` the file
`packetprinting.lua` is also required. You have to put it in the same
directory as your document or (best) in a `texmf` tree.


### Simplified version:

* run `l3build unpack` to generate the `.sty` (and the `.lua` files) in
`build/unpacked/`
