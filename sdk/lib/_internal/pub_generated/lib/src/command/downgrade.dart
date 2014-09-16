library pub.command.downgrade;
import 'dart:async';
import '../command.dart';
import '../log.dart' as log;
import '../solver/version_solver.dart';
class DowngradeCommand extends PubCommand {
  String get description =>
      "Downgrade the current package's dependencies to oldest versions.\n\n"
          "This doesn't modify the lockfile, so it can be reset with \"pub get\".";
  String get usage => "pub downgrade [dependencies...]";
  bool get takesArguments => true;
  bool get isOffline => commandOptions['offline'];
  DowngradeCommand() {
    commandParser.addFlag(
        'offline',
        help: 'Use cached packages instead of accessing the network.');
    commandParser.addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: "Report what dependencies would change but don't change any.");
  }
  Future onRun() {
    final completer0 = new Completer();
    scheduleMicrotask(() {
      try {
        var dryRun = commandOptions['dry-run'];
        entrypoint.acquireDependencies(
            SolveType.DOWNGRADE,
            useLatest: commandOptions.rest,
            dryRun: dryRun).then((x0) {
          try {
            x0;
            join0() {
              completer0.complete(null);
            }
            if (isOffline) {
              log.warning(
                  "Warning: Downgrading when offline may not update you to "
                      "the oldest versions of your dependencies.");
              join0();
            } else {
              join0();
            }
          } catch (e0) {
            completer0.completeError(e0);
          }
        }, onError: (e1) {
          completer0.completeError(e1);
        });
      } catch (e2) {
        completer0.completeError(e2);
      }
    });
    return completer0.future;
  }
}