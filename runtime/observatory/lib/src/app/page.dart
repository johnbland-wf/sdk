// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of app;

/// A [Page] controls the user interface of Observatory. At any given time
/// one page will be the current page. Pages are registered at startup.
/// When the user navigates within the application, each page is asked if it
/// can handle the current location, the first page to say yes, wins.
abstract class Page extends Observable {
  final ObservatoryApplication app;

  @observable ObservatoryElement element;
  @observable ObservableMap args;

  Page(this.app);

  /// Called when the page is installed, this callback must initialize
  /// [element].
  void onInstall();

  /// Called when the page is uninstalled, this callback must clear
  /// [element].
  void onUninstall() {
    element = null;
  }

  /// Called when the page should update its state based on [uri].
  /// NOTE: Only called when the page is installed.
  void visit(Uri uri, Map argsMap) {
    args = toObservable(argsMap);
    _visit(uri);
  }

  // Overridden by subclasses.
  void _visit(Uri uri);

  /// Called to test whether this page can visit [uri].
  bool canVisit(Uri uri);
}

/// A [SimplePage] matches a single uri path and displays a single element.
class SimplePage extends Page {
  final String path;
  final String elementTagName;
  SimplePage(this.path, this.elementTagName, app) : super(app);

  void onInstall() {
    if (element == null) {
      element = new Element.tag(elementTagName);
    }
  }

  void _visit(Uri uri) {
    assert(uri != null);
    assert(canVisit(uri));
  }

  Future<Isolate> getIsolate(Uri uri) {
    return app.vm.getIsolate(uri.queryParameters['isolateId'])
      .catchError((e, stack) {
        Logger.root.severe('$path visit error: $e\n$stack');
        return e;
      });
  }

  bool canVisit(Uri uri) => uri.path == path;
}

/// Error page for unrecognized paths.
class ErrorPage extends Page {
  ErrorPage(app) : super(app);

  void onInstall() {
    if (element == null) {
      // Lazily create page.
      element = new Element.tag('general-error');
    }
  }

  void _visit(Uri uri) {
    assert(element != null);
    assert(canVisit(uri));

    /*
    if (uri.path == '') {
      // Nothing requested.
      return;
    }
    */

    if (element != null) {
      GeneralErrorElement serviceElement = element;
      serviceElement.message = "Path '${uri.path}' not found";
    }
  }

  /// Catch all.
  bool canVisit(Uri uri) => true;
}

/// Top-level vm info page.
class VMPage extends SimplePage {
  VMPage(app) : super('vm', 'service-view', app);

  void _visit(Uri uri) {
    super._visit(uri);
    app.vm.reload().then((vm) {
      if (element != null) {
        ServiceObjectViewElement serviceElement = element;
        serviceElement.object = vm;
      }
    }).catchError((e, stack) {
      Logger.root.severe('VMPage visit error: $e\n$stack');
    });
  }
}

class FlagsPage extends SimplePage {
  FlagsPage(app) : super('flags', 'flag-list', app);

  void _visit(Uri uri) {
    super._visit(uri);
    app.vm.getFlagList().then((flags) {
      if (element != null) {
        FlagListElement serviceElement = element;
        serviceElement.flagList = flags;
      }
    }).catchError((e, stack) {
      Logger.root.severe('FlagsPage visit error: $e\n$stack');
    });
  }
}

class InspectPage extends SimplePage {
  InspectPage(app) : super('inspect', 'service-view', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      var objectId = uri.queryParameters['objectId'];
      if (objectId == null) {
        isolate.reload().then(_visitObject);
      } else {
        isolate.getObject(objectId).then(_visitObject);
      }
    });
  }

  void _visitObject(obj) {
    if (element != null) {
      ServiceObjectViewElement serviceElement = element;
      serviceElement.object = obj;
    }
  }
}


/// Class tree page.
class ClassTreePage extends SimplePage {
  ClassTreePage(app) : super('class-tree', 'class-tree', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      if (element != null) {
        /// Update the page.
        ClassTreeElement page = element;
        page.isolate = isolate;
      }
    });
  }
}

