class PackageCheck {
  const PackageCheck({
    this.openedVaPage = false,
    this.savedConfirmation = false,
  });

  final bool openedVaPage;
  final bool savedConfirmation;

  bool get started => openedVaPage || savedConfirmation;

  static const empty = PackageCheck();

  static PackageCheck fromData(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return PackageCheck(
      openedVaPage: data['openedVaPage'] == true,
      savedConfirmation: data['savedConfirmation'] == true,
    );
  }
}

/// How a Veteran files. This app does not file and does not mail the package.
const vaHowToFileUrl = 'https://www.va.gov/disability/how-to-file-claim/';
