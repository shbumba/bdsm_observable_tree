# BDSM Observable Tree

A reactive bi-directional sorted map tree with MobX integration for Dart.

## Overview

`BDSMObservableTree` extends the functionality of `BDSMTree` by adding reactivity through MobX, allowing your application to respond to changes in the tree structure. This package maintains the strict, hierarchical ordering of `BDSMTree` while enabling observation of structure mutations.

## Features

- **Reactive Collection**: Automatically notifies observers when elements are added, updated, or removed
- **MobX Integration**: Seamlessly works with MobX reactions, actions, and computed values
- **Strict Ordering Control**: Maintains the same value-based hierarchical structure as BDSMTree
- **Efficient Key-Value Access**: O(1) lookups by key and O(log n) operations for maintaining sorted order
- **Observable Change Events**: Get detailed information about each change with keys, values, and operation types
- **Runtime Comparator Changes**: Dynamically change the hierarchy rules with automatic rebalancing

## Installation

Add the package to your `pubspec.yaml` file using one of the following options:

### From pub.dev (coming soon)

```yaml
dependencies:
  bdsm_observable_tree: ^0.1.0
```

### From GitHub

Until the package is published to pub.dev, you can install it directly from GitHub:

```yaml
dependencies:
  bdsm_observable_tree:
    git:
      url: https://github.com/shbumba/bdsm_observable_tree.git
      ref: main  # or use a specific branch/tag/commit
```

### For Local Development

```yaml
dependencies:
  bdsm_observable_tree:
    path: path/to/bdsm_observable_tree
```

After adding the dependency, run:

```bash
dart pub get
```

## Usage

### Basic Usage

```dart
import 'package:bdsm_observable_tree/bdsm_observable_tree.dart';
import 'package:mobx/mobx.dart';

void main() {
  // Create a tree that sorts strings by their length
  final tree = BDSMObservableTree<String, String>((pair1, pair2) => 
      pair1.value.length.compareTo(pair2.value.length));
  
  // Set up an observer to react to changes
  final disposer = autorun((_) {
    print('Tree values: ${tree.toList()}');
  });  // Prints: Tree values: []
  
  // Add key-value pairs (will trigger the observer)
  tree.add('id1', 'apple');     // Prints: Tree values: [apple]
  tree.add('id2', 'banana');    // Prints: Tree values: [apple, banana]
  tree.add('id3', 'cherry');    // Prints: Tree values: [apple, cherry, banana]
  
  // Update a value (will trigger the observer)
  tree.update('id1', (value) => 'watermelon');
  // Prints: Tree values: [cherry, banana, watermelon]
  
  // Clean up the observer when done
  disposer();
}
```

### Observing Specific Changes

```dart
import 'package:bdsm_observable_tree/bdsm_observable_tree.dart';

void main() {
  final tree = BDSMObservableTree<int, String>.withValueComparator(
    (a, b) => a.compareTo(b)
  );
  
  // Observe specific changes with detailed information
  final dispose = tree.observe((change) {
    switch (change.type) {
      case TreeOperationType.add:
        print('Added: ${change.key} -> ${change.value}');
        break;
      case TreeOperationType.update:
        print('Updated: ${change.key} from ${change.oldValue} to ${change.value}');
        break;
      case TreeOperationType.remove:
        print('Removed: ${change.key} -> ${change.oldValue}');
        break;
    }
  });
  
  tree.add(1, 'apple');           // Prints: Added: 1 -> apple
  tree.add(2, 'banana');          // Prints: Added: 2 -> banana
  tree.update(1, (v) => 'apricot'); // Prints: Updated: 1 from apple to apricot
  tree.removeKey(2);              // Prints: Removed: 2 -> banana
  
  dispose();
}
```

### With Custom Objects

