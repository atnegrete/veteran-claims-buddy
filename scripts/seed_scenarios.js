const scenarios = {
  a: {
    id: 'a',
    label: 'brand new Veteran',
    user: {
      onboardingStatus: 'inProgress',
      onboardingStep: 'service',
      accountStatus: 'active',
    },
    documents: [
      {
        path: 'servicePeriods/army-1',
        data: {
          branch: 'army',
          component: 'active',
          startDate: '2010-06',
          endDate: null,
          primaryOccupationText: 'Infantry',
        },
      },
    ],
  },
  b: {
    id: 'b',
    label: 'active initial claim',
    user: {
      onboardingStatus: 'complete',
      onboardingStep: 'review',
      accountStatus: 'active',
      currentWorkingCaseId: 'case-b',
    },
    documents: [
      {
        path: 'cases/case-b',
        data: { displayName: 'Open Case', status: 'working' },
      },
      {
        path: 'conditions/hearing',
        data: {
          displayName: 'Hearing loss',
          bodySystem: 'hearing',
          status: 'potential',
          current: true,
          diagnosed: false,
          discoverySource: 'questionnaire',
          sourceQuestionnaireId: 'condition-discovery',
          sourceQuestionId: 'hearing',
          sourceType: 'veteranReported',
          schemaVersion: 1,
        },
      },
      {
        path: 'conditions/knee',
        data: {
          displayName: 'Knee pain',
          bodySystem: 'musculoskeletal',
          status: 'potential',
          current: true,
          diagnosed: false,
          discoverySource: 'questionnaire',
          sourceQuestionnaireId: 'condition-discovery',
          sourceQuestionId: 'knee',
          sourceType: 'veteranReported',
          schemaVersion: 1,
        },
      },
      {
        path: 'claimIssues/hearing',
        data: {
          conditionId: 'hearing',
          displayName: 'Hearing loss',
          activeCaseId: 'case-b',
          status: 'potential',
        },
      },
      {
        path: 'claimIssues/knee',
        data: {
          conditionId: 'knee',
          displayName: 'Knee pain',
          activeCaseId: 'case-b',
          status: 'potential',
        },
      },
      {
        path: 'evidenceLinks/hearing-diagnosis',
        data: {
          claimIssueId: 'hearing',
          documentId: null,
          factId: null,
          questionnaireId: null,
          responseId: null,
          evidenceType: 'currentDiagnosis',
          relationship: 'supports',
          summary: 'Audiology note on file.',
          sourceType: 'veteranReported',
          userConfirmed: true,
        },
      },
      {
        path: 'exams/exam-b',
        data: {
          caseId: 'case-b',
          examDate: '2026-11-02',
          examTime: '09:00',
          timezone: 'America/Chicago',
          examType: 'C&P',
          providerType: 'va',
          providerName: 'VA clinic',
          location: 'Chicago',
          phone: '',
          telehealth: false,
          notes: '',
          status: 'active',
          sourceType: 'veteranReported',
          schemaVersion: 1,
        },
      },
    ],
  },
  c: {
    id: 'c',
    label: 'denied issue',
    user: {
      onboardingStatus: 'complete',
      onboardingStep: 'review',
      accountStatus: 'active',
      currentWorkingCaseId: 'case-c',
    },
    documents: [
      {
        path: 'cases/case-c',
        data: { displayName: 'Open Case', status: 'decisionReceived' },
      },
      {
        path: 'conditions/knee',
        data: {
          displayName: 'Knee pain',
          bodySystem: 'musculoskeletal',
          status: 'potential',
          current: true,
          diagnosed: false,
          discoverySource: 'questionnaire',
          sourceQuestionnaireId: 'condition-discovery',
          sourceQuestionId: 'knee',
          sourceType: 'veteranReported',
          schemaVersion: 1,
        },
      },
      {
        path: 'claimIssues/knee',
        data: {
          conditionId: 'knee',
          displayName: 'Knee pain',
          activeCaseId: 'case-c',
          status: 'potential',
        },
      },
      {
        path: 'decisions/decision-c',
        data: {
          caseId: 'case-c',
          decisionDate: '2026-03-01',
          receivedDate: '2026-03-15',
          sourceDocumentId: null,
          sourceType: 'documentExtracted',
          status: 'confirmed',
          benefitType: 'compensation',
          overallSummary: 'The knee claim was denied.',
          reviewDeadline: '2027-03-01',
          deadlineRuleVersionId: 'va-rules',
          schemaVersion: 1,
        },
      },
      {
        path: 'decisionIssues/knee-denial',
        data: {
          decisionId: 'decision-c',
          claimIssueId: 'knee',
          displayName: 'Knee pain',
          outcome: 'denied',
          ratingPercent: null,
          effectiveDate: null,
          favorableFindings: [{ text: 'Service in the Army is conceded.' }],
          reasons: [
            {
              category: 'nexus',
              text: 'The letter did not connect the knee pain to service.',
            },
          ],
          evidenceConsidered: ['Service treatment records'],
          extractionConfidence: 1,
          userConfirmed: true,
        },
      },
    ],
  },
  d: {
    id: 'd',
    label: 'mixed decision',
    user: {
      onboardingStatus: 'complete',
      onboardingStep: 'review',
      accountStatus: 'active',
      currentWorkingCaseId: 'case-d',
    },
    documents: [
      {
        path: 'cases/case-d',
        data: { displayName: 'Open Case', status: 'decisionReceived' },
      },
      {
        path: 'decisions/decision-d',
        data: {
          caseId: 'case-d',
          decisionDate: '2026-03-01',
          receivedDate: '2026-03-15',
          sourceDocumentId: null,
          sourceType: 'documentExtracted',
          status: 'confirmed',
          benefitType: 'compensation',
          overallSummary: 'One issue was granted, one denied, and one deferred.',
          reviewDeadline: '2027-03-01',
          deadlineRuleVersionId: 'va-rules',
          schemaVersion: 1,
        },
      },
      issue('back', 'Back pain', 'musculoskeletal', 'granted', 20),
      issue('knee', 'Knee pain', 'musculoskeletal', 'denied', null),
      issue('nerve', 'Radiculopathy', 'neurological', 'deferred', null),
    ].flat(),
  },
};

function issue(id, name, bodySystem, outcome, rating) {
  return [
    {
      path: `conditions/${id}`,
      data: {
        displayName: name,
        bodySystem,
        status: 'potential',
        current: true,
        diagnosed: false,
        discoverySource: 'questionnaire',
        sourceQuestionnaireId: 'condition-discovery',
        sourceQuestionId: id,
        sourceType: 'veteranReported',
        schemaVersion: 1,
      },
    },
    {
      path: `claimIssues/${id}`,
      data: {
        conditionId: id,
        displayName: name,
        activeCaseId: 'case-d',
        status: 'potential',
      },
    },
    {
      path: `decisionIssues/${id}`,
      data: {
        decisionId: 'decision-d',
        claimIssueId: id,
        displayName: name,
        outcome,
        ratingPercent: rating,
        effectiveDate: outcome === 'granted' ? '2026-03-01' : null,
        favorableFindings: [],
        reasons: [],
        evidenceConsidered: [],
        extractionConfidence: 1,
        userConfirmed: true,
      },
    },
  ];
}

function scenarioById(id) {
  const scenario = scenarios[id];
  if (!scenario) {
    throw new Error('Pass --scenario a, b, c, or d.');
  }
  return scenario;
}

module.exports = { scenarios, scenarioById };
