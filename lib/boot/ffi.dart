import 'dart:ffi' hide Size;
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef UnpackNative = Pointer<Utf8> Function(Pointer<Utf8> src, Pointer<Utf8> dest);
typedef UnpackDart = Pointer<Utf8> Function(Pointer<Utf8> src, Pointer<Utf8> dest);
typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

class RustTar {
  static final _lib = Platform.isAndroid ? DynamicLibrary.open("libsuitar.so") : DynamicLibrary.process();
  static final _unpack = _lib.lookup<NativeFunction<UnpackNative>>('unpack_xz_tar').asFunction<UnpackDart>();
  static final _freeStr = _lib.lookup<NativeFunction<FreeStringNative>>('free_rust_string').asFunction<FreeStringDart>();

  static String? unpack(String src, String dest) {
    final s = src.toNativeUtf8(), d = dest.toNativeUtf8();
    final ptr = _unpack(s, d);
    malloc.free(s);
    malloc.free(d);
    if (ptr.address == 0) return null;
    final res = ptr.toDartString();
    _freeStr(ptr);
    return res;
  }
}
