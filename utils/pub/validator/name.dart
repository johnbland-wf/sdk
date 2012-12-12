// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library name_validator;

import 'dart:io';

import '../entrypoint.dart';
import '../io.dart';
import '../path.dart' as path;
import '../validator.dart';

/// Dart reserved words, from the Dart spec.
final _RESERVED_WORDS = [
  "abstract", "as", "dynamic", "export", "external", "factory", "get",
  "implements", "import", "library", "operator", "part", "set", "static",
  "typedef"
];

/// A validator that validates the name of the package and its libraries.
class NameValidator extends Validator {
  NameValidator(Entrypoint entrypoint)
    : super(entrypoint);

  Future validate() {
    _checkName(entrypoint.root.name, 'Package name "${entrypoint.root.name}"');

    var libDir = join(entrypoint.root.dir, "lib");
    return dirExists(libDir).chain((libDirExists) {
      if (!libDirExists) return new Future.immediate([]);
      return listDir(libDir, recursive: true);
    }).transform((files) {
      for (var file in files) {
        file = relativeTo(file, libDir);
        if (splitPath(file).contains("src")) continue;
        if (path.extension(file) != '.dart') continue;
        var libName = path.basenameWithoutExtension(file);
        _checkName(libName, 'The name of "$file", "$libName",');
      }
    });
  }

  void _checkName(String name, String description) {
    if (name == "") {
      errors.add("$description may not be empty.");
    } else if (!new RegExp(r"^[a-zA-Z0-9_]*$").hasMatch(name)) {
      errors.add("$description may only contain letters, numbers, and "
          "underscores.\n"
          "Using a valid Dart identifier makes the name usable in Dart code.");
    } else if (!new RegExp(r"^[a-zA-Z]").hasMatch(name)) {
      errors.add("$description must begin with letter.\n"
          "Using a valid Dart identifier makes the name usable in Dart code.");
    } else if (_RESERVED_WORDS.contains(name.toLowerCase())) {
      errors.add("$description may not be a reserved word in Dart.\n"
          "Using a valid Dart identifier makes the name usable in Dart code.");
    } else if (new RegExp(r"[A-Z]").hasMatch(name)) {
      warnings.add('$description should be lower-case. Maybe use '
          '"${_unCamelCase(name)}"?');
    }
  }

  String _unCamelCase(String source) {
    var builder = new StringBuffer();
    var lastMatchEnd = 0;
    for (var match in new RegExp(r"[a-z]([A-Z])").allMatches(source)) {
      builder
        ..add(source.substring(lastMatchEnd, match.start + 1))
        ..add("_")
        ..add(match.group(1).toLowerCase());
      lastMatchEnd = match.end;
    }
    builder.add(source.substring(lastMatchEnd));
    return builder.toString().toLowerCase();
  }
}