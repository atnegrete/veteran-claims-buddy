import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../forms/mailing_address.dart';
import 'claim_guide.dart';

/// The protected identifiers the VA forms need (legal name, date of birth,
/// SSN, VA file number, phone). They live in a single owner-only document,
/// `users/{uid}/identifiers/profile`, separate from the profile doc, and are
/// collected only when a form needs them. Nothing here is filed with the VA.
class Identifiers {
  const Identifiers({
    this.legalFirstName = '',
    this.legalMiddleName = '',
    this.legalLastName = '',
    this.dateOfBirth = '',
    this.ssn = '',
    this.vaFileNumber = '',
    this.phone = '',
    this.email = '',
    this.mailingStreet = '',
    this.mailingUnit = '',
    this.mailingCity = '',
    this.mailingState = '',
    this.mailingZip = '',
  });

  final String legalFirstName;
  final String legalMiddleName;
  final String legalLastName;

  /// `YYYY-MM-DD`, or empty.
  final String dateOfBirth;

  /// `###-##-####`, or empty.
  final String ssn;

  /// 8 or 9 digits, or empty.
  final String vaFileNumber;

  /// `+1` plus ten digits in E.164, or empty.
  /// This fills VA forms. It is not the number used to sign in.
  final String phone;

  /// The address that fills VA forms. It is not the sign-in email.
  final String email;

  final String mailingStreet;
  final String mailingUnit;
  final String mailingCity;

  /// Two-letter U.S. state abbreviation, or empty.
  final String mailingState;

  /// `#####` or `#####-####`, or empty.
  final String mailingZip;

  static const empty = Identifiers();

  /// True once the Veteran has given a legal name (the minimum every form
  /// needs). SSN, VA file number, and date of birth are gathered per form.
  bool get hasLegalName =>
      legalFirstName.trim().isNotEmpty && legalLastName.trim().isNotEmpty;

  static Identifiers fromData(Map<String, dynamic>? data) {
    if (data == null) return empty;
    String str(String key) => (data[key] as String? ?? '').trim();
    return Identifiers(
      legalFirstName: str('legalFirstName'),
      legalMiddleName: str('legalMiddleName'),
      legalLastName: str('legalLastName'),
      dateOfBirth: str('dateOfBirth'),
      ssn: str('ssn'),
      vaFileNumber: str('vaFileNumber'),
      phone: str('phone'),
      email: str('email'),
      mailingStreet: str('mailingStreet'),
      mailingUnit: str('mailingUnit'),
      mailingCity: str('mailingCity'),
      mailingState: str('mailingState'),
      mailingZip: str('mailingZip'),
    );
  }
}

/// Validates the masked identifier shapes. Returns an error message, or null
/// when every supplied value matches its shape (empty values are allowed).
/// Pure, so the UI and the repository agree and it is unit-testable.
String? identifiersError(Identifiers value) {
  final ssn = value.ssn.trim();
  if (ssn.isNotEmpty && !RegExp(r'^\d{3}-\d{2}-\d{4}$').hasMatch(ssn)) {
    return 'Enter the SSN as ###-##-####.';
  }
  final fileNumber = value.vaFileNumber.trim();
  if (fileNumber.isNotEmpty && !RegExp(r'^\d{8,9}$').hasMatch(fileNumber)) {
    return 'A VA file number is 8 or 9 digits.';
  }
  final dob = value.dateOfBirth.trim();
  if (dob.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
    return 'Enter the date of birth as YYYY-MM-DD.';
  }
  final phone = value.phone.trim();
  if (phone.isNotEmpty && !RegExp(r'^\+1\d{10}$').hasMatch(phone)) {
    return 'Enter a U.S. mobile number.';
  }
  final email = value.email.trim();
  if (email.isNotEmpty &&
      (email.length > 254 ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))) {
    return 'Enter an email address.';
  }
  if (value.mailingStreet.trim().length > mailingStreetMax) {
    return 'Street can be $mailingStreetMax characters.';
  }
  if (value.mailingUnit.trim().length > mailingUnitMax) {
    return 'Apartment or unit can be $mailingUnitMax characters.';
  }
  if (value.mailingCity.trim().length > mailingCityMax) {
    return 'City can be $mailingCityMax characters.';
  }
  final state = value.mailingState.trim();
  if (state.isNotEmpty && !validMailingState(state)) {
    return 'Choose a state.';
  }
  final zip = value.mailingZip.trim();
  if (zip.isNotEmpty && !validMailingZip(zip)) {
    return 'Enter a ZIP code.';
  }
  return null;
}

/// The first missing piece of a mailing address, or null when street, city,
/// state, and ZIP are all present. Apartment or unit may be empty.
String? mailingRequiredMessage({
  required String street,
  required String city,
  required String state,
  required String zip,
}) {
  if (street.trim().isEmpty) return 'Enter a street address.';
  if (city.trim().isEmpty) return 'Enter a city.';
  if (!validMailingState(state.trim())) return 'Choose a state.';
  if (!validMailingZip(zip.trim())) return 'Enter a ZIP code.';
  return null;
}

class IdentifiersRepository {
  IdentifiersRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _ref(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('identifiers')
        .doc('profile');
  }

