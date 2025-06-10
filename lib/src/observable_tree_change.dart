import 'package:mobx/mobx.dart';
import 'bdsm_observable_tree.dart';

/// The type of operation that caused a change in the observable tree
enum TreeOperationType {
  add,
  update,
  remove,
}

/// Notification class for BDSMObservableTree changes
class ObservableTreeChange<K, V> {
  ObservableTreeChange({
    required this.object,
    required this.type,
    required this.key,
    this.value,
    this.oldValue,
  });

  final BDSMObservableTree<K, V> object;

  final TreeOperationType type;

  final K key;

  final V? value;

  final V? oldValue;
}
