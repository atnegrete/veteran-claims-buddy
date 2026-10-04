import 'package:app/claim/package_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a checklist starts only after the veteran marks it', () {
    expect(PackageCheck.empty.started, isFalse);
    expect(
      PackageCheck.fromData({'openedVaPage': true, 'savedConfirmation': false})
          .started,
      isTrue,
    );
    expect(PackageCheck.fromData(null).savedConfirmation, isFalse);
  });
}
