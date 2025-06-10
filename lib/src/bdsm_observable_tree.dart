import 'dart:collection';

import 'package:bdsm_tree/bdsm_tree.dart';
import 'package:meta/meta.dart';
import 'package:mobx/mobx.dart';

import 'observable_tree_change.dart';

/// Creates an atom for a BDSMObservableTree
Atom _observableBDSMTreeAtom<K, V>(
  ReactiveContext context,
  String? name,
) =>
    Atom(
      name: name ?? context.nameFor('BDSMObservableTree<$K, $V>'),
      context: context,
    );

/// BDSMObservableTree provides a reactive bidirectional sorted map tree
/// that notifies observers when entries are added, updated, or removed.
///
/// This class wraps BDSMTree from the bdsm_tree package and adds MobX reactivity.
///
/// Example:
/// ```dart
/// // Create a tree with integer keys and string values, sorted by values
/// final tree = BDSMObservableTree<int, String>(
///   (pair1, pair2) => pair1.value.compareTo(pair2.value)
/// );
///
/// // Add some entries
/// tree.add(1, 'apple');
/// tree.add(3, 'cherry');
/// tree.add(2, 'banana');
///
/// // Observe changes
/// autorun((_) {
///   print(tree.toList()); // Will print ['apple', 'banana', 'cherry'] in alphabetical order
/// });
///
/// // Updates will trigger reactions
/// tree.add(4, 'apricot'); // Will trigger the autorun
/// ```
class BDSMObservableTree<K, V> with IterableMixin<V> implements Listenable<ObservableTreeChange<K, V>> {
  BDSMObservableTree(
    Comparator<Pair<K, V>> comparator, {
    ReactiveContext? context,
    String? name,
  })  : _context = context ?? mainContext,
        _atom = _observableBDSMTreeAtom<K, V>(
          context ?? mainContext,
          name,
        ),
        _inner = BDSMTree<K, V>(comparator);

  factory BDSMObservableTree.from(
    Map<K, V> map,
    Comparator<Pair<K, V>> comparator, {
    ReactiveContext? context,
    String? name,
  }) {
    final tree = BDSMObservableTree<K, V>(
      comparator,
      context: context,
      name: name,
    );
    tree.addAll(map);
    return tree;
  }

  factory BDSMObservableTree.withValueComparator(
    Comparator<V> valueComparator, {
    ReactiveContext? context,
    String? name,
  }) {
    return BDSMObservableTree<K, V>(
      (pair1, pair2) => valueComparator(pair1.value, pair2.value),
      context: context,
      name: name,
    );
  }

  BDSMObservableTree._wrap(
    this._context,
    this._atom,
    this._inner,
  );

  final ReactiveContext _context;
  final Atom _atom;
  final BDSMTree<K, V> _inner;

  String get name => _atom.name;

  BDSMTree<K, V> get nonObservableInner => _inner;

  Listeners<ObservableTreeChange<K, V>>? _listenersField;

  Listeners<ObservableTreeChange<K, V>> get _listeners => _listenersField ??= Listeners(_context);

  bool get _hasListeners => _listenersField != null && _listenersField!.hasHandlers;

  T _read<T>(T Function() fn, {bool enforceReadPolicy = false}) {
    if (enforceReadPolicy) {
      _context.enforceReadPolicy(_atom);
    }
    _atom.reportObserved();
    return fn();
  }

  T _write<T>(
    T Function() fn, {
    Function(T result)? onBefore,
    Function(T result)? onAfter,
  }) {
    late T result;

    _context.conditionallyRunInAction(() {
      onBefore?.call(result);
      result = fn();
      onAfter?.call(result);

      _atom.reportChanged();
    }, _atom);

    return result;
  }

  BDSMObservableTree<K, V> setComparator(Comparator<Pair<K, V>> newComparator) => _write(() {
        _inner.setComparator(newComparator);
        return this;
      });

