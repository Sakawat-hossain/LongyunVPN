import 'package:longyunvpn/views/proxies/node_status.dart';
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

    test('keeps nodes named without a multiplier or a Latin country code', () {
      // The filter used to require one or the other, so every one of these
      // was thrown away and panels that name nodes this way showed an empty
      // server list. A name is a server unless it is recognisably an info row.
      expect(isRealServerNode('香港01'), isTrue);
      expect(isRealServerNode('🇭🇰 香港 01'), isTrue);
      expect(isRealServerNode('日本 IEPL 专线'), isTrue);
      expect(isRealServerNode('新加坡A'), isTrue);
      expect(isRealServerNode('🇺🇸 洛杉矶 GIA'), isTrue);
      expect(isRealServerNode('台湾 中华电信'), isTrue);
    });
  });
}
