import 'package:bdsm_observable_tree/bdsm_observable_tree.dart';
import 'package:mobx/mobx.dart' hide when;
import 'package:bdsm_observable_tree/src/observable_tree_change.dart';
import 'package:test/test.dart';

void main() {
  group('BDSMObservableTree', () {
    late BDSMObservableTree<int, String> tree;
    
    setUp(() {
      // Create a tree with a simple value-based comparator
      tree = BDSMObservableTree<int, String>((pair1, pair2) => pair1.value.compareTo(pair2.value));
    });

    test('should be empty initially', () {
      expect(tree.isEmpty, isTrue);
      expect(tree.length, equals(0));
    });

    test('adding elements triggers observation', () {
      final values = <String>[];
      final dispose = autorun((_) {
        values.add(tree.isEmpty ? 'empty' : 'not empty');
      });

      expect(values, equals(['empty']));

      tree.add(1, 'apple');
      expect(values, equals(['empty', 'not empty']));

      dispose();
    });

    test('value observation with computed', () {
      tree.add(1, 'apple');
      tree.add(2, 'banana');
      
      final fruitList = Observable<String>('');

      final dispose = autorun((_) {
        fruitList.value = tree.toList().join(', ');
      });

      expect(fruitList.value, equals('apple, banana'));

      // Add more fruit
      tree.add(3, 'cherry');
      expect(fruitList.value, equals('apple, banana, cherry'));

      // Update existing
      tree.add(2, 'blueberry');
      expect(fruitList.value, equals('apple, blueberry, cherry'));

      // Remove one
      tree.removeKey(1);
      expect(fruitList.value, equals('blueberry, cherry'));

      dispose();
    });

    test('observation with specific elements', () {
      final appleState = Observable<String?>('not added');
      
      final dispose = autorun((_) {
        appleState.value = tree.get(1);
      });

      expect(appleState.value, isNull);

      tree.add(1, 'apple');
      expect(appleState.value, equals('apple'));

      tree.add(1, 'red apple');
      expect(appleState.value, equals('red apple'));

      tree.removeKey(1);
      expect(appleState.value, isNull);

      dispose();
    });

    test('observes comparator changes', () {
      tree.add(1, 'c');
      tree.add(2, 'a');
      tree.add(3, 'b');

      final values = <String>[];
      final dispose = autorun((_) {
        values.add(tree.toList().join(''));
      });

      expect(values, equals(['abc'])); // Sorted by value: a, b, c
      
      // Change comparator to reverse order
      tree.setComparator((pair1, pair2) => pair2.value.compareTo(pair1.value));
      expect(values, equals(['abc', 'cba'])); // Now sorted as: c, b, a

      dispose();
    });

    test('observe method receives changes', () {
      final changes = <String>[];
      
      final dispose = tree.observe((change) {
        String typeStr = '';
        String value = '';
        switch (change.type) {
          case TreeOperationType.add:
            typeStr = 'add';
            value = '${change.value}';
            break;
          case TreeOperationType.update:
            typeStr = 'update';
            value = '${change.value}';
            break;
          case TreeOperationType.remove:
            typeStr = 'remove';
            value = '${change.oldValue}'; // Use oldValue for removals
            break;
        }
        changes.add('$typeStr: ${change.key}=$value');
      });

      tree.add(1, 'apple');
      tree.add(2, 'banana');
      tree.add(1, 'orange'); // Update
      tree.removeKey(2);

      expect(changes, equals([
        'add: 1=apple',
        'add: 2=banana',
        'update: 1=orange',
        'remove: 2=banana',
      ]));

      dispose();
    });

    test('observe with fireImmediately reports existing elements', () {
      tree.add(1, 'apple');
      tree.add(2, 'banana');

      final changes = <String>[];
      
      final dispose = tree.observe((change) {
        String typeStr = '';
        String value = '';
        switch (change.type) {
          case TreeOperationType.add:
            typeStr = 'add';
            value = '${change.value}';
            break;
          case TreeOperationType.update:
            typeStr = 'update';
            value = '${change.value}';
            break;
          case TreeOperationType.remove:
            typeStr = 'remove';
            value = '${change.oldValue}'; // Use oldValue for removals
            break;
        }
        changes.add('$typeStr: ${change.key}=$value');
      }, fireImmediately: true);

      expect(changes, equals([
        'add: 1=apple',
        'add: 2=banana',
      ]));

      // Add one more and verify it's also reported
      tree.add(3, 'cherry');
      expect(changes, equals([
        'add: 1=apple',
        'add: 2=banana',
        'add: 3=cherry',
      ]));

      dispose();
    });

    test('operations do not notify when there are no listeners', () {
      // First add some items
      tree.add(1, 'apple');
      tree.add(2, 'banana');

      // Then create a listener
      int changeCount = 0;
      final dispose = tree.observe((_) {
        changeCount++;
      });

      // Verify changes are detected
      tree.add(3, 'cherry');
      expect(changeCount, equals(1));

      // Remove listener
      dispose();

      // These operations should not increment the counter
      tree.add(4, 'date');
      tree.update(1, (_) => 'apricot');
      tree.removeKey(2);
      
      expect(changeCount, equals(1)); // Still just 1 from before

      // Add listener again
      final dispose2 = tree.observe((_) {
        changeCount++;
      });

      // Now changes should be detected again
      tree.add(5, 'elderberry');
      expect(changeCount, equals(2));

      dispose2();
    });

    test('batch operations', () {
      final changes = <String>[];
      
      final dispose = tree.observe((change) {
        String typeStr = '';
        String value = '';
        switch (change.type) {
          case TreeOperationType.add:
            typeStr = 'add';
            value = '${change.value}';
            break;
          case TreeOperationType.update:
            typeStr = 'update';
            value = '${change.value}';
            break;
          case TreeOperationType.remove:
            typeStr = 'remove';
            value = '${change.oldValue}'; // Use oldValue for removals
            break;
        }
        changes.add('$typeStr: ${change.key}=$value');
      });

      runInAction(() {
        tree.add(1, 'apple');
        tree.add(2, 'banana');
        tree.add(3, 'cherry');
      });

      expect(changes, equals([
        'add: 1=apple',
        'add: 2=banana',
        'add: 3=cherry',
      ]));

      dispose();
    });

    test('clear operation notifies for all removed elements', () {
      // Add several items
      tree.add(1, 'apple');
      tree.add(2, 'banana');
      tree.add(3, 'cherry');

      final removedItems = <String>[];
      
      final dispose = tree.observe((change) {
        if (change.type == TreeOperationType.remove) {
          removedItems.add('${change.key}=${change.oldValue}');
        }
      });

      // Clear the tree
      tree.clear();

      // Verify we got notifications for all removed items
      expect(removedItems, containsAll([
        '1=apple',
        '2=banana',
        '3=cherry',
      ]));

      expect(tree.isEmpty, isTrue);

      dispose();
    });

    test('updateAll operation notifies for all modified elements', () {
      // Add several items
      tree.add(1, 'apple');
      tree.add(2, 'banana');
      tree.add(3, 'cherry');

      final updates = <String>[];
      
      final dispose = tree.observe((change) {
        if (change.type == TreeOperationType.update) {
          updates.add('${change.key}: ${change.oldValue} -> ${change.value}');
        }
      });

      // Update all elements
      tree.updateAll((key, value) => value.toUpperCase());

      // Verify we got update notifications for all items
      expect(updates, equals([
        '1: apple -> APPLE',
        '2: banana -> BANANA',
        '3: cherry -> CHERRY',
      ]));

      expect(tree.toList(), equals(['APPLE', 'BANANA', 'CHERRY']));

      dispose();
    });

    test('bidirectional navigation with reactivity', () {
      tree.add(1, 'apple');
      tree.add(3, 'cherry');
      tree.add(5, 'elderberry');

      // Create observables for navigation
      final beforeCherry = Observable<String?>('');
      final afterApple = Observable<String?>('');
      
      final dispose = autorun((_) {
        beforeCherry.value = tree.lastValueBefore(3);
        afterApple.value = tree.firstValueAfter(1);
      });

      expect(beforeCherry.value, equals('apple'));
      expect(afterApple.value, equals('cherry'));

      // Add an element between apple and cherry
      tree.add(2, 'banana');
      
      // Navigation results should update
      expect(beforeCherry.value, equals('banana'));
      expect(afterApple.value, equals('banana'));

      dispose();
    });

    test('removeAll notifies for each removed element', () {
      tree.add(1, 'apple');
      tree.add(2, 'banana');
      tree.add(3, 'cherry');
      tree.add(4, 'date');

      final removed = <String>[];
      
      final dispose = tree.observe((change) {
        if (change.type == TreeOperationType.remove) {
          removed.add('${change.key}=${change.oldValue}');
        }
      });

      // Remove multiple elements
      tree.removeAll(['apple', 'cherry']);

      // Verify notifications for removed elements
      expect(removed, equals([
        '1=apple',
        '3=cherry',
      ]));

      expect(tree.toList(), equals(['banana', 'date']));

      dispose();
    });

    test('removeWhere notifies for each removed element', () {
      tree.add(1, 'apple');
      tree.add(2, 'banana');
      tree.add(3, 'cherry');
      tree.add(4, 'date');
      
      final removed = <String>[];
      
      final dispose = tree.observe((change) {
        if (change.type == TreeOperationType.remove) {
          removed.add('${change.key}=${change.oldValue}');
        }
      });

      // Remove elements that start with a vowel
      tree.removeWhere((value) => 'aeiou'.contains(value[0]));

      // Verify notifications for removed elements
      expect(removed, equals([
        '1=apple',
      ]));

      expect(tree.toList(), equals(['banana', 'cherry', 'date']));

      dispose();
    });

    test('rebalanceAll preserves observation', () {
      tree.add(1, 'apple');
      tree.add(2, 'banana');

      var latestValue = '';
      final dispose = autorun((_) {
        latestValue = tree.toList().join(', ');
      });

      expect(latestValue, equals('apple, banana'));

      // Rebalance shouldn't change the order but should maintain reactivity
      tree.rebalanceAll();
      
      // Order should be the same
      expect(latestValue, equals('apple, banana'));
      
      // And adding a new item should still trigger the reaction
      tree.add(3, 'cherry');
      expect(latestValue, equals('apple, banana, cherry'));

      dispose();
    });

    test('constructor with value comparator', () {
      final valueTree = BDSMObservableTree<int, String>.withValueComparator(
        (a, b) => a.compareTo(b),
      );

      valueTree.add(1, 'c');
      valueTree.add(2, 'a');
      valueTree.add(3, 'b');

      expect(valueTree.toList(), equals(['a', 'b', 'c']));
    });
  });

  group('ObservableTreeChange', () {
    test('properties are correctly set', () {
      final tree = BDSMObservableTree<int, String>((p1, p2) => 0);
      
      final addChange = ObservableTreeChange<int, String>(
        object: tree,
        type: TreeOperationType.add,
        key: 1,
        value: 'apple',
      );
      
      expect(addChange.object, equals(tree));
      expect(addChange.type, equals(TreeOperationType.add));
      expect(addChange.key, equals(1));
      expect(addChange.value, equals('apple'));
      expect(addChange.oldValue, isNull);
      
      final updateChange = ObservableTreeChange<int, String>(
        object: tree,
        type: TreeOperationType.update,
        key: 1,
        value: 'apple pie',
        oldValue: 'apple',
      );
      
      expect(updateChange.object, equals(tree));
      expect(updateChange.type, equals(TreeOperationType.update));
      expect(updateChange.key, equals(1));
      expect(updateChange.value, equals('apple pie'));
      expect(updateChange.oldValue, equals('apple'));
      
      final removeChange = ObservableTreeChange<int, String>(
        object: tree,
        type: TreeOperationType.remove,
        key: 1,
        oldValue: 'apple pie',
      );
      
      expect(removeChange.object, equals(tree));
      expect(removeChange.type, equals(TreeOperationType.remove));
      expect(removeChange.key, equals(1));
      expect(removeChange.value, isNull);
      expect(removeChange.oldValue, equals('apple pie'));
    });
  });
}