  @override
  int get length => _read(() => _inner.length, enforceReadPolicy: true);

  @override
  bool get isEmpty => _read(() => _inner.isEmpty, enforceReadPolicy: true);

  @override
  bool get isNotEmpty => _read(() => _inner.isNotEmpty, enforceReadPolicy: true);

  V putIfAbsent(K key, V Function() ifAbsent) => _write(() {
        final exists = _inner.containsKey(key);
        final result = _inner.putIfAbsent(key, ifAbsent);

        if (!exists && _hasListeners) {
          _reportAdd(key, result);
        }

        return result;
      });

  void add(K key, V value) => _write(() {
        final exists = _inner.containsKey(key);
        final oldValue = exists ? _inner.get(key) : null;

        _inner.add(key, value);

        if (_hasListeners) {
          if (exists) {
            _reportUpdate(key, value, oldValue);
          } else {
            _reportAdd(key, value);
          }
        }
      });

  void addAll(Map<K, V> other) => _write(() {
        other.forEach((key, value) {
          final exists = _inner.containsKey(key);
          final oldValue = exists ? _inner.get(key) : null;

          if (_hasListeners) {
            if (exists) {
              _reportUpdate(key, value, oldValue);
            } else {
              _reportAdd(key, value);
            }
          }
        });

        _inner.addAll(other);
      });

  void update(K key, V Function(V value) update, {V Function()? ifAbsent}) => _write(() {
        final exists = _inner.containsKey(key);
        final oldValue = exists ? _inner.get(key) : null;

        if (exists) {
          final newValue = _inner.update(key, update);

          if (_hasListeners) {
            _reportUpdate(key, newValue, oldValue);
          }
        } else {
          if (ifAbsent == null) {
            throw ArgumentError('Key $key not found and no ifAbsent function provided');
          }

          final newValue = ifAbsent();
          _inner.add(key, newValue);

          if (_hasListeners) {
            _reportAdd(key, newValue);
          }
        }
      });

  void updateAll(V Function(K key, V value) update) => _write(() {
        final entries = <K, V>{};
        final oldValues = <K, V>{};

        _inner.forEachEntry((key, value) {
          oldValues[key] = value;
          entries[key] = update(key, value);
        });

        _inner.updateAll(update);

        if (_hasListeners) {
          entries.forEach((key, value) {
            _reportUpdate(key, value, oldValues[key]);
          });
        }
      });

  void clear() => _write(() {
        final entries = <K, V>{};

        if (_hasListeners) {
          _inner.forEachEntry((key, value) {
            entries[key] = value;
          });
        }

        _inner.clear();

        if (_hasListeners) {
          entries.forEach((key, value) {
            _reportRemove(key, value);
          });
        }
      });

  List<V> toList({bool growable = true}) => _read(() => _inner.toList(growable: growable));

  void forEachEntry(void Function(K key, V value) f) => _read(() => _inner.forEachEntry(f));

  bool containsKey(Object? key) => _read(() => _inner.containsKey(key));

  bool containsValue(Object? value) => _read(() => _inner.containsValue(value));

  K? lastKey() => _read(() => _inner.lastKey());

  K? firstKey() => _read(() => _inner.firstKey());

  V? get(K key) => _read(() => _inner.get(key));

  K? getKey(V value) => _read(() => _inner.getKey(value));

  bool removeKey(K key) => _write(() {
        if (!_inner.containsKey(key)) {
          return false;
        }

        final value = _inner.get(key);
        final result = _inner.removeKey(key);

        if (result && _hasListeners) {
          _reportRemove(key, value);
        }

        return result;
      });

  bool removeValue(V value) => _write(() {
        final key = _inner.getKey(value);

        if (key == null) {
          return false;
        }

        final result = _inner.removeValue(value);

        if (result && _hasListeners) {
          _reportRemove(key, value);
        }

        return result;
      });