class DebuggerPage extends SimplePage {
  DebuggerPage(app) : super('debugger', 'debugger-page', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      if (element != null) {
        /// Update the page.
        DebuggerPageElement page = element;
        page.app = app;
        page.isolate = isolate;
      }
    });
  }
}

class CpuProfilerPage extends SimplePage {
  CpuProfilerPage(app) : super('profiler', 'cpu-profile', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      if (element != null) {
        /// Update the page.
        CpuProfileElement page = element;
        page.isolate = isolate;
      }
    });
  }
}

class AllocationProfilerPage extends SimplePage {
  AllocationProfilerPage(app)
      : super('allocation-profiler', 'heap-profile', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      if (element != null) {
        /// Update the page.
        HeapProfileElement page = element;
        page.isolate = isolate;
      }
    });
  }
}

class HeapMapPage extends SimplePage {
  HeapMapPage(app) : super('heap-map', 'heap-map', app);

  void _visit(Uri uri) {
    super._visit(uri);
    getIsolate(uri).then((isolate) {
      if (element != null) {
        /// Update the page.
        HeapMapElement page = element;
        page.isolate = isolate;
      }
    });
  }
}

class ErrorViewPage extends Page {
  ErrorViewPage(app) : super(app);

  void onInstall() {
    if (element == null) {
      /// Lazily create page.
      element = new Element.tag('service-view');
    }
  }

  void _visit(Uri uri) {
    assert(element != null);
    assert(canVisit(uri));
    (element as ServiceObjectViewElement).object = app.lastErrorOrException;
  }

  // TODO(turnidge): How to test this page?
  bool canVisit(Uri uri) => uri.path.startsWith('error/');
}

class VMConnectPage extends Page {
  VMConnectPage(app) : super(app);

  void onInstall() {
    if (element == null) {
      element = new Element.tag('vm-connect');
    }
    assert(element != null);
  }

  void _visit(Uri uri) {
    assert(element != null);
    assert(canVisit(uri));
  }

  // TODO(turnidge): Update this to not have the trailing slash.
  bool canVisit(Uri uri) => uri.path.startsWith('vm-connect/');
}

class MetricsPage extends Page {
  // Page state, retained as long as ObservatoryApplication.
  String selectedMetricId;

  final Map<int, MetricPoller> pollers = new Map<int, MetricPoller>();

  // 8 seconds, 4 seconds, 2 seconds, 1 second, and one hundred milliseconds.
  static final List<int> POLL_PERIODS = [8000,
                                         4000,
                                         2000,
                                         1000,
                                         100];

  MetricsPage(app) : super(app) {
    for (var i = 0; i < POLL_PERIODS.length; i++) {
      pollers[POLL_PERIODS[i]] = new MetricPoller(POLL_PERIODS[i]);
    }
  }

  void onInstall() {
    if (element == null) {
      element = new Element.tag('metrics-page');
      (element as MetricsPageElement).page = this;
    }
    assert(element != null);
  }

  void setRefreshPeriod(int refreshPeriod, ServiceMetric metric) {
    if (metric.poller != null) {
      if (metric.poller.pollPeriod.inMilliseconds == refreshPeriod) {
        return;
      }
      // Remove from current poller.
      metric.poller.metrics.remove(metric);
      metric.poller = null;
    }
    if (refreshPeriod == 0) {
      return;
    }
    var poller = pollers[refreshPeriod];
    if (poller != null) {
      poller.metrics.add(metric);
      metric.poller = poller;
      return;
    }
    throw new FallThroughError();
  }

  void _visit(Uri uri) {
    assert(element != null);
    assert(canVisit(uri));
    app.vm.getIsolate(uri.queryParameters['isolateId']).then((i) {
      (element as MetricsPageElement).isolate = i;
    });
  }

  bool canVisit(Uri uri) => uri.path == 'metrics';
}