# MinGW-w64 / GCC runtime notice

The Windows build produced by `compile_windows.sh` is statically linked with
the MinGW-w64 runtime, libgcc, libstdc++ and (for the POSIX toolchain variant)
libwinpthread. These components are not part of CarCalc and are distributed
under their own licenses:

- **GCC runtime library (libgcc, libstdc++)**: GNU GPL v3 with the
  [GCC Runtime Library Exception](https://www.gnu.org/licenses/gcc-exception-3.1.html).
  The exception permits distributing programs linked against the runtime
  without imposing the GPL on the program itself.
  - https://www.gnu.org/licenses/gpl-3.0.html
  - https://www.gnu.org/licenses/gcc-exception-3.1.html
- **MinGW-w64 runtime**: a mix of permissive licenses (BSD-style, MIT-style and
  others), depending on the component.
  - https://www.mingw-w64.org/contribute/#license
  - https://sourceforge.net/p/mingw-w64/wiki/Licenses/

Copies of the upstream license texts ship with the toolchain packages
(`/usr/share/doc/gcc-*/copyright`, `/usr/share/doc/mingw-w64/copyright` on
Debian/Ubuntu).