  Iterable<V> removeAll(Iterable<V> values) => _write(() {
        final removedEntries = <K, V>{};

        // Find keys for all values that will be removed
        if (_hasListeners) {
          for (final value in values) {
            final key = _inner.getKey(value);
            if (key != null) {
              removedEntries[key] = value;
            }
          }
        }

        final result = _inner.removeAll(values);

        // Notify listeners for each removed entry
        if (_hasListeners) {
          removedEntries.forEach((key, value) {
            _reportRemove(key, value);
          });
        }

        return result;
      });

  Iterable<V> removeWhere(bool Function(V value) test) => _write(() {
        final removedEntries = <K, V>{};

        if (_hasListeners) {
          _inner.forEachEntry((key, value) {
            if (test(value)) {
              removedEntries[key] = value;
            }
          });
        }

        final result = _inner.removeWhere(test);

        if (_hasListeners) {
          removedEntries.forEach((key, value) {
            _reportRemove(key, value);
          });
        }

        return result;
      });

  void rebalanceAll() => _write(() => _inner.rebalanceAll());

  void rebalanceWhere(bool Function(V value) test) => _write(() => _inner.rebalanceWhere(test));

  K? lastKeyBefore(K key) => _read(() => _inner.lastKeyBefore(key));

  K? firstKeyAfter(K key) => _read(() => _inner.firstKeyAfter(key));

  V? lastValueBefore(K key) => _read(() => _inner.lastValueBefore(key));

  V? firstValueAfter(K key) => _read(() => _inner.firstValueAfter(key));

  @override
  Iterator<V> get iterator => ObservableIterator<V>(_atom, _read(() => _inner.iterator));

  @override
  void forEach(void Function(V element) f) => _read(() => _inner.forEach(f));

  /// Registers an observer to be notified of changes to this tree
  ///
  /// If [fireImmediately] is true, the listener will be called immediately
  /// for each entry currently in the tree.
  @override
  Dispose observe(
    void Function(ObservableTreeChange<K, V>) listener, {
    bool fireImmediately = false,
  }) {
    if (fireImmediately) {
      _inner.forEachEntry((key, value) {
        listener(
          ObservableTreeChange<K, V>(
            object: this,
            type: TreeOperationType.add,
            key: key,
            value: value,
          ),
        );
      });
    }
    return _listeners.add(listener);
  }

  void _reportAdd(K key, V? value) {
    _listeners.notifyListeners(
      ObservableTreeChange<K, V>(
        object: this,
        type: TreeOperationType.add,
        key: key,
        value: value,
      ),
    );
  }

  void _reportUpdate(K key, V? value, V? oldValue) {
    _listeners.notifyListeners(
      ObservableTreeChange<K, V>(
        object: this,
        type: TreeOperationType.update,
        key: key,
        value: value,
        oldValue: oldValue,
      ),
    );
  }

  void _reportRemove(K key, V? value) {
    _listeners.notifyListeners(
      ObservableTreeChange<K, V>(
        object: this,
        type: TreeOperationType.remove,
        key: key,
        oldValue: value,
      ),
    );
  }
}

/// Iterator that notifies the atom when values are accessed
class ObservableIterator<T> implements Iterator<T> {
  ObservableIterator(this._atom, this._iterator);

  final Iterator<T> _iterator;
  final Atom _atom;

  @override
  T get current {
    _atom.context.enforceReadPolicy(_atom);

    _atom.reportObserved();
    return _iterator.current;
  }

  @override
  bool moveNext() {
    _atom.context.enforceReadPolicy(_atom);

    _atom.reportObserved();
    return _iterator.moveNext();
  }
}

@visibleForTesting
BDSMObservableTree<K, V> wrapInObservableBDSMTree<K, V>(
  Atom atom,
  BDSMTree<K, V> tree,
) =>
    BDSMObservableTree<K, V>._wrap(
      mainContext,
      atom,
      tree,
    );
