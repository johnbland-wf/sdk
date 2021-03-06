import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/summary/format.dart';
import 'package:analyzer/src/summary/summarize_elements.dart';
import 'package:path/path.dart';

main(List<String> args) {
  if (args.length < 1 || args.length > 2) {
    _printUsage();
    exitCode = 1;
    return;
  }
  //
  // Prepare output file path.
  //
  String outputDirectoryPath = args[0];
  if (!FileSystemEntity.isDirectorySync(outputDirectoryPath)) {
    print("'$outputDirectoryPath' is not a directory.");
    _printUsage();
    exitCode = 1;
    return;
  }
  //
  // Prepare SDK path.
  //
  String sdkPath;
  if (args.length == 2) {
    sdkPath = args[1];
    if (!FileSystemEntity.isDirectorySync('$sdkPath/lib')) {
      print("'$sdkPath/lib' does not exist.");
      _printUsage();
      exitCode = 1;
      return;
    }
  } else {
    sdkPath = DirectoryBasedDartSdk.defaultSdkDirectory.getAbsolutePath();
  }
  //
  // Build spec and strong summaries.
  //
  new _Builder(sdkPath, outputDirectoryPath, false).build();
  new _Builder(sdkPath, outputDirectoryPath, true).build();
}

/**
 * The name of the SDK summaries builder application.
 */
const BINARY_NAME = "build_sdk_summaries";

/**
 * Print information about how to use the SDK summaries builder.
 */
void _printUsage() {
  print('Usage: $BINARY_NAME output_directory_path [sdk_path]');
  print('Build files spec.sum and strong.sum in the output directory.');
}

class _Builder {
  final String sdkPath;
  final String outputDirectoryPath;
  final bool strongMode;

  AnalysisContext context;
  final Set<Source> processedSources = new Set<Source>();

  final List<String> linkedLibraryUris = <String>[];
  final List<LinkedLibraryBuilder> linkedLibraries = <LinkedLibraryBuilder>[];
  final List<String> unlinkedUnitUris = <String>[];
  final List<UnlinkedUnitBuilder> unlinkedUnits = <UnlinkedUnitBuilder>[];

  _Builder(this.sdkPath, this.outputDirectoryPath, this.strongMode);

  /**
   * Build a strong or spec mode summary for the Dart SDK at [sdkPath].
   */
  void build() {
    print('Generating ${strongMode ? 'strong' : 'spec'} mode summary.');
    Stopwatch sw = new Stopwatch()..start();
    //
    // Prepare SDK.
    //
    DirectoryBasedDartSdk sdk =
        new DirectoryBasedDartSdk(new JavaFile(sdkPath));
    sdk.useSummary = false;
    context = sdk.context;
    context.analysisOptions = new AnalysisOptionsImpl()
      ..strongMode = strongMode;
    //
    // Serialize each SDK library.
    //
    for (SdkLibrary lib in sdk.sdkLibraries) {
      Source libSource = sdk.mapDartUri(lib.shortName);
      _serializeLibrary(libSource);
    }
    //
    // Write the whole SDK bundle.
    //
    SdkBundleBuilder sdkBundle = new SdkBundleBuilder(
        linkedLibraryUris: linkedLibraryUris,
        linkedLibraries: linkedLibraries,
        unlinkedUnitUris: unlinkedUnitUris,
        unlinkedUnits: unlinkedUnits);
    String outputFilePath =
        join(outputDirectoryPath, strongMode ? 'strong.sum' : 'spec.sum');
    File file = new File(outputFilePath);
    file.writeAsBytesSync(sdkBundle.toBuffer(), mode: FileMode.WRITE_ONLY);
    //
    // Done.
    //
    print('\tDone in ${sw.elapsedMilliseconds} ms.');
  }

  /**
   * Serialize the library with the given [source] and all its direct or
   * indirect imports and exports.
   */
  void _serializeLibrary(Source source) {
    if (!processedSources.add(source)) {
      return;
    }
    LibraryElement element = context.computeLibraryElement(source);
    _serializeSingleLibrary(element);
    element.importedLibraries.forEach((e) => _serializeLibrary(e.source));
    element.exportedLibraries.forEach((e) => _serializeLibrary(e.source));
  }

  /**
   * Serialize the library with the given [element].
   */
  void _serializeSingleLibrary(LibraryElement element) {
    String uri = element.source.uri.toString();
    LibrarySerializationResult libraryResult =
        serializeLibrary(element, context.typeProvider, strongMode);
    linkedLibraryUris.add(uri);
    linkedLibraries.add(libraryResult.linked);
    unlinkedUnitUris.addAll(libraryResult.unitUris);
    unlinkedUnits.addAll(libraryResult.unlinkedUnits);
  }
}
