// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// VMOptions=
// VMOptions=--short_socket_read
// VMOptions=--short_socket_write
// VMOptions=--short_socket_read --short_socket_write

import "package:async_helper/async_helper.dart";
import "package:expect/expect.dart";
import "package:path/path.dart";
import "dart:async";
import "dart:io";

String localFile(path) => Platform.script.resolve(path).toFilePath();

SecurityContext serverContext(String certType, String password) =>
    new SecurityContext()
    ..useCertificateChainSync(localFile('certificates/server_chain.$certType'),
                              password: password)
    ..usePrivateKeySync(localFile('certificates/server_key.$certType'),
                        password: password);

SecurityContext clientContext(String certType, String password) =>
    new SecurityContext()
    ..setTrustedCertificatesSync(localFile(
        'certificates/trusted_certs.$certType'), password: password);

Future<HttpServer> startServer(String certType, String password) {
  return HttpServer.bindSecure(
      "localhost",
      0,
      serverContext(certType, password),
      backlog: 5).then((server) {
    server.listen((HttpRequest request) {
      request.listen(
        (_) { },
        onDone: () {
          request.response.contentLength = 100;
          for (int i = 0; i < 10; i++) {
            request.response.add([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
          }
          request.response.close();
        });
    });
    return server;
  });
}

Future test(String certType, String password) {
  List<int> body = <int>[];
  startServer(certType, password).then((server) {
    SecureSocket.connect(
        "localhost", server.port, context: clientContext(certType, password))
    .then((socket) {
      socket.write("GET / HTTP/1.0\r\nHost: localhost\r\n\r\n");
      socket.close();
      socket.listen(
        (List<int> data) {
          body.addAll(data);
        },
        onDone: () {
          Expect.isTrue(body.length > 100, "$body\n${body.length}");
          Expect.equals(72, body[0]);
          Expect.equals(9, body[body.length - 1]);
          server.close();
        },
        onError: (e, trace) {
          String msg = "Unexpected error $e";
          if (trace != null) msg += "\nStackTrace: $trace";
          Expect.fail(msg);
        });
    });
  });
}

main() async {
  asyncStart();
  await test('pem', 'dartdart');
  await test('p12', 'dartdart');
  asyncEnd();
}
