// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

patch class _StdIOUtils {
  static Stdin _getStdioInputStream() {
    switch (_getStdioHandleType(0)) {
      case _STDIO_HANDLE_TYPE_TERMINAL:
      case _STDIO_HANDLE_TYPE_PIPE:
      case _STDIO_HANDLE_TYPE_SOCKET:
        return new Stdin._(new _Socket._readPipe(0));
      case _STDIO_HANDLE_TYPE_FILE:
        return new Stdin._(new _FileStream.forStdin());
      default:
        throw new FileSystemException("Unsupported stdin type");
    }
  }

  static _getStdioOutputStream(int fd) {
    assert(fd == 1 || fd == 2);
    switch (_getStdioHandleType(fd)) {
      case _STDIO_HANDLE_TYPE_TERMINAL:
      case _STDIO_HANDLE_TYPE_PIPE:
      case _STDIO_HANDLE_TYPE_SOCKET:
      case _STDIO_HANDLE_TYPE_FILE:
        return new Stdout._(new IOSink(new _StdConsumer(fd)), fd);
      default:
        throw new FileSystemException("Unsupported stdin type");
    }
  }

  static int _socketType(nativeSocket) {
    var result = _getSocketType(nativeSocket);
    if (result is OSError) {
      throw new FileSystemException("Error retreiving socket type", "", result);
    }
    return result;
  }

  static _getStdioHandleType(int fd) native "File_GetStdioHandleType";
}

patch class Stdin {
  /* patch */ int readByteSync() native "Stdin_ReadByte";

  /* patch */ bool get echoMode => _echoMode;
  /* patch */ void set echoMode(bool enabled) { _echoMode = enabled; }

  /* patch */ bool get lineMode => _lineMode;
  /* patch */ void set lineMode(bool enabled) { _lineMode = enabled; }

  static bool get _echoMode native "Stdin_GetEchoMode";
  static void set _echoMode(bool enabled) native "Stdin_SetEchoMode";
  static bool get _lineMode native "Stdin_GetLineMode";
  static void set _lineMode(bool enabled) native "Stdin_SetLineMode";
}

patch class Stdout {
  /* patch */ bool _hasTerminal(int fd) {
    try {
      _terminalSize(fd);
      return true;
    } catch (_) {
      return false;
    }
  }

  /* patch */ int _terminalColumns(int fd) => _terminalSize(fd)[0];
  /* patch */ int _terminalLines(int fd) => _terminalSize(fd)[1];

  static List _terminalSize(int fd) {
    var size = _getTerminalSize(fd);
    if (size is! List) {
      throw new StdoutException("Could not get terminal size", size);
    }
    return size;
  }

  static _getTerminalSize(int fd) native "Stdout_GetTerminalSize";
}


_getStdioHandle(_NativeSocket socket, int num) native "Socket_GetStdioHandle";
_getSocketType(_NativeSocket nativeSocket) native "Socket_GetType";
