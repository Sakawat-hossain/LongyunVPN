import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/views/proxies/common.dart';

/// The Node Status tab used to lead, so every mapping between a tab index and a
/// group index was a bare +1/-1. It now sits after the first few groups, and an
/// off-by-one here does not crash — it quietly shows the wrong group's nodes,
/// or lets Node Status be treated as a group and read past the end of the list.
void main() {
  group('nodeStatusTabIndex', () {
    test('follows the first three groups once there are enough', () {
      expect(nodeStatusTabIndex(4), 3);
      expect(nodeStatusTabIndex(9), 3);
    });

    test('lands last when there are fewer groups than that', () {
      expect(nodeStatusTabIndex(0), 0);
      expect(nodeStatusTabIndex(1), 1);
      expect(nodeStatusTabIndex(2), 2);
    });

    test('is exactly after the third group at the boundary', () {
      expect(nodeStatusTabIndex(3), 3);
    });
  });

  group('tabIndexForGroup', () {
    test('groups before the status tab keep their index', () {
      expect(tabIndexForGroup(0, 6), 0);
      expect(tabIndexForGroup(1, 6), 1);
      expect(tabIndexForGroup(2, 6), 2);
    });

    test('groups after it are shifted by one', () {
      expect(tabIndexForGroup(3, 6), 4);
      expect(tabIndexForGroup(4, 6), 5);
      expect(tabIndexForGroup(5, 6), 6);
    });

    test('no group ever maps onto the status tab', () {
      for (var count = 1; count <= 8; count++) {
        final statusIndex = nodeStatusTabIndex(count);
        for (var g = 0; g < count; g++) {
          expect(
            tabIndexForGroup(g, count),
            isNot(statusIndex),
            reason: 'group $g of $count collided with Node Status',
          );
        }
      }
    });
  });

  group('groupIndexForTab', () {
    test('the status tab has no group', () {
      expect(groupIndexForTab(3, 6), isNull);
      expect(groupIndexForTab(2, 2), isNull);
    });

    test('reverses tabIndexForGroup for every group', () {
      for (var count = 1; count <= 8; count++) {
        for (var g = 0; g < count; g++) {
          expect(
            groupIndexForTab(tabIndexForGroup(g, count), count),
            g,
            reason: 'round trip failed for group $g of $count',
          );
        }
      }
    });

    test('every tab is either one group or the status tab, never both', () {
      for (var count = 1; count <= 8; count++) {
        final seen = <int>[];
        for (var tab = 0; tab <= count; tab++) {
          final g = groupIndexForTab(tab, count);
          if (g != null) seen.add(g);
        }
        expect(
          seen,
          List.generate(count, (i) => i),
          reason: 'tabs did not cover every group exactly once ($count groups)',
        );
      }
    });

    test('an index past the end has no group', () {
      expect(groupIndexForTab(7, 3), isNull);
      expect(groupIndexForTab(99, 6), isNull);
    });

    test('with no groups at all nothing maps to one', () {
      expect(groupIndexForTab(0, 0), isNull);
    });
  });
}