  Stream<Identifiers> watch(String uid) {
    return _ref(uid).snapshots().map((snap) => Identifiers.fromData(snap.data()));
  }

  Future<void> save({required String uid, required Identifiers value}) async {
    final error = identifiersError(value);
    if (error != null) throw ClaimGuideFailure(error);
    final ssn = value.ssn.trim();
    final fileNumber = value.vaFileNumber.trim();
    final dob = value.dateOfBirth.trim();
    final phone = value.phone.trim();
    final email = value.email.trim();

    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
    final ref = _ref(uid);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'legalFirstName': value.legalFirstName.trim(),
      'legalMiddleName': value.legalMiddleName.trim(),
      'legalLastName': value.legalLastName.trim(),
      'dateOfBirth': dob,
      'ssn': ssn,
      'vaFileNumber': fileNumber,
      'phone': phone,
      'email': email,
      'mailingStreet': value.mailingStreet.trim(),
      'mailingUnit': value.mailingUnit.trim(),
      'mailingCity': value.mailingCity.trim(),
      'mailingState': value.mailingState.trim(),
      'mailingZip': value.mailingZip.trim(),
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  /// Writes a form phone or form email only when that copy is still empty.
  /// Sign-in credentials are not changed.
  Future<void> seedFormContact({
    required String uid,
    String? phone,
    String? email,
  }) async {
    final snap = await _ref(uid).get();
    final current = Identifiers.fromData(snap.data());
    final nextPhone = current.phone.isNotEmpty
        ? current.phone
        : (phone ?? '').trim();
    final nextEmail = current.email.isNotEmpty
        ? current.email
        : (email ?? '').trim();
    if (nextPhone == current.phone && nextEmail == current.email) return;
    await save(
      uid: uid,
      value: Identifiers(
        legalFirstName: current.legalFirstName,
        legalMiddleName: current.legalMiddleName,
        legalLastName: current.legalLastName,
        dateOfBirth: current.dateOfBirth,
        ssn: current.ssn,
        vaFileNumber: current.vaFileNumber,
        phone: nextPhone,
        email: nextEmail,
        mailingStreet: current.mailingStreet,
        mailingUnit: current.mailingUnit,
        mailingCity: current.mailingCity,
        mailingState: current.mailingState,
        mailingZip: current.mailingZip,
      ),
    );
  }

  /// Saves the name used on forms and keeps the other identifier fields.
  /// An empty form email is filled from [emailIfEmpty].
  Future<void> saveLegalName({
    required String uid,
    required String first,
    required String middle,
    required String last,
    String? dateOfBirth,
    String? emailIfEmpty,
    String? mailingStreet,
    String? mailingUnit,
    String? mailingCity,
    String? mailingState,
    String? mailingZip,
  }) async {
    final snap = await _ref(uid).get();
    final current = Identifiers.fromData(snap.data());
    await save(
      uid: uid,
      value: Identifiers(
        legalFirstName: first.trim(),
        legalMiddleName: middle.trim(),
        legalLastName: last.trim(),
        dateOfBirth: (dateOfBirth ?? current.dateOfBirth).trim(),
        ssn: current.ssn,
        vaFileNumber: current.vaFileNumber,
        phone: current.phone,
        email: current.email.isNotEmpty
            ? current.email
            : (emailIfEmpty ?? '').trim(),
        mailingStreet: (mailingStreet ?? current.mailingStreet).trim(),
        mailingUnit: (mailingUnit ?? current.mailingUnit).trim(),
        mailingCity: (mailingCity ?? current.mailingCity).trim(),
        mailingState: (mailingState ?? current.mailingState).trim(),
        mailingZip: (mailingZip ?? current.mailingZip).trim(),
      ),
    );
  }

  /// Writes the VA file number and keeps every other identifier field.
  /// Empty clears it. Any other shape is rejected by [identifiersError].
  Future<void> saveVaFileNumber({
    required String uid,
    required String vaFileNumber,
  }) async {
    final fileNumber = vaFileNumber.trim();
    final snap = await _ref(uid).get();
    final current = Identifiers.fromData(snap.data());
    if (current.vaFileNumber == fileNumber) return;
    await save(
      uid: uid,
      value: Identifiers(
        legalFirstName: current.legalFirstName,
        legalMiddleName: current.legalMiddleName,
        legalLastName: current.legalLastName,
        dateOfBirth: current.dateOfBirth,
        ssn: current.ssn,
        vaFileNumber: fileNumber,
        phone: current.phone,
        email: current.email,
        mailingStreet: current.mailingStreet,
        mailingUnit: current.mailingUnit,
        mailingCity: current.mailingCity,
        mailingState: current.mailingState,
        mailingZip: current.mailingZip,
      ),
    );
  }
}

final identifiersRepositoryProvider = Provider<IdentifiersRepository>((ref) {
  return IdentifiersRepository(FirebaseFirestore.instance);
});

final identifiersProvider = StreamProvider<Identifiers>((ref) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return Stream.value(Identifiers.empty);
  return ref.watch(identifiersRepositoryProvider).watch(uid);
});