```dart
import 'package:bdsm_observable_tree/bdsm_observable_tree.dart';
import 'package:mobx/mobx.dart';

class Product {
  final String name;
  @observable
  double price;
  
  Product(this.name, this.price);
  
  @override
  String toString() => 'Product{name: $name, price: \$${price.toStringAsFixed(2)}}';
}

void main() {
  // Sort products by price
  final tree = BDSMObservableTree<String, Product>((pair1, pair2) => 
      pair1.value.price.compareTo(pair2.value.price));
  
  final laptop = Product('Laptop', 999.99);
  final phone = Product('Phone', 599.99);
  final headphones = Product('Headphones', 99.99);
  
  tree.add('p1', laptop);
  tree.add('p2', phone);
  tree.add('p3', headphones);
  
  // Set up an observer to print products whenever the tree changes
  final disposer = autorun((_) {
    print('Products in price order: ${tree.toList().map((p) => '${p.name}: \$${p.price}')}');
  });
  // Prints: Products in price order: (Headphones: $99.99, Phone: $599.99, Laptop: $999.99)
  
  // When external changes occur, manually rebalance the tree
  headphones.price = 129.99;
  tree.rebalanceWhere((product) => product.name == 'Headphones');
  // Prints: Products in price order: (Headphones: $129.99, Phone: $599.99, Laptop: $999.99)
  
  // Or change the sorting rule completely
  tree.setComparator((pair1, pair2) => pair1.value.name.compareTo(pair2.value.name));
  // Prints: Products in price order: (Headphones: $129.99, Laptop: $999.99, Phone: $599.99)
  
  disposer();
}
```

## API Reference

### Creation & Configuration

- `BDSMObservableTree(Comparator<Pair<K, V>> comparator)`: Create a reactive tree with the given comparator
- `BDSMObservableTree.from(Map<K, V> map, Comparator<Pair<K, V>> comparator)`: Create from a map
- `BDSMObservableTree.withValueComparator(Comparator<V> valueComparator)`: Create with a simpler comparator
- `setComparator(Comparator<Pair<K, V>> newComparator)`: Change the ordering rules at runtime

### Core Methods

- `add(K key, V value)`: Add or update an entry (notifies observers)
- `update(K key, V Function(V) update, {V Function()? ifAbsent})`: Update with a function (notifies observers)
- `removeKey(K key)`: Remove by key (notifies observers)
- `removeValue(V value)`: Remove by value (notifies observers)
- `clear()`: Remove all entries (notifies observers)

### Observation

- `observe(void Function(ObservableTreeChange<K, V>) listener, {bool fireImmediately = false})`: Listen for specific changes
- All properties and methods participate in MobX tracking when used in reactions, computed properties, etc.

### Navigation & Access

BDSMObservableTree includes all methods from BDSMTree:

- `get(K key)`: Get a value by key
- `firstValue()`, `lastValue()`: Get the first/last value
- `firstValueAfter(K key)`, `lastValueBefore(K key)`: Navigate to adjacent values
- Plus full Iterable<V> implementation

### Rebalancing

- `rebalanceAll()`: Force a complete reordering of the tree
- `rebalanceWhere(bool Function(V value) test)`: Rebalance only entries matching a condition

## How It Works

BDSMObservableTree wraps a BDSMTree instance and adds several MobX integration points:

1. An `Atom` that tracks read operations to the tree, enabling MobX reactions
2. A `_write` method that reports changes to the atom when the tree is modified
3. A `Listeners` system with `ObservableTreeChange` events for fine-grained observation
4. An `ObservableIterator` that ensures iterations are tracked by MobX

When operations are performed on the tree, appropriate observers are notified, allowing your application to update UI, sync data, or perform other reactive operations.

## When to Use BDSMObservableTree

BDSMObservableTree is perfect for:

- **Reactive UIs** that need to update when data changes
- **MobX-based applications** needing sorted collections
- **Complex data hierarchies** that require observation
- **Forms of discipline** that demand notification when rules or positions change
- **Consensual data binding** where both parties (data and UI) agree to the relationship

## Safe Usage Guidelines

When working with BDSMObservableTree, always follow these principles:

1. **Consent**: Always dispose observers when no longer needed
2. **Trust**: Use within MobX actions for batch updates when appropriate
3. **Boundaries**: Define clear responsibilities between the tree and its observers
4. **Communication**: Document how your observers react to different change types
5. **Aftercare**: Clean up resources properly using the provided dispose methods

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
