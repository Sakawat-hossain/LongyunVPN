import 'package:fl_clash/views/proxies/node_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isRealServerNode', () {
    test('accepts nodes with a traffic multiplier', () {
      expect(isRealServerNode('HK 香港 | x1.5'), isTrue);
      expect(isRealServerNode('JP x2'), isTrue);
    });

    test('accepts nodes with a leading country code', () {
      expect(isRealServerNode('US Los Angeles'), isTrue);
      expect(isRealServerNode('SG Singapore 01'), isTrue);
    });

    test('rejects the panel info/pseudo entries', () {
      expect(isRealServerNode('剩余流量：100 GB'), isFalse);
      expect(isRealServerNode('套餐到期：2025-01-01'), isFalse);
      expect(isRealServerNode('过期时间'), isFalse);
      expect(isRealServerNode('Traffic reset in 3 days'), isFalse);
      expect(isRealServerNode('Official Website'), isFalse);
      expect(isRealServerNode('Subscribe here'), isFalse);
    });

    test('rejects entries with neither a multiplier nor a country prefix', () {
      expect(isRealServerNode('12345'), isFalse);
      expect(isRealServerNode('a'), isFalse);
    });
  });
}
