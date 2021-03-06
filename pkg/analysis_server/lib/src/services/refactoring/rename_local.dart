// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.src.refactoring.rename_local;

import 'dart:async';

import 'package:analysis_server/src/protocol_server.dart' hide Element;
import 'package:analysis_server/src/services/correction/status.dart';
import 'package:analysis_server/src/services/correction/util.dart';
import 'package:analysis_server/src/services/refactoring/naming_conventions.dart';
import 'package:analysis_server/src/services/refactoring/refactoring.dart';
import 'package:analysis_server/src/services/refactoring/rename.dart';
import 'package:analysis_server/src/services/search/hierarchy.dart';
import 'package:analysis_server/src/services/search/search_engine.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';

/**
 * A [Refactoring] for renaming [LocalElement]s.
 */
class RenameLocalRefactoringImpl extends RenameRefactoringImpl {
  Set<LocalElement> elements = new Set<LocalElement>();

  RenameLocalRefactoringImpl(SearchEngine searchEngine, LocalElement element)
      : super(searchEngine, element);

  @override
  LocalElement get element => super.element as LocalElement;

  @override
  String get refactoringName {
    if (element is ParameterElement) {
      return "Rename Parameter";
    }
    if (element is FunctionElement) {
      return "Rename Local Function";
    }
    return "Rename Local Variable";
  }

  @override
  Future<RefactoringStatus> checkFinalConditions() async {
    RefactoringStatus result = new RefactoringStatus();
    // prepare all elements (usually one)
    await _prepareElements();
    // checks the resolved CompilationUnit(s)
    for (LocalElement element in elements) {
      Source unitSource = element.source;
      List<Source> librarySources = context.getLibrariesContaining(unitSource);
      for (Source librarySource in librarySources) {
        _analyzePossibleConflicts_inLibrary(
            result, unitSource, librarySource, element);
      }
    }
    // done
    return result;
  }

  @override
  RefactoringStatus checkNewName() {
    RefactoringStatus result = super.checkNewName();
    if (element is LocalVariableElement) {
      result.addStatus(validateVariableName(newName));
    } else if (element is ParameterElement) {
      result.addStatus(validateParameterName(newName));
    } else if (element is FunctionElement) {
      result.addStatus(validateFunctionName(newName));
    }
    return result;
  }

  @override
  Future fillChange() async {
    for (Element element in elements) {
      addDeclarationEdit(element);
      await searchEngine.searchReferences(element).then(addReferenceEdits);
    }
  }

  void _analyzePossibleConflicts_inLibrary(RefactoringStatus result,
      Source unitSource, Source librarySource, LocalElement element) {
    // prepare resolved unit
    CompilationUnit unit = null;
    try {
      unit = context.resolveCompilationUnit2(unitSource, librarySource);
    } catch (e) {}
    if (unit == null) {
      return;
    }
    // check for conflicts in the unit
    SourceRange elementRange = element.visibleRange;
    unit.accept(new _ConflictValidatorVisitor(this, result, elementRange));
  }

  /**
   * Fills [elements] with [Element]s to rename.
   */
  Future _prepareElements() async {
    Element enclosing = element.enclosingElement;
    if (enclosing is MethodElement &&
        element is ParameterElement &&
        (element as ParameterElement).parameterKind == ParameterKind.NAMED) {
      // prepare hierarchy methods
      Set<ClassMemberElement> methods =
          await getHierarchyMembers(searchEngine, enclosing);
      // add named parameter from each method
      for (ClassMemberElement method in methods) {
        if (method is MethodElement) {
          for (ParameterElement parameter in method.parameters) {
            if (parameter.parameterKind == ParameterKind.NAMED &&
                parameter.name == element.name) {
              elements.add(parameter);
            }
          }
        }
      }
    } else {
      elements = new Set.from([element]);
    }
  }
}

class _ConflictValidatorVisitor extends RecursiveAstVisitor {
  final RenameLocalRefactoringImpl refactoring;
  final RefactoringStatus result;
  final SourceRange elementRange;
  final Set<Element> conflictingLocals = new Set<Element>();

  _ConflictValidatorVisitor(this.refactoring, this.result, this.elementRange);

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    Element nodeElement = node.bestElement;
    String newName = refactoring.newName;
    if (nodeElement != null && nodeElement.name == newName) {
      // duplicate declaration
      if (node.inDeclarationContext() &&
          haveIntersectingRanges(refactoring.element, nodeElement)) {
        conflictingLocals.add(nodeElement);
        String nodeKind = nodeElement.kind.displayName;
        String message = "Duplicate $nodeKind '$newName'.";
        result.addError(message, newLocation_fromElement(nodeElement));
        return;
      }
      if (conflictingLocals.contains(nodeElement)) {
        return;
      }
      // shadowing referenced element
      if (elementRange.contains(node.offset) &&
          !node.isQualified &&
          !_isNamedExpressionName(node)) {
        nodeElement = getSyntheticAccessorVariable(nodeElement);
        String nodeKind = nodeElement.kind.displayName;
        String nodeName = getElementQualifiedName(nodeElement);
        String nameElementSourceName = nodeElement.source.shortName;
        String refKind = refactoring.element.kind.displayName;
        String message = 'Usage of $nodeKind "$nodeName" declared in '
            '"$nameElementSourceName" will be shadowed by renamed $refKind.';
        result.addError(message, newLocation_fromNode(node));
      }
    }
  }

  static bool _isNamedExpressionName(SimpleIdentifier node) {
    return node.parent is Label && node.parent.parent is NamedExpression;
  }
}
