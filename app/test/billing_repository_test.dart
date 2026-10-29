import 'package:app/billing/billing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null or empty link yields no URI', () {
    expect(buildWebPurchaseUri(null, 'uid123'), isNull);
    expect(buildWebPurchaseUri('', 'uid123'), isNull);
  });

  test('app user id is appended as a path segment, not a query parameter', () {
    final uri = buildWebPurchaseUri(
      'https://pay.rev.cat/sandbox/tok123/',
      'uid123',
    );
    expect(uri.toString(), 'https://pay.rev.cat/sandbox/tok123/uid123');
    expect(uri!.queryParameters.containsKey('app_user_id'), isFalse);
  });

  test('works without a trailing slash on the link', () {
    final uri = buildWebPurchaseUri(
      'https://pay.rev.cat/tok123',
      'uid123',
    );
    expect(uri.toString(), 'https://pay.rev.cat/tok123/uid123');
  });

  test('a missing uid returns the bare link', () {
    final uri = buildWebPurchaseUri('https://pay.rev.cat/tok123/', null);
    expect(uri.toString(), 'https://pay.rev.cat/tok123/');
  });
}
