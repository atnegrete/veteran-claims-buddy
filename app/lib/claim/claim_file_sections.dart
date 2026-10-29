import 'claim_document.dart';
import 'issue_lane.dart';

/// One filing group on My Uploads or Case Info.
class ClaimFileSectionSpec {
  const ClaimFileSectionSpec({
    required this.packet,
    required this.showDropTarget,
    this.note,
  });

  final ClaimPacket packet;
  final bool showDropTarget;
  final String? note;
}

const _sectionOrder = <ClaimPacket>[
  ClaimPacket.record,
  ClaimPacket.newClaim,
  ClaimPacket.supplemental,
  ClaimPacket.higherLevel,
  ClaimPacket.board,
];

/// The short line under a filing heading. Empty when that filing uses [note].
String claimFileSectionLead(ClaimPacket packet) {
  return switch (packet) {
    ClaimPacket.newClaim => 'Medical records and other files for a condition claimed for the first time.',
    ClaimPacket.supplemental => 'The VA decision and other files from the claim you want to pursue again.',
    ClaimPacket.record => 'Decision letters and discharge papers.',
    _ => '',
  };
}

/// Sections to show, in display order.
///
/// An earlier claim always includes New claims and Supplemental Claim.
/// A first claim does not add an empty Supplemental Claim section.
/// Records, Higher-Level Review, and Board Appeal stay hidden until a
/// condition or a saved file belongs there.
List<ClaimFileSectionSpec> claimFileSections({
  required bool earlierClaim,
  required List<IssueLaneResult> lanes,
  required List<ClaimDocument> documents,
}) {
  final specs = <ClaimFileSectionSpec>[];
  for (final packet in _sectionOrder) {
    final accepts = lanes.any(
      (lane) => lane.packet == packet && lane.acceptsEvidence,
    );
    final inLane = lanes.any((lane) => lane.packet == packet);
    final listed = documents.any(
      (document) => documentListedIn(
        documentPacket: document.packet,
        section: packet,
        sectionAcceptsEvidence: accepts,
      ),
    );
    final forced =
        earlierClaim &&
        (packet == ClaimPacket.newClaim || packet == ClaimPacket.supplemental);
    if (packet == ClaimPacket.record) {
      if (!listed) continue;
    } else if (!forced && !listed && !inLane) {
      continue;
    }
    final drop = switch (packet) {
      ClaimPacket.newClaim || ClaimPacket.supplemental => true,
      ClaimPacket.higherLevel || ClaimPacket.board => accepts,
      _ => false,
    };
    specs.add(
      ClaimFileSectionSpec(
        packet: packet,
        showDropTarget: drop,
        note: _note(packet, accepts),
      ),
    );
  }
  if (!specs.any((spec) => spec.showDropTarget) &&
      !specs.any((spec) => spec.packet == ClaimPacket.newClaim)) {
    final record = specs.indexWhere(
      (spec) => spec.packet == ClaimPacket.record,
    );
    specs.insert(
      record + 1,
      const ClaimFileSectionSpec(
        packet: ClaimPacket.newClaim,
        showDropTarget: true,
      ),
    );
  }
  return specs;
}

String? _note(ClaimPacket packet, bool accepts) {
  if (packet == ClaimPacket.higherLevel) {
    return 'The VA will not look at new files on a Higher-Level Review.';
  }
  if (packet == ClaimPacket.board && !accepts) {
    return 'Direct review does not add new files.';
  }
  return null;
}

/// Files that belong in one section, including a file tagged for both
/// filings when that section accepts evidence.
List<ClaimDocument> documentsInSection({
  required List<ClaimDocument> documents,
  required ClaimPacket packet,
  required bool sectionAcceptsEvidence,
}) {
  return [
    for (final document in documents)
      if (documentListedIn(
        documentPacket: document.packet,
        section: packet,
        sectionAcceptsEvidence: sectionAcceptsEvidence,
      ))
        document,
  ];
}
