'use strict';

const YES_NO = [
  ['yes', 'Yes'],
  ['no', 'No'],
];

const SIDE = [
  ['right', 'Right'],
  ['left', 'Left'],
  ['both', 'Both'],
];

const MILD = [
  ['mild', 'Mild'],
  ['moderate', 'Moderate'],
  ['severe', 'Severe'],
];

const COURSE = [
  ['steady', 'Steady'],
  ['comes_and_goes', 'Comes and goes'],
  ['worse', 'Getting worse'],
  ['better', 'Getting better'],
  ['not_sure', "I'm not sure"],
];

const IMPACT = [
  ['work', 'Work'],
  ['walking', 'Walking'],
  ['standing', 'Standing'],
  ['sitting', 'Sitting'],
  ['lifting', 'Lifting'],
  ['sleep', 'Sleep'],
  ['self_care', 'Self-care'],
  ['none', 'None of these'],
];

const BED = [
  ['under_1', 'Less than 1 week'],
  ['1_to_2', '1 week to under 2 weeks'],
  ['2_to_4', '2 weeks to under 4 weeks'],
  ['4_to_6', '4 weeks to under 6 weeks'],
  ['6_plus', '6 weeks or more'],
];

const DEVICES = [
  ['cane', 'Cane'],
  ['walker', 'Walker'],
  ['brace', 'Brace'],
  ['crutches', 'Crutches'],
  ['wheelchair', 'Wheelchair'],
];

const RARE_JOINT = [
  ['infection', 'An infection a doctor tied to the joint'],
  ['gout', 'Gout'],
  ['growth', 'A benign bone growth'],
  ['paget', "Paget's disease"],
  ['osteoporosis', 'Osteoporosis leftovers'],
  ['soft_bones', 'Soft bones'],
  ['bursitis', 'Bursitis'],
  ['myositis', 'Myositis'],
];

const MUSCLE_GROUPS = [
  ['shoulder_shrug', 'Shoulder shrug and shoulder blade'],
  ['chest_lat', 'Chest and lat muscles that move the arm'],
  ['deltoid', 'Deltoid, lifting the arm'],
  ['rotator', 'Rotator cuff'],
  ['biceps', 'Biceps, bending the elbow'],
  ['triceps', 'Triceps, straightening the elbow'],
  ['forearm_flex', 'Forearm muscles that bend the wrist and fingers'],
  ['forearm_extend', 'Forearm muscles that straighten the wrist and fingers'],
  ['hand', 'Small muscles in the hand'],
  ['foot_sole', 'Sole of the foot'],
  ['calf', 'Calf'],
  ['shin', 'Shin'],
  ['hamstring', 'Hamstrings'],
  ['quad', 'Quadriceps'],
  ['inner_thigh', 'Inner thigh'],
  ['hip_flexor', 'Hip flexors'],
  ['buttock', 'Buttocks'],
  ['hip_rotator', 'Hip rotators'],
  ['abdomen', 'Abdominal wall'],
  ['spine', 'Back muscles along the spine'],
  ['breathing', 'Muscles of breathing'],
  ['neck_front', 'Front of the neck'],
  ['neck_side', 'Side and back of the neck'],
];

const questions = [];

function option(entry) {
  if (Array.isArray(entry)) {
    const [value, label, extra] = entry;
    return { value, label, ...(extra || {}) };
  }
  return entry;
}

function add(question) {
  questions.push({
    required: true,
    options: [],
    showWhen: [],
    createsCondition: null,
    createsEachOption: false,
    createsExcept: ['none', 'not_sure', 'not_applicable'],
    includeInIntake: true,
    order: questions.length,
    ...question,
    options: (question.options || []).map(option),
  });
}

function yesNo(id, prompt, showWhen, extra = {}) {
  add({
    id,
    prompt,
    answerType: 'singleChoice',
    options: YES_NO,
    showWhen,
    ...extra,
  });
}

function single(id, prompt, options, showWhen, extra = {}) {
  add({
    id,
    prompt,
    answerType: 'singleChoice',
    options,
    showWhen,
    ...extra,
  });
}

function multi(id, prompt, options, showWhen, extra = {}) {
  add({
    id,
    prompt,
    answerType: 'multiChoice',
    options,
    showWhen,
    createsEachOption: true,
    ...extra,
  });
}

function yearMonth(id, prompt, showWhen) {
  add({
    id,
    prompt,
    answerType: 'yearMonth',
    required: false,
    showWhen,
  });
}

function note(id, prompt, showWhen) {
  add({
    id,
    prompt,
    answerType: 'note',
    required: false,
    showWhen,
  });
}

function yes(id) {
  return [{ questionId: id, equals: 'yes' }];
}

function includes(id, value) {
  return [{ questionId: id, includes: value }];
}

function includesAny(id, values) {
  return [{ questionId: id, includesAny: values }];
}

function all(...parts) {
  return parts.flat();
}

function tail(moduleId, showWhen) {
  yearMonth(
    `${moduleId}.start`,
    'About when did this start? A month and year is enough.',
    showWhen,
  );
  single(`${moduleId}.course`, 'How has it behaved?', COURSE, showWhen);
  multi(`${moduleId}.impact`, 'What does this limit?', IMPACT, showWhen, {
    createsEachOption: false,
  });
  note(`${moduleId}.note`, 'Anything else about this, in your own words.', showWhen);
}

function voiding(prefix, showWhen) {
  single(
    `${prefix}.leak`,
    'How often do you leak and need a pad or absorbent material?',
    [
      ['never', 'Never'],
      ['under_daily', 'Less than once a day'],
      ['once', 'Once a day'],
      ['two_to_four', '2 to 4 times a day'],
      ['more', 'More than 4 times a day'],
    ],
    showWhen,
  );
  yesNo(`${prefix}.appliance`, 'Do you use a catheter or another appliance?', showWhen);
  single(
    `${prefix}.day`,
    'How long can you go between times you urinate during the day?',
    [
      ['over_3', 'More than 3 hours'],
      ['two_to_3', '2 to 3 hours'],
      ['one_to_2', '1 to 2 hours'],
      ['under_1', 'Less than 1 hour'],
    ],
    showWhen,
  );
  single(
    `${prefix}.night`,
    'How many times do you get up at night to urinate?',
    [
      ['0_1', '0 or 1'],
      ['2', '2'],
      ['3', '3'],
      ['4', '4'],
      ['5_plus', '5 or more'],
    ],
    showWhen,
  );
  single(
    `${prefix}.stream`,
    'How is the urine stream?',
    [
      ['normal', 'Normal'],
      ['slow', 'Slow or weak'],
      ['hesitant', 'Hesitant'],
      ['interrupted', 'Interrupted'],
      ['strain', 'I have to strain'],
    ],
    showWhen,
  );
}

function scar(showWhen) {
  multi(
    'scar.where',
    'Where are the scars?',
    [
      ['head', 'Head, face, or neck'],
      ['right_arm', 'Right arm or hand'],
      ['left_arm', 'Left arm or hand'],
      ['torso', 'Chest or belly'],
      ['back', 'Back'],
      ['right_leg', 'Right leg or foot'],
      ['left_leg', 'Left leg or foot'],
    ],
    showWhen,
    { createsEachOption: false },
  );
  single(
    'scar.painCount',
    'How many of those scars hurt?',
    [
      ['0', '0'],
      ['1', '1'],
      ['2', '2'],
      ['3', '3'],
      ['4', '4'],
      ['5_plus', '5 or more'],
    ],
    showWhen,
  );
  single(
    'scar.unstableCount',
    'How many lose their covering or open up?',
    [
      ['0', '0'],
      ['1', '1'],
      ['2', '2'],
      ['3', '3'],
      ['4', '4'],
      ['5_plus', '5 or more'],
    ],
    showWhen,
  );
  yesNo('scar.limit', 'Does a scar limit movement?', showWhen);
  multi(
    'scar.face',
    'What is visible on the head, face, or neck?',
    [
      ['mark', 'A visible mark'],
      ['uneven', 'One feature looks uneven'],
      ['missing', 'Tissue is missing'],
      ['none', 'None of these'],
    ],
    all(showWhen, includes('scar.where', 'head')),
    { createsEachOption: false },
  );
}

function spine(id, noun, limbNoun, travelPrompt) {
  const gate = yes(id);
  multi(
    `${id}.which`,
    `Which of these fit your ${noun}?`,
    [
      ['strain', 'Strain'],
      ['arthritis', 'Arthritis'],
      ['disc', 'A disc problem'],
      ['stenosis', 'Spinal stenosis'],
      ['fracture', 'A fracture'],
      ['surgery', 'A fusion or other surgery'],
      ['not_sure', "I'm not sure"],
      ['none', 'None of these'],
    ],
    gate,
  );
  yesNo(`${id}.flare`, `Does your ${noun} flare up?`, gate);
  single(
    `${id}.flareFrequency`,
    'How often?',
    [
      ['few', 'A few times a year'],
      ['monthly', 'Monthly'],
      ['weekly', 'Weekly'],
      ['more', 'More often than weekly'],
    ],
    yes(`${id}.flare`),
  );
  multi(
    `${id}.flareLimit`,
    'During a flare, what is hard to do?',
    [
      ['bend', 'Bend'],
      ['stand', 'Stand'],
      ['sit', 'Sit'],
      ['walk', 'Walk'],
      ['lift', 'Lift'],
      ['sleep', 'Sleep'],
    ],
    yes(`${id}.flare`),
    { createsEachOption: false },
  );
  yesNo(`${id}.${limbNoun}`, travelPrompt, gate, {
    createsCondition: null,
  });
  single(`${id}.${limbNoun}Side`, 'Which side?', SIDE, yes(`${id}.${limbNoun}`));
  multi(
    `${id}.${limbNoun}Feel`,
    'How does that feel?',
    [
      ['constant', 'Constant pain'],
      ['intermittent', 'Pain that comes and goes'],
      ['numb', 'Numbness'],
      ['tingle', 'Tingling'],
    ],
    yes(`${id}.${limbNoun}`),
    { createsEachOption: false },
  );
  single(`${id}.${limbNoun}Severity`, 'How bad is it?', MILD, yes(`${id}.${limbNoun}`));
  yesNo(
    `${id}.bedRest`,
    `In the past year, has a doctor ordered bed rest for your ${noun}?`,
    gate,
  );
  single(`${id}.bedRestDuration`, 'About how long, in total?', BED, yes(`${id}.bedRest`));
  yesNo(
    `${id}.device`,
    `Do you use a cane, walker, brace, crutches, or a wheelchair because of your ${noun}?`,
    gate,
  );
  multi(`${id}.deviceWhich`, 'Which ones?', DEVICES, yes(`${id}.device`), {
    createsEachOption: false,
  });
  single(
    `${id}.deviceOften`,
    'How often?',
    [
      ['occasional', 'Occasional'],
      ['regular', 'Regular'],
      ['constant', 'Constant'],
    ],
    yes(`${id}.device`),
  );
  yesNo(
    `${id}.bowel`,
    `Have you had bowel or bladder trouble that you were told is from your ${noun}?`,
    gate,
  );
  yesNo(
    `${id}.stiff`,
    `Is your ${noun} stuck in one position, so you cannot straighten up or bend?`,
    gate,
  );
  tail(id, gate);
}

function perChecked(parentId, items, ask) {
  for (const [value, label] of items) {
    ask(value, label, includes(parentId, value));
  }
}

function definition() {
  return {
    id: 'condition-discovery-v2',
    name: 'Condition discovery',
    type: 'conditionDiscovery',
    version: 2,
    status: 'active',
    entryQuestionId: 'head',
    schemaVersion: 1,
    questions: questions.map((question) => ({ ...question })),
  };
}

const GATES = [
  ['head', 'Do you have recurring headaches, dizziness, or other problems with your head or nerves?'],
  ['eyes', 'Do you have trouble with your eyes or vision?'],
  ['hearing', 'Do you have trouble hearing, ringing in the ears, or balance problems?'],
  ['ent', 'Do you have recurring nose, sinus, or throat problems?'],
  ['respiratory', 'Do you have recurring breathing problems?'],
  ['sleep', 'Do you have trouble sleeping, or does your breathing stop while you sleep?'],
  ['cardiovascular', 'Do you have a heart, blood pressure, or circulation problem?'],
  ['gastrointestinal', 'Do you have recurring stomach or bowel problems?'],
  ['genitourinary', 'Do you have recurring kidney, bladder, or urinary problems?'],
  ['endocrine', 'Do you have thyroid trouble, diabetes, or another hormone problem?'],
  ['skin', 'Do you have a recurring skin condition?'],
  ['back', 'Do you have recurring back pain, stiffness, or limited movement?'],
  ['neck', 'Do you have recurring neck pain, stiffness, or limited movement?'],
  [
    'joints',
    'Do you have recurring pain or an old injury in a joint, such as a shoulder, arm, elbow, wrist, hand, hip, knee, ankle, or foot?',
  ],
  ['nerves', 'Do you have numbness, tingling, or weakness in your arms or legs?'],
  ['mental', 'Do you have depression, anxiety, or another mental health concern you want to include?'],
  ['dental', 'Do you have a jaw, tooth, or mouth problem from service?'],
  ['reproductive', 'Do you have a reproductive-organ condition you want to include?'],
  ['blood', 'Do you have a blood, immune, or infectious condition you want to include?'],
  ['general', 'Do you have chronic fatigue, fibromyalgia, or another whole-body condition you want to include?'],
];

for (const [id, prompt] of GATES) {
  yesNo(id, prompt, [], { section: 'gates' });
}

const heartGate = yes('cardiovascular');
multi(
  'heart.which',
  'Which of these has a doctor named, or do you live with?',
  [
    ['chest_pain', 'Chest pain or pressure'],
    ['heart_attack', 'Heart attack'],
    ['heart_failure', 'Heart failure'],
    ['coronary', 'Coronary heart disease'],
    ['palpitations', 'Palpitations or an abnormal heartbeat'],
    ['valve', 'A heart murmur or valve problem'],
    ['high_bp', 'High blood pressure'],
    ['low_bp', 'Low blood pressure'],
    ['procedure', 'A procedure such as a stent, bypass, pacemaker, or defibrillator'],
    ['varicose', 'Varicose veins'],
    ['raynaud', "Raynaud's or fingers that change color in the cold"],
    ['aneurysm', 'An aneurysm'],
    ['av_fistula', 'A traumatic connection between an artery and a vein'],
    ['erythromelalgia', 'Burning pain in the hands or feet when warm'],
    ['none', 'None of these'],
  ],
  heartGate,
  { section: 'heart' },
);
yesNo('heart.medicine', 'Do you take medicine regularly for your heart or blood pressure?', heartGate, {
  section: 'heart',
});
yearMonth('heart.attackWhen', 'About when was the heart attack?', includes('heart.which', 'heart_attack'));
multi(
  'heart.procedure',
  'Which procedure?',
  [
    ['stent', 'Stent or angioplasty'],
    ['bypass', 'Bypass surgery'],
    ['pacemaker', 'Pacemaker'],
    ['defibrillator', 'Defibrillator'],
    ['valve', 'Valve replacement'],
    ['other', 'Other'],
  ],
  includes('heart.which', 'procedure'),
  { section: 'heart' },
);
yesNo(
  'heart.hospital',
  'Have you been hospitalized for your heart, other than a procedure you already counted?',
  heartGate,
  { section: 'heart' },
);
multi(
  'vein.where',
  'Where are the varicose veins?',
  [
    ['right_leg', 'Right leg'],
    ['left_leg', 'Left leg'],
    ['both_legs', 'Both legs'],
    ['right_arm', 'Right arm'],
    ['left_arm', 'Left arm'],
    ['both_arms', 'Both arms'],
  ],
  includes('heart.which', 'varicose'),
  { section: 'heart', createsEachOption: false },
);
multi(
  'vein.symptoms',
  'What do you notice in that limb?',
  [
    ['stand', 'Aching or fatigue after standing'],
    ['walk', 'Aching or fatigue after walking'],
    ['raise', 'Better when I raise the limb'],
    ['stockings', 'Better with compression stockings'],
    ['rest', 'Pain at rest'],
    ['swell_comes', 'Swelling that comes and goes'],
    ['swell_stays', 'Swelling that stays'],
    ['sore_closes', 'A sore that opens and closes'],
    ['sore_stays', 'A sore that stays open'],
    ['color', 'Color change or a rash on the skin'],
    ['none', 'None of these'],
  ],
  includes('heart.which', 'varicose'),
  { section: 'heart', createsEachOption: false },
);
single(
  'raynaud.often',
  "How often do the color changes happen?",
  [
    ['under_weekly', 'Less than once a week'],
    ['1_3', '1 to 3 times a week'],
    ['4_6', '4 to 6 times a week'],
    ['daily', 'Daily'],
  ],
  includes('heart.which', 'raynaud'),
  { section: 'heart' },
);
yesNo('raynaud.sores', 'Do you have sores on the fingers?', includes('heart.which', 'raynaud'), {
  section: 'heart',
});
yesNo('raynaud.lost', 'Has a fingertip been lost?', includes('heart.which', 'raynaud'), {
  section: 'heart',
});
multi(
  'aneurysm.which',
  'Where is the aneurysm?',
  [
    ['aorta', 'Aorta'],
    ['large', 'Another large artery'],
    ['small', 'A small artery'],
  ],
  includes('heart.which', 'aneurysm'),
  { section: 'heart' },
);
yesNo('aneurysm.symptoms', 'Does it cause symptoms?', includes('heart.which', 'aneurysm'), {
  section: 'heart',
});
yesNo('aneurysm.surgery', 'Have you had surgery for it?', includes('heart.which', 'aneurysm'), {
  section: 'heart',
});
yesNo(
  'aneurysm.unsafe',
  'Has a doctor said the aorta aneurysm is large enough that exertion is unsafe?',
  includes('aneurysm.which', 'aorta'),
  { section: 'heart' },
);
single(
  'erythromelalgia.often',
  'How often is the burning pain?',
  [
    ['under_3', 'Less than 3 times a week'],
    ['3_plus', 'At least 3 times a week'],
    ['daily', 'Daily'],
    ['more_than_daily', 'More than once a day'],
  ],
  includes('heart.which', 'erythromelalgia'),
  { section: 'heart' },
);
yesNo(
  'erythromelalgia.tasks',
  'Does it stop you from most daily tasks?',
  includes('heart.which', 'erythromelalgia'),
  { section: 'heart' },
);
yesNo('erythromelalgia.treatment', 'Does treatment help?', includes('heart.which', 'erythromelalgia'), {
  section: 'heart',
});
tail('heart', heartGate);

const headGate = yes('head');
multi(
  'head.which',
  'Which of these fit?',
  [
    ['migraine', 'Migraine or other severe headaches'],
    ['dizzy', 'Dizziness or fainting'],
    ['injury', 'A head injury or concussion'],
    ['seizure', 'Seizures'],
    ['parkinsons', "Parkinson's disease"],
    ['ms', 'Multiple sclerosis'],
    ['als', 'ALS'],
    ['narcolepsy', 'Narcolepsy'],
    ['memory', 'Memory loss that has not gone away'],
    ['none', 'None of these'],
  ],
  headGate,
  { section: 'head' },
);
multi(
  'headache.pain',
  'How does the headache feel?',
  [
    ['constant', 'Constant'],
    ['throbbing', 'Throbbing'],
    ['one_side', 'One side'],
    ['both_sides', 'Both sides'],
    ['worse_activity', 'Worse with activity'],
  ],
  includes('head.which', 'migraine'),
  { section: 'head', createsEachOption: false },
);
multi(
  'headache.other',
  'What else comes with it?',
  [
    ['nausea', 'Nausea'],
    ['vomiting', 'Vomiting'],
    ['light', 'Light sensitivity'],
    ['sound', 'Sound sensitivity'],
    ['vision', 'Vision changes'],
    ['pins', 'Pins and needles'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'migraine'),
  { section: 'head', createsEachOption: false },
);
single(
  'headache.duration',
  'How long does a typical headache last?',
  [
    ['under_day', 'Less than a day'],
    ['1_2', '1 to 2 days'],
    ['over_2', 'More than 2 days'],
  ],
  includes('head.which', 'migraine'),
  { section: 'head' },
);
yesNo(
  'headache.prostrating',
  'Do you have attacks that leave you exhausted or unable to do ordinary activities?',
  includes('head.which', 'migraine'),
  { section: 'head' },
);
single(
  'headache.prostratingFrequency',
  'How often are those attacks?',
  [
    ['under_2_months', 'Less than every 2 months'],
    ['once_2_months', 'Once in 2 months'],
    ['monthly', 'Once a month'],
    ['more', 'More than once a month'],
  ],
  yes('headache.prostrating'),
  { section: 'head' },
);
multi(
  'head.injury',
  'Right after a blow to the head, did any of these happen?',
  [
    ['blackout', 'Blacked out'],
    ['memory', 'Lost memory of the event'],
    ['stars', 'Saw stars or felt disoriented'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'injury'),
  { section: 'head', createsEachOption: false },
);
yesNo('head.injuryOngoing', 'Are any of those symptoms still with you?', includes('head.which', 'injury'), {
  section: 'head',
});
yesNo('seizure.medicine', 'Do you take medicine regularly so you do not have seizures?', includes('head.which', 'seizure'), {
  section: 'head',
});
yesNo('seizure.surgery', 'Have you had surgery for seizures?', includes('head.which', 'seizure'), {
  section: 'head',
});
yesNo('seizure.witness', 'Has someone else seen you have a seizure?', includes('head.which', 'seizure'), {
  section: 'head',
});
yearMonth('seizure.first', 'About when was the first one?', includes('head.which', 'seizure'));
yearMonth('seizure.last', 'About when was the most recent one?', includes('head.which', 'seizure'));
yesNo('seizure.minor', 'Have you had minor seizures? A minor seizure is a brief lapse, staring, blinking, a jerk, or suddenly going limp.', includes('head.which', 'seizure'), {
  section: 'head',
});
single(
  'seizure.minorCount',
  'In the past 6 months, how many minor seizures?',
  [
    ['none_or_one', 'None or one'],
    ['two_plus', 'Two or more'],
  ],
  yes('seizure.minor'),
  { section: 'head' },
);
single(
  'seizure.minorWeek',
  'In a typical week, how many?',
  [
    ['up_to_4', 'Up to 4 a week'],
    ['5_8', '5 to 8 a week'],
    ['9_10', '9 to 10 a week'],
    ['over_10', 'More than 10 a week'],
  ],
  all(yes('seizure.minor'), [{ questionId: 'seizure.minorCount', equals: 'two_plus' }]),
  { section: 'head' },
);
yesNo(
  'seizure.major',
  'Have you had major seizures? A major seizure is a convulsion with loss of consciousness.',
  includes('head.which', 'seizure'),
  { section: 'head' },
);
single(
  'seizure.majorSpan',
  'How recently?',
  [
    ['none_2_years', 'None in the past 2 years'],
    ['one_2_years', 'At least one in the past 2 years'],
    ['two_year', 'At least two in the past year'],
  ],
  yes('seizure.major'),
  { section: 'head' },
);
single(
  'seizure.majorOften',
  'About how often are the major seizures?',
  [
    ['under_6_months', 'Less than one in the past 6 months'],
    ['one_6_months', 'At least one in the past 6 months'],
    ['every_4', 'About every 4 months'],
    ['every_3', 'About every 3 months'],
    ['monthly', 'About monthly'],
  ],
  yes('seizure.major'),
  { section: 'head' },
);
multi(
  'cns.which',
  'Has a doctor named any of these?',
  [
    ['infection', 'Meningitis or a brain infection'],
    ['stroke', 'A stroke, TIA, or brain bleed'],
    ['hydrocephalus', 'Water on the brain'],
    ['tumor', 'A brain or spinal cord tumor'],
    ['cord', 'A spinal cord injury'],
    ['palsy', 'Bulbar or pseudobulbar palsy'],
    ['none', 'None of these'],
  ],
  headGate,
  { section: 'head' },
);
single(
  'cns.active',
  'Is an infection still active?',
  [
    ['yes', 'Yes'],
    ['leftovers', 'No, with leftovers'],
  ],
  includes('cns.which', 'infection'),
  { section: 'head' },
);
yesNo(
  'cranial.ask',
  'Do you have face pain, face weakness, or numbness on the face?',
  headGate,
  { section: 'head' },
);
const cranialGate = yes('cranial.ask');
multi(
  'cranial.place',
  'Where on the face is the nerve problem?',
  [
    ['upper', 'Upper face'],
    ['mid', 'Mid face'],
    ['lower', 'Lower face'],
    ['jaw', 'Jaw'],
  ],
  cranialGate,
  { section: 'head', createsEachOption: true },
);
multi(
  'cranial.face',
  'What does it do?',
  [
    ['constant', 'Constant face pain'],
    ['comes', 'Pain that comes and goes'],
    ['numb', 'Numbness'],
    ['weak', 'Weakness of the face'],
    ['speech', 'Trouble speaking or swallowing'],
    ['none', 'None of these'],
  ],
  cranialGate,
  { section: 'head', createsEachOption: false },
);
single('cranial.side', 'Which side of the face?', SIDE, cranialGate, { section: 'head' });
single('cranial.severity', 'How bad is it?', MILD, cranialGate, { section: 'head' });
yesNo('narcolepsy.medicine', 'Do you take medicine regularly for this?', includes('head.which', 'narcolepsy'), {
  section: 'head',
});
multi(
  'narcolepsy.symptoms',
  'Which of these happen?',
  [
    ['sleepy', 'Daytime sleepiness'],
    ['attacks', 'Sleep attacks'],
    ['tone', 'Sudden loss of muscle tone while awake'],
    ['paralysis', 'Unable to move when first waking'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'narcolepsy'),
  { section: 'head', createsEachOption: false },
);
single(
  'narcolepsy.often',
  'In the past 6 months, how many sleep attacks or losses of tone?',
  [
    ['none_or_one', 'None or one'],
    ['two_plus', 'Two or more'],
  ],
  includes('head.which', 'narcolepsy'),
  { section: 'head' },
);
single(
  'narcolepsy.week',
  'In a typical week, how many?',
  [
    ['up_to_4', 'Up to 4 a week'],
    ['5_8', '5 to 8 a week'],
    ['9_10', '9 to 10 a week'],
    ['over_10', 'More than 10 a week'],
  ],
  [{ questionId: 'narcolepsy.often', equals: 'two_plus' }],
  { section: 'head' },
);
multi(
  'parkinsons.which',
  "Which name did a doctor use?",
  [
    ['parkinsons', "Parkinson's disease"],
    ['parkinsonism', 'Parkinsonism'],
    ['psp', 'Progressive supranuclear palsy'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head' },
);
multi(
  'parkinsons.signs',
  'Which of these do you have?',
  [
    ['face', 'A face that does not move much'],
    ['stoop', 'Stooped posture'],
    ['balance', 'Poor balance'],
    ['slow', 'Slow movement'],
    ['tremor', 'Tremor'],
    ['stiff', 'Stiffness'],
    ['chew', 'Trouble chewing'],
    ['swallow', 'Trouble swallowing'],
    ['constipation', 'Constipation'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head', createsEachOption: false },
);
multi(
  'parkinsons.where',
  'Where is the slow movement, tremor, or stiffness?',
  [
    ['right_arm', 'Right arm'],
    ['left_arm', 'Left arm'],
    ['right_leg', 'Right leg'],
    ['left_leg', 'Left leg'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head', createsEachOption: false },
);
single('parkinsons.severity', 'How bad is that limb trouble?', MILD, includes('head.which', 'parkinsons'), {
  section: 'head',
});
single(
  'parkinsons.speech',
  'How is your speech?',
  [
    ['normal', 'Normal'],
    ['slight', 'Slightly affected'],
    ['very', 'Very affected'],
    ['none', 'I cannot speak'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head' },
);
single(
  'parkinsons.smell',
  'How is your sense of smell?',
  [
    ['normal', 'Normal'],
    ['partial', 'Partial loss'],
    ['complete', 'Complete loss'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head' },
);
single(
  'parkinsons.taste',
  'How is your sense of taste?',
  [
    ['normal', 'Normal'],
    ['partial', 'Partial loss'],
    ['complete', 'Complete loss'],
  ],
  includes('head.which', 'parkinsons'),
  { section: 'head' },
);
yesNo('parkinsons.sleep', 'Has this changed your sleep?', includes('head.which', 'parkinsons'), {
  section: 'head',
});
yesNo('parkinsons.sex', 'Has this changed sexual function?', includes('head.which', 'parkinsons'), {
  section: 'head',
});
yesNo('parkinsons.mental', 'Have you noticed mental changes with this?', includes('head.which', 'parkinsons'), {
  section: 'head',
});
const neuroWhen = headGate;
multi(
  'neuro.speech',
  'Has this changed speech or swallowing?',
  [
    ['hoarse', 'Hoarseness'],
    ['unclear', 'People cannot understand my speech'],
    ['cannot', 'I cannot speak'],
    ['nasal', 'Food comes back through my nose'],
    ['swallow', 'Trouble swallowing'],
    ['none', 'None of these'],
  ],
  neuroWhen,
  { section: 'head', createsEachOption: false },
);
multi(
  'neuro.sleep',
  'Has this changed sleep?',
  [
    ['insomnia', 'Insomnia'],
    ['attacks', 'Sleep attacks'],
    ['sleepy', 'Daytime sleepiness that will not go away'],
    ['machine', 'A breathing machine at night'],
    ['none', 'None of these'],
  ],
  neuroWhen,
  { section: 'head', createsEachOption: false },
);
yesNo('neuro.sex', 'Has this caused trouble with erections, or with lubrication and arousal?', neuroWhen, {
  section: 'head',
});
yesNo('neuro.weak', 'Is an arm or leg weak because of this?', neuroWhen, { section: 'head' });
multi(
  'neuro.weakWhere',
  'Which limb?',
  [
    ['right_arm', 'Right arm'],
    ['left_arm', 'Left arm'],
    ['right_leg', 'Right leg'],
    ['left_leg', 'Left leg'],
  ],
  yes('neuro.weak'),
  { section: 'head', createsEachOption: false },
);
single('neuro.weakSeverity', 'How bad is the weakness?', MILD, yes('neuro.weak'), { section: 'head' });
multi(
  'als.breathing',
  'How is your breathing with ALS?',
  [
    ['short', 'Short of breath'],
    ['machine', 'A breathing machine'],
    ['tube', 'A breathing tube in the neck'],
    ['none', 'None of these'],
  ],
  includes('head.which', 'als'),
  { section: 'head', createsEachOption: false },
);
voiding(
  'neuro',
  includesAny('head.which', ['parkinsons', 'ms', 'als']),
);
tail('head', headGate);

const eyeGate = yes('eyes');
multi(
  'eye.which',
  'Which of these fit?',
  [
    ['glasses', 'Glasses or contacts'],
    ['dry', 'Dry eyes'],
    ['cataract', 'Cataracts'],
    ['glaucoma', 'Glaucoma'],
    ['retina', 'A retina or macular problem'],
    ['double', 'Double vision'],
    ['loss', 'Loss of an eye or blindness in one eye'],
    ['20_200', 'Vision of 20/200 or worse in the better eye even with glasses'],
    ['surgery', 'Laser or other surgery to correct vision'],
    ['injury', 'An eye injury'],
    ['growth', 'A growth on or in the eye'],
    ['none', 'None of these'],
  ],
  eyeGate,
  { section: 'eyes' },
);
single('eye.side', 'Which eye?', SIDE, eyeGate, { section: 'eyes' });
yesNo('eye.incapacitating', 'In the past year, has an eye doctor ordered bed rest for this?', eyeGate, {
  section: 'eyes',
});
single('eye.bed', 'About how long, in total?', BED, yes('eye.incapacitating'), { section: 'eyes' });
tail('eyes', eyeGate);

const hearingGate = yes('hearing');
yesNo(
  'hearing.ringing',
  'Do you have persistent or recurring noises in your ears or head, such as ringing, buzzing, or humming?',
  hearingGate,
  { section: 'hearing', createsCondition: 'Ringing in the ears' },
);
yesNo(
  'hearing.change',
  'Has your hearing changed enough to affect what you can do?',
  hearingGate,
  { section: 'hearing', createsCondition: 'Hearing change' },
);
yesNo('hearing.aid', 'Have you worn a hearing aid?', hearingGate, { section: 'hearing' });
yesNo(
  'hearing.noise',
  'Were you around loud noise, blasts, or gunfire that left your hearing worse or made your ears ring?',
  hearingGate,
  { section: 'hearing' },
);
multi(
  'ear.which',
  'Which of these fit?',
  [
    ['vertigo', 'Spinning or vertigo'],
    ['meniere', "Meniere's disease"],
    ['infection', 'A chronic ear infection'],
    ['growth', 'A growth in the ear'],
    ['surgery', 'Ear surgery'],
    ['none', 'None of these'],
  ],
  hearingGate,
  { section: 'hearing' },
);
multi(
  'ear.vertigo',
  'What comes with the spinning?',
  [
    ['vertigo', 'Vertigo'],
    ['stagger', 'Staggering'],
    ['hearing', 'Hearing gets worse with the spells'],
    ['ring', 'Ringing with the spells'],
  ],
  includes('ear.which', 'vertigo'),
  { section: 'hearing', createsEachOption: false },
);
single(
  'ear.vertigoOften',
  'How often?',
  [
    ['under_monthly', 'Less than once a month'],
    ['1_4', '1 to 4 times a month'],
    ['weekly', 'More than once a week'],
  ],
  includes('ear.which', 'vertigo'),
  { section: 'hearing' },
);
single(
  'ear.vertigoDuration',
  'How long does a spell last?',
  [
    ['under_hour', 'Less than an hour'],
    ['1_24', '1 to 24 hours'],
    ['over_24', 'More than 24 hours'],
  ],
  includes('ear.which', 'vertigo'),
  { section: 'hearing' },
);
multi(
  'ear.infection',
  'What does the ear infection do?',
  [
    ['swelling', 'Swelling'],
    ['itch', 'Itching'],
    ['drainage', 'Drainage'],
    ['hole', 'A hole in the eardrum'],
    ['face', 'Facial weakness'],
    ['none', 'None of these'],
  ],
  includes('ear.which', 'infection'),
  { section: 'hearing', createsEachOption: false },
);
single('ear.surgery', 'Which ear was operated on?', SIDE, includes('ear.which', 'surgery'), {
  section: 'hearing',
});
tail('hearing', hearingGate);

const entGate = yes('ent');
multi(
  'ent.which',
  'Which of these fit?',
  [
    ['sinusitis', 'Sinusitis'],
    ['rhinitis', 'Hay fever or other rhinitis'],
    ['smell', 'A lost or reduced sense of smell'],
    ['taste', 'A lost or reduced sense of taste'],
    ['septum', 'A crooked septum from an injury'],
    ['hoarse', 'Hoarseness or a voice problem'],
    ['voice', 'Loss of the voice'],
    ['throat', 'A hole or injury in the throat'],
    ['nose', 'Part of the nose missing'],
    ['growth', 'A growth in the nose or throat'],
    ['none', 'None of these'],
  ],
  entGate,
  { section: 'ent' },
);
single(
  'smell.level',
  'How is your sense of smell?',
  [
    ['some', 'I can still smell some things'],
    ['none', 'I cannot smell anything'],
    ['not_smell', 'This is not a smell problem'],
  ],
  includes('ent.which', 'smell'),
  { section: 'ent' },
);
single(
  'taste.level',
  'How is your sense of taste?',
  [
    ['weaker', 'Taste is weaker'],
    ['none', 'I cannot taste anything'],
    ['not_taste', 'This is not a taste problem'],
  ],
  includes('ent.which', 'taste'),
  { section: 'ent' },
);
multi(
  'sinus.symptoms',
  'What do the sinuses do?',
  [
    ['headache', 'Headaches'],
    ['pain', 'Pain'],
    ['tender', 'Tenderness'],
    ['discharge', 'Thick or colored discharge'],
    ['crust', 'Crusting'],
    ['constant', 'Near-constant sinusitis'],
  ],
  includes('ent.which', 'sinusitis'),
  { section: 'ent', createsEachOption: false },
);
single(
  'sinus.episodes',
  'In the past year, how many sinus flares did you have with headache, pain, and discharge or crusting, that did not put you on doctor-ordered bed rest?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4', '4'],
    ['5', '5'],
    ['6', '6'],
    ['7_plus', '7 or more'],
  ],
  includes('ent.which', 'sinusitis'),
  { section: 'ent' },
);
single(
  'sinus.antibiotics',
  'In the past year, how many times did a doctor put you on 4 to 6 weeks of antibiotics and bed rest for your sinuses?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3_plus', '3 or more'],
  ],
  includes('ent.which', 'sinusitis'),
  { section: 'ent' },
);
yesNo('sinus.surgery', 'Have you had sinus surgery?', includes('ent.which', 'sinusitis'), { section: 'ent' });
single(
  'sinus.surgeryCount',
  'How many times?',
  [
    ['once', 'Once'],
    ['more', 'More than once'],
  ],
  yes('sinus.surgery'),
  { section: 'ent' },
);
yesNo('sinus.bone', 'Did a bone infection follow that surgery?', yes('sinus.surgery'), { section: 'ent' });
multi(
  'nose.breathe',
  'Can you breathe through your nose?',
  [
    ['both', 'I can breathe through both sides'],
    ['one', 'One side is blocked'],
    ['both_blocked', 'Both sides are badly blocked'],
    ['polyps', 'A doctor told me I have polyps'],
  ],
  entGate,
  { section: 'ent', createsEachOption: false },
);
multi(
  'voice.which',
  'What happened to your voice?',
  [
    ['hoarse', 'Hoarseness'],
    ['whisper', 'I can only whisper'],
    ['cannot', 'I cannot speak'],
    ['tube', 'A breathing tube in the neck'],
    ['part', 'Part of the voice box removed'],
    ['all', 'The whole voice box removed'],
  ],
  includes('ent.which', 'hoarse'),
  { section: 'ent', createsEachOption: false },
);
tail('ent', entGate);

const breathGate = yes('respiratory');
multi(
  'respiratory.which',
  'Which of these fit?',
  [
    ['asthma', 'Asthma'],
    ['cough', 'Chronic cough'],
    ['wheeze', 'Wheezing or shortness of breath'],
    ['bronchitis', 'Bronchitis'],
    ['copd', 'COPD, emphysema, or another lung problem'],
    ['clot', 'A blood clot in the lung'],
    ['collapse', 'A collapsed lung'],
    ['sarcoid', 'Sarcoidosis'],
    ['blood', 'Coughing up blood'],
    ['tb', 'Tuberculosis'],
    ['growth', 'A growth in the lung'],
    ['none', 'None of these'],
  ],
  breathGate,
  { section: 'respiratory' },
);
yesNo('respiratory.steroid', 'Do you take steroid pills or shots for your breathing?', breathGate, {
  section: 'respiratory',
});
single(
  'respiratory.steroidDose',
  'How are those steroids used?',
  [
    ['occasional', 'Occasional short courses'],
    ['low', 'A low daily dose'],
    ['high', 'A high daily dose'],
  ],
  yes('respiratory.steroid'),
  { section: 'respiratory' },
);
single(
  'respiratory.steroidYear',
  'How many courses in the past year?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4_plus', '4 or more'],
  ],
  yes('respiratory.steroid'),
  { section: 'respiratory' },
);
multi(
  'respiratory.inhaler',
  'Which inhalers do you use?',
  [
    ['rescue_some', 'A rescue inhaler now and then'],
    ['rescue_daily', 'A rescue inhaler every day'],
    ['steroid_some', 'A steroid inhaler now and then'],
    ['steroid_daily', 'A steroid inhaler every day'],
    ['none', 'None of these'],
  ],
  breathGate,
  { section: 'respiratory', createsEachOption: false },
);
yesNo('respiratory.oxygen', 'Do you use oxygen?', breathGate, { section: 'respiratory' });
single(
  'respiratory.oxygenHours',
  'How much of the day?',
  [
    ['not_all', 'Not all day'],
    ['over_17', 'More than 17 hours a day'],
  ],
  yes('respiratory.oxygen'),
  { section: 'respiratory' },
);
yesNo(
  'asthma.failure',
  'In the past year, did an asthma attack leave you unable to breathe and needing emergency care?',
  includes('respiratory.which', 'asthma'),
  { section: 'respiratory' },
);
single(
  'asthma.failureOften',
  'How often?',
  [
    ['none', 'None'],
    ['few', 'A few times in the year'],
    ['monthly', 'Monthly'],
    ['weekly', 'Weekly'],
  ],
  yes('asthma.failure'),
  { section: 'respiratory' },
);
single(
  'asthma.visits',
  'How often did you see a doctor for an asthma flare in the past year?',
  [
    ['under_monthly', 'Less than monthly'],
    ['monthly', 'Monthly or more'],
  ],
  includes('respiratory.which', 'asthma'),
  { section: 'respiratory' },
);
tail('respiratory', breathGate);

const sleepGate = yes('sleep');
multi(
  'sleep.which',
  'Which of these fit?',
  [
    ['apnea', 'Breathing that stops during sleep'],
    ['sleepy', 'Daytime sleepiness that will not go away'],
    ['insomnia', 'Trouble falling or staying asleep'],
    ['none', 'None of these'],
  ],
  sleepGate,
  { section: 'sleep' },
);
single(
  'sleep.study',
  'Have you had a sleep study?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_sure', "I'm not sure"],
  ],
  includes('sleep.which', 'apnea'),
  { section: 'sleep' },
);
yesNo('sleep.cpap', 'Do you use a CPAP or another breathing machine at night?', includes('sleep.which', 'apnea'), {
  section: 'sleep',
});
yesNo('sleep.medicine', 'Do you take medicine regularly for sleep?', sleepGate, { section: 'sleep' });
tail('sleep', sleepGate);

const giGate = yes('gastrointestinal');
multi(
  'gi.which',
  'Which of these fit?',
  [
    ['reflux', 'Heartburn, reflux, or a hiatal hernia'],
    ['ulcer', 'A stomach ulcer or chronic gastritis'],
    ['ibs', 'Irritable bowel or a similar problem'],
    ['ibd', "Crohn's disease or ulcerative colitis"],
    ['diverticulitis', 'Diverticulitis'],
    ['celiac', 'Celiac disease'],
    ['ostomy', 'A bag or a surgery that removed part of the bowel'],
    ['gallbladder', 'Gallbladder trouble'],
    ['hernia', 'A hernia in the groin or belly wall'],
    ['rectum', 'Hemorrhoids or other rectum or anus trouble'],
    ['liver', 'Liver problems'],
    ['pancreas', 'Pancreas trouble'],
    ['adhesion', 'Scar tissue in the belly after surgery or infection'],
    ['none', 'None of these'],
  ],
  giGate,
  { section: 'gi' },
);
yesNo('gi.medicine', 'Do you take a prescribed medicine every day for this?', giGate, { section: 'gi' });
single(
  'ibs.pain',
  'In the past 3 months, how often did belly pain come with a bowel movement?',
  [
    ['none', 'None'],
    ['once', 'At least once'],
    ['3_days', 'At least 3 days a month'],
    ['weekly', 'At least 1 day a week'],
  ],
  includes('gi.which', 'ibs'),
  { section: 'gi' },
);
multi(
  'ibs.signs',
  'What else changed?',
  [
    ['often', 'Stool comes more or less often'],
    ['look', 'Stool looks different'],
    ['bloat', 'Bloating'],
    ['strain', 'Straining or urgency'],
    ['mucus', 'Mucus'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'ibs'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'ibd.which',
  'Which of these fit Crohn\'s or ulcerative colitis?',
  [
    ['pills', 'Pills that are not immune drugs'],
    ['immune', 'Immune or biologic medicine'],
    ['failing', 'Treatment is not working'],
    ['hospital', 'Hospitalized at least once a year'],
    ['pain', 'Belly pain'],
    ['diarrhea', 'Diarrhea every day'],
    ['bleed', 'Bleeding from the rectum 6 or more times a day'],
    ['leak', 'Leaking stool'],
    ['surgery', 'A colectomy or a colostomy'],
    ['fever', 'Fever or anemia'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'ibd'),
  { section: 'gi', createsEachOption: false },
);
single(
  'ibd.diarrhea',
  'How often is the diarrhea?',
  [
    ['3_or_fewer', '3 or fewer times a day'],
    ['4_5', '4 or 5'],
    ['6_plus', '6 or more'],
  ],
  includes('ibd.which', 'diarrhea'),
  { section: 'gi' },
);
multi(
  'gi.ostomy',
  'What was done to the bowel?',
  [
    ['part', 'Part of the colon removed'],
    ['all', 'All of the colon removed'],
    ['colostomy', 'A permanent colostomy'],
    ['ileostomy', 'An ileostomy'],
    ['diarrhea_under_4', 'Diarrhea fewer than 4 times a day'],
    ['diarrhea_4', 'Diarrhea 4 or more times a day'],
    ['iv', 'IV fluids for dehydration more than twice in the past year'],
  ],
  includes('gi.which', 'ostomy'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'esophagus.which',
  'Which esophagus problem was named?',
  [
    ['gerd', 'GERD or reflux'],
    ['hiatal', 'Hiatal hernia'],
    ['para', 'Paraesophageal hernia'],
    ['swallow', 'Trouble swallowing'],
    ['narrow', 'A narrowing that needed stretching'],
    ['barrett', "Barrett's esophagus"],
    ['tear', 'A tear at the bottom of the esophagus'],
    ['cancer', 'Esophageal cancer'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'reflux'),
  { section: 'gi' },
);
multi(
  'esophagus.symptoms',
  'What do you live with?',
  [
    ['none_daily', 'No daily symptoms'],
    ['swallow', 'Trouble swallowing'],
    ['medicine', 'Daily medicine for swallowing'],
    ['wrong_way', 'Food or liquid going down the wrong way'],
    ['vomit', 'Vomiting'],
    ['nausea', 'Nausea'],
    ['watery', 'Watery bowel movements'],
    ['warning', 'Bowel movements that come without warning'],
    ['dump', 'Light-headed and sweating after meals'],
    ['pain', 'Pain within an hour of eating'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'reflux'),
  { section: 'gi', createsEachOption: false },
);
single(
  'esophagus.vomit',
  'How often do you vomit?',
  [
    ['under_2', 'Less than twice a week'],
    ['2_plus', 'Twice a week or more'],
    ['daily', 'Daily'],
  ],
  includes('esophagus.symptoms', 'vomit'),
  { section: 'gi' },
);
single(
  'esophagus.bowel',
  'How often are the watery bowel movements?',
  [
    ['under_3', 'Fewer than 3 a day'],
    ['3_5', '3 to 5 a day'],
    ['6_plus', '6 or more a day'],
  ],
  includes('esophagus.symptoms', 'watery'),
  { section: 'gi' },
);
single(
  'esophagus.stretch',
  'In the past year, how many times was a narrowing stretched?',
  [
    ['none', 'None'],
    ['1_2', 'Once or twice'],
    ['3_plus', '3 or more'],
  ],
  includes('esophagus.which', 'narrow'),
  { section: 'gi' },
);
single(
  'esophagus.barrett',
  'What did a biopsy show?',
  [
    ['high', 'High-grade changes'],
    ['low', 'Low-grade changes'],
    ['none', 'No dysplasia'],
    ['not_sure', "I'm not sure"],
  ],
  includes('esophagus.which', 'barrett'),
  { section: 'gi' },
);
yesNo('esophagus.barrettTreated', 'Has it been treated with surgery or ablation?', includes('esophagus.which', 'barrett'), {
  section: 'gi',
});
yesNo(
  'esophagus.surgery',
  'Have you had surgery for reflux, a hiatal hernia, or the esophagus?',
  includes('gi.which', 'reflux'),
  { section: 'gi' },
);
multi(
  'esophagus.surgeryEffects',
  'Since that surgery, which of these fit?',
  [
    ['none', 'No problems since'],
    ['tube', 'Tube feeding for more than 30 days in the last 6 months'],
    ['iv', 'IV nutrition for more than 30 days in the last 6 months'],
    ['dump', 'Dumping or food sitting in the stomach'],
  ],
  yes('esophagus.surgery'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'stomach.which',
  'Which stomach problem was named?',
  [
    ['ulcer', 'Peptic ulcer'],
    ['gastritis', 'Chronic gastritis'],
    ['pylori', 'H. pylori'],
    ['injury', 'Stomach injury'],
    ['removed', 'Part of the stomach removed'],
    ['vagotomy', 'A vagotomy or a connection surgery'],
    ['cancer', 'Stomach cancer'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'ulcer'),
  { section: 'gi' },
);
multi(
  'stomach.symptoms',
  'Which of these have happened?',
  [
    ['episode', 'Pain, nausea, or vomiting for at least 3 days in a row'],
    ['blood', 'Vomiting blood'],
    ['black', 'Black or tarry stools'],
    ['anemia', 'Hospitalized for anemia in the past year'],
    ['bleed_surgery', 'Surgery for a bleed or a hole'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'ulcer'),
  { section: 'gi', createsEachOption: false },
);
single(
  'stomach.episodeOften',
  'How often are those 3-day episodes?',
  [
    ['3_or_fewer', '3 times or fewer in the past year'],
    ['4_plus', '4 or more times in the past year'],
    ['constant', 'Pain that does not stop, with vomiting now and then'],
  ],
  includes('stomach.symptoms', 'episode'),
  { section: 'gi' },
);
multi(
  'gallbladder.which',
  'Which gallbladder problem was named?',
  [
    ['stones', 'Gallstones'],
    ['ongoing', 'Ongoing gallbladder or bile-duct disease'],
    ['removed', 'Gallbladder removed'],
    ['duct', 'A bile-duct injury or blockage'],
    ['cancer', 'Gallbladder cancer'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'gallbladder'),
  { section: 'gi' },
);
single(
  'gallbladder.attacks',
  'In the past year, how many attacks of right-upper belly pain did you have?',
  [
    ['none', 'None'],
    ['1_2', '1 or 2'],
    ['3_plus', '3 or more'],
  ],
  includes('gi.which', 'gallbladder'),
  { section: 'gi' },
);
multi(
  'gallbladder.attackFeel',
  'What came with those attacks?',
  [
    ['nausea', 'Nausea'],
    ['vomiting', 'Vomiting'],
    ['both', 'Both'],
  ],
  includes('gi.which', 'gallbladder'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'gallbladder.after',
  'Since the gallbladder was removed, which of these fit?',
  [
    ['none', 'No symptoms since'],
    ['pain_some', 'Belly pain now and then'],
    ['pain_often', 'Belly pain that keeps coming back'],
    ['stool_1_2', 'One or two watery stools a day'],
    ['stool_3', 'Three or more watery stools a day'],
  ],
  includes('gallbladder.which', 'removed'),
  { section: 'gi', createsEachOption: false },
);
yesNo('gallbladder.hospital', 'Were you hospitalized for this in the past 2 years?', includes('gi.which', 'gallbladder'), {
  section: 'gi',
});
multi(
  'hernia.where',
  'Where is the hernia?',
  [
    ['inguinal', 'Groin (inguinal)'],
    ['femoral', 'Femoral'],
    ['umbilical', 'Belly button'],
    ['incision', 'Incision'],
    ['ventral', 'Ventral'],
    ['other', 'Other'],
  ],
  includes('gi.which', 'hernia'),
  { section: 'gi' },
);
single('hernia.side', 'Which side?', SIDE, includes('gi.which', 'hernia'), { section: 'gi' });
yesNo('hernia.surgery', 'Have you had surgery for it?', includes('gi.which', 'hernia'), { section: 'gi' });
yesNo('hernia.back', 'Is the hernia back, or still there?', includes('gi.which', 'hernia'), { section: 'gi' });
yesNo('hernia.cannotFix', 'Has a doctor told you it cannot be repaired?', includes('gi.which', 'hernia'), {
  section: 'gi',
});
multi(
  'hernia.pain',
  'What does that pain limit?',
  [
    ['care', 'Bathing, dressing, or getting around'],
    ['bend', 'Bending'],
    ['stairs', 'Stairs'],
    ['walk', 'Walking'],
    ['none', 'None of these'],
  ],
  yes('hernia.cannotFix'),
  { section: 'gi', createsEachOption: false },
);
yesNo('hernia.painYear', 'Has that pain lasted 12 months or more?', yes('hernia.cannotFix'), {
  section: 'gi',
});
multi(
  'rectum.which',
  'Which rectum or anus problem was named?',
  [
    ['hemorrhoid', 'Hemorrhoids'],
    ['fistula', 'A fistula'],
    ['stricture', 'A stricture or severe constipation'],
    ['leak', 'Loss of control of the bowel'],
    ['prolapse', 'Rectal prolapse'],
    ['itch', 'Anal itching'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'rectum'),
  { section: 'gi' },
);
multi(
  'hemorrhoid.which',
  'What kind of hemorrhoids?',
  [
    ['external', 'External'],
    ['internal', 'Internal'],
    ['bleed', 'Bleeding that keeps happening'],
    ['clot', 'A clot 3 or more times a year'],
    ['prolapse', 'Internal ones that stay prolapsed'],
    ['none', 'None of these'],
  ],
  includes('rectum.which', 'hemorrhoid'),
  { section: 'gi', createsEachOption: false },
);
single(
  'fistula.count',
  'How many fistulas?',
  [
    ['one', 'One'],
    ['two', 'Two or more at once'],
    ['more', 'More than two almost all the time'],
  ],
  includes('rectum.which', 'fistula'),
  { section: 'gi' },
);
multi(
  'fistula.symptoms',
  'What does it do?',
  [
    ['drainage', 'Drainage'],
    ['pain', 'Pain'],
    ['abscess', 'An abscess'],
  ],
  includes('rectum.which', 'fistula'),
  { section: 'gi', createsEachOption: false },
);
yesNo('fistula.failed', 'Has treatment failed to close it?', includes('rectum.which', 'fistula'), {
  section: 'gi',
});
single(
  'sphincter.leak',
  'How often do you lose control of the bowel?',
  [
    ['under_6_months', 'Less than once every 6 months'],
    ['every_6_months', 'At least once every 6 months'],
    ['twice_month', 'Twice a month or more'],
    ['twice_week', 'Twice a week or more'],
    ['twice_day', 'Twice a day or more'],
  ],
  includes('rectum.which', 'leak'),
  { section: 'gi' },
);
yesNo('bowel.program', 'Do you have a doctor-ordered bowel program?', includes('rectum.which', 'leak'), {
  section: 'gi',
});
multi(
  'bowel.programWhich',
  'What does that program include?',
  [
    ['diet', 'Diet'],
    ['medicine', 'Medicine beyond a laxative'],
    ['digital', 'Digital stimulation'],
    ['surgery', 'Surgery'],
  ],
  yes('bowel.program'),
  { section: 'gi', createsEachOption: false },
);
single(
  'bowel.programWorks',
  'Does it work?',
  [
    ['yes', 'It works'],
    ['part', 'It partly works'],
    ['no', 'It does not work'],
  ],
  yes('bowel.program'),
  { section: 'gi' },
);
multi(
  'prolapse.which',
  'What does the prolapse do?',
  [
    ['itself', 'Goes back on its own'],
    ['push', 'I have to push it back'],
    ['stuck', 'It will not go back'],
    ['strain', 'Only after a bowel movement or straining'],
    ['other', 'At other times too'],
    ['repaired', 'It was repaired'],
  ],
  includes('rectum.which', 'prolapse'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'liver.which',
  'Which liver problem was named?',
  [
    ['hep_a', 'Hepatitis A'],
    ['hep_b', 'Hepatitis B'],
    ['hep_c', 'Hepatitis C'],
    ['auto', 'Autoimmune hepatitis'],
    ['fatty', 'Fatty liver or NASH'],
    ['cirrhosis', 'Cirrhosis'],
    ['abscess', 'A liver abscess'],
    ['transplant', 'A liver transplant'],
    ['cancer', 'Liver cancer'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'liver'),
  { section: 'gi' },
);
multi(
  'liver.symptoms',
  'What do you notice now?',
  [
    ['none_now', 'No symptoms now'],
    ['fatigue', 'Fatigue'],
    ['ill', 'Feeling ill'],
    ['appetite', 'Poor appetite'],
    ['itch', 'Itching'],
    ['joint', 'Joint pain'],
    ['weight', 'Weight loss'],
    ['fluid', 'Fluid in the belly'],
    ['weak', 'Weakness every day'],
    ['pain', 'Belly pain'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'liver'),
  { section: 'gi', createsEachOption: false },
);
single(
  'liver.fatigue',
  'How often is the fatigue?',
  [
    ['off', 'Off and on'],
    ['daily', 'Daily'],
  ],
  includes('liver.symptoms', 'fatigue'),
  { section: 'gi' },
);
yesNo(
  'liver.medicine',
  'Do you take medicine regularly for the liver, other than a one-time treatment?',
  includes('gi.which', 'liver'),
  { section: 'gi' },
);
single(
  'liver.transplant',
  'Where are you with a transplant?',
  [
    ['may', 'A doctor said I may need one'],
    ['waiting', 'I am waiting'],
    ['had', 'I had one'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'liver'),
  { section: 'gi' },
);
multi(
  'pancreas.which',
  'Which pancreas problem was named?',
  [
    ['chronic', 'Chronic pancreatitis'],
    ['removed', 'Part or all of the pancreas removed'],
    ['transplant', 'A pancreas transplant'],
    ['cancer', 'Pancreatic cancer'],
    ['none', 'None of these'],
  ],
  includes('gi.which', 'pancreas'),
  { section: 'gi' },
);
single(
  'pancreas.pain',
  'How often is there belly or mid-back pain from this?',
  [
    ['none', 'None'],
    ['yearly', 'Once a year'],
    ['3_plus', 'Three or more times a year'],
    ['daily', 'Daily, with 3 or more hospital stays a year'],
  ],
  includes('gi.which', 'pancreas'),
  { section: 'gi' },
);
single(
  'pancreas.removed',
  'How much was removed?',
  [
    ['part', 'Part'],
    ['all', 'All'],
  ],
  includes('pancreas.which', 'removed'),
  { section: 'gi' },
);
yesNo(
  'pancreas.hospital',
  'Were you hospitalized for this, other than the surgery itself?',
  includes('gi.which', 'pancreas'),
  { section: 'gi' },
);
multi(
  'adhesion.cause',
  'What do you think caused the scar tissue?',
  [
    ['surgery', 'Surgery'],
    ['injury', 'An injury'],
    ['inflammation', "Inflammation such as gallbladder disease or Crohn's"],
    ['not_sure', "I'm not sure"],
  ],
  includes('gi.which', 'adhesion'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'adhesion.organ',
  'Which organ is involved?',
  [
    ['stomach', 'Stomach'],
    ['gallbladder', 'Gallbladder'],
    ['liver', 'Liver'],
    ['small', 'Small intestine'],
    ['large', 'Large intestine'],
    ['pancreas', 'Pancreas'],
    ['other', 'Other'],
  ],
  includes('gi.which', 'adhesion'),
  { section: 'gi', createsEachOption: false },
);
multi(
  'adhesion.symptoms',
  'What does it do?',
  [
    ['none', 'No symptoms'],
    ['diarrhea', 'Diarrhea'],
    ['constipation', 'Constipation'],
    ['cramp', 'Cramping'],
    ['vomit', 'Vomiting'],
    ['nausea', 'Nausea'],
    ['pain', 'Belly pain'],
    ['diet', 'A special diet'],
    ['block', 'A blockage that keeps coming back'],
  ],
  includes('gi.which', 'adhesion'),
  { section: 'gi', createsEachOption: false },
);
single(
  'adhesion.block',
  'Has a doctor said it cannot be operated on, or that treatment is not working?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_sure', "I'm not sure"],
  ],
  includes('adhesion.symptoms', 'block'),
  { section: 'gi' },
);
yesNo(
  'adhesion.hospital',
  'Were you hospitalized for a blockage in the past 2 years?',
  includes('adhesion.symptoms', 'block'),
  { section: 'gi' },
);
tail('gi', giGate);

const guGate = yes('genitourinary');
multi(
  'gu.which',
  'Which of these fit?',
  [
    ['void', 'Leaking or frequency'],
    ['stream', 'A slow or weak stream'],
    ['stone', 'Bladder or kidney stones'],
    ['infection', 'Repeated bladder or kidney infections'],
    ['function', 'A doctor told you your kidneys are not working well'],
    ['dialysis', 'Dialysis'],
    ['removed', 'A kidney removed'],
    ['transplant', 'A kidney transplant'],
    ['blood', 'Blood in the urine'],
    ['growth', 'A growth in the kidney or bladder'],
    ['none', 'None of these'],
  ],
  guGate,
  { section: 'gu' },
);
voiding('gu', includes('gu.which', 'void'));
multi(
  'stone.where',
  'Where were the stones?',
  [
    ['kidney', 'Kidney'],
    ['ureter', 'Ureter'],
    ['bladder', 'Bladder'],
    ['urethra', 'Urethra'],
  ],
  includes('gu.which', 'stone'),
  { section: 'gu', createsEachOption: false },
);
multi(
  'stone.treatment',
  'What treatment have you had?',
  [
    ['diet', 'Diet'],
    ['medicine', 'Medicine'],
    ['once', 'A procedure once a year or less'],
    ['twice', 'A procedure twice a year'],
    ['more', 'A procedure more than twice a year'],
    ['none', 'None of these'],
  ],
  includes('gu.which', 'stone'),
  { section: 'gu', createsEachOption: false },
);
single(
  'stone.colic',
  'Do you get attacks of kidney-stone pain?',
  [
    ['occasional', 'Occasional'],
    ['frequent', 'Frequent'],
    ['no', 'No'],
  ],
  includes('gu.which', 'stone'),
  { section: 'gu' },
);
multi(
  'infection.treatment',
  'How are the repeated infections treated?',
  [
    ['none', 'No treatment'],
    ['under_6', 'Suppressive medicine for less than 6 months'],
    ['6_plus', 'Suppressive medicine for 6 months or longer'],
    ['hospital_1_2', 'Hospitalized once or twice in the past year'],
    ['hospital_more', 'Hospitalized more than twice'],
    ['stent', 'A stent or drain'],
  ],
  includes('gu.which', 'infection'),
  { section: 'gu', createsEachOption: false },
);
yesNo('kidney.dialysis', 'Do you need regular dialysis?', includes('gu.which', 'dialysis'), { section: 'gu' });
single(
  'kidney.removed',
  'Why was the kidney removed?',
  [
    ['donated', 'Donated'],
    ['disease', 'Removed because of disease'],
    ['injury', 'Removed because of injury'],
  ],
  includes('gu.which', 'removed'),
  { section: 'gu' },
);
yesNo('kidney.remaining', 'Is the remaining kidney also sick?', includes('gu.which', 'removed'), {
  section: 'gu',
});
yearMonth('kidney.transplant', 'About when was the transplant?', includes('gu.which', 'transplant'));
yesNo('kidney.transplantSick', 'Is the transplanted kidney sick?', includes('gu.which', 'transplant'), {
  section: 'gu',
});
tail('gu', guGate);

const endoGate = yes('endocrine');
multi(
  'endocrine.which',
  'Which of these fit?',
  [
    ['thyroid', 'Thyroid trouble'],
    ['parathyroid', 'Parathyroid trouble'],
    ['diabetes', 'Diabetes'],
    ['sugar', 'High or low blood sugar'],
    ['cushing', "Cushing's"],
    ['acromegaly', 'Acromegaly'],
    ['insipidus', 'Diabetes insipidus'],
    ['addison', "Addison's disease"],
    ['pituitary', 'A pituitary problem'],
    ['other', 'Another hormone problem'],
    ['none', 'None of these'],
  ],
  endoGate,
  { section: 'endocrine' },
);
multi(
  'diabetes.medicine',
  'How is the diabetes treated?',
  [
    ['diet', 'Restricted diet'],
    ['pills', 'Pills'],
    ['insulin_once', 'Insulin once a day'],
    ['insulin_more', 'Insulin more than once a day'],
    ['none', 'None of these'],
  ],
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine', createsEachOption: false },
);
yesNo(
  'diabetes.limitActivity',
  'Has a doctor told you to avoid hard work or exercise so your blood sugar does not crash?',
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine' },
);
yesNo(
  'diabetes.lowHigh',
  'In the past year, have you gone to a doctor for very low or very high blood sugar?',
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine' },
);
single(
  'diabetes.lowHighOften',
  'How often?',
  [
    ['under_2', 'Less than twice a month'],
    ['twice', 'Twice a month'],
    ['weekly', 'Weekly'],
  ],
  yes('diabetes.lowHigh'),
  { section: 'endocrine' },
);
yesNo(
  'diabetes.hospital',
  'In the past year, were you hospitalized for very low or very high blood sugar?',
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine' },
);
single(
  'diabetes.hospitalCount',
  'How many times?',
  [
    ['none', 'None'],
    ['1', 'Once'],
    ['2', 'Twice'],
    ['3_plus', '3 or more'],
  ],
  yes('diabetes.hospital'),
  { section: 'endocrine' },
);
yesNo(
  'diabetes.weight',
  'Have you been losing weight and strength without trying, and were you told it is from diabetes?',
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine' },
);
multi(
  'diabetes.complications',
  'Has a doctor tied any of these to diabetes?',
  [
    ['nerves', 'Nerve symptoms in the feet or hands', { opensGate: 'nerves' }],
    ['kidney', 'Kidney trouble from diabetes', { opensGate: 'genitourinary' }],
    ['eyes', 'Eye trouble from diabetes', { opensGate: 'eyes' }],
    ['erection', 'Trouble getting or keeping an erection', { opensGate: 'reproductive' }],
    ['heart', 'Heart trouble', { opensGate: 'cardiovascular' }],
    ['bp', 'High blood pressure', { opensGate: 'cardiovascular' }],
    ['circulation', 'Poor circulation in the legs', { opensGate: 'cardiovascular' }],
    ['stroke', 'A stroke', { opensGate: 'head' }],
    ['skin', 'A skin condition', { opensGate: 'skin' }],
    ['none', 'None of these'],
  ],
  includes('endocrine.which', 'diabetes'),
  { section: 'endocrine' },
);
multi(
  'thyroid.which',
  'Which thyroid or parathyroid problem was named?',
  [
    ['hyper', "Overactive thyroid, including Graves'"],
    ['hypo', 'Underactive thyroid'],
    ['large', 'A large thyroid'],
    ['inflammation', 'Thyroid inflammation'],
    ['cancer', 'Thyroid cancer or a growth'],
    ['para_hyper', 'Overactive parathyroid'],
    ['para_hypo', 'Underactive parathyroid'],
    ['para_growth', 'A parathyroid growth'],
    ['none', 'None of these'],
  ],
  endoGate,
  { section: 'endocrine' },
);
multi(
  'thyroid.treatment',
  'What treatment have you had?',
  [
    ['iodine', 'Radioactive iodine'],
    ['surgery', 'Surgery'],
    ['medicine', 'Medicine'],
    ['none', 'None of these'],
  ],
  endoGate,
  { section: 'endocrine', createsEachOption: false },
);
yesNo(
  'thyroid.myxedema',
  'Have you been hospitalized for a myxedema crisis, a severe low-thyroid emergency?',
  includes('thyroid.which', 'hypo'),
  { section: 'endocrine' },
);
multi(
  'parathyroid.symptoms',
  'What does the overactive parathyroid do?',
  [
    ['fatigue', 'Fatigue'],
    ['appetite', 'Poor appetite'],
    ['nausea', 'Nausea'],
    ['constipation', 'Constipation'],
    ['none', 'None of these'],
  ],
  includes('thyroid.which', 'para_hyper'),
  { section: 'endocrine', createsEachOption: false },
);
multi(
  'cushing.symptoms',
  "What does Cushing's do?",
  [
    ['worse', 'Getting worse'],
    ['bp', 'High blood pressure'],
    ['bones', 'Bones that break easily'],
    ['arms', 'Arms too weak to lift'],
    ['legs', 'Legs too weak to climb stairs or stand from a chair'],
    ['none', 'None of these'],
  ],
  includes('endocrine.which', 'cushing'),
  { section: 'endocrine', createsEachOption: false },
);
multi(
  'acromegaly.symptoms',
  'What does acromegaly do?',
  [
    ['larger', 'Hands, feet, or jaw getting larger'],
    ['joint', 'Joint trouble'],
    ['bp', 'High blood pressure'],
    ['sugar', 'High blood sugar'],
    ['pressure', 'Headache or vision change from pressure'],
    ['none', 'None of these'],
  ],
  includes('endocrine.which', 'acromegaly'),
  { section: 'endocrine', createsEachOption: false },
);
multi(
  'insipidus.symptoms',
  'What does diabetes insipidus do?',
  [
    ['urine', 'Urinating all the time'],
    ['medicine', 'Hormone medicine all the time'],
    ['none', 'None of these'],
  ],
  includes('endocrine.which', 'insipidus'),
  { section: 'endocrine', createsEachOption: false },
);
single(
  'addison.crisis',
  'In the past year, how many adrenal crises put you into shock or the emergency room?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4', '4'],
    ['5', '5'],
    ['6', '6'],
  ],
  includes('endocrine.which', 'addison'),
  { section: 'endocrine' },
);
single(
  'addison.episode',
  'How many milder episodes, with nausea, vomiting, or profound weakness?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4', '4'],
    ['5', '5'],
    ['more', 'More than 5'],
  ],
  includes('endocrine.which', 'addison'),
  { section: 'endocrine' },
);
yesNo('addison.medicine', 'Do you need steroid medicine to control this?', includes('endocrine.which', 'addison'), {
  section: 'endocrine',
});
tail('endocrine', endoGate);

const skinGate = yes('skin');
multi(
  'skin.which',
  'Which of these fit?',
  [
    ['rash', 'A rash or other skin disease'],
    ['skin_cancer', 'Skin cancer'],
    ['other_cancer', 'Another cancer'],
    ['scars', 'Scars from a condition or from treatment'],
    ['none', 'None of these'],
  ],
  skinGate,
  { section: 'skin' },
);
multi(
  'skin.treatment',
  'What treatment have you used in the past year?',
  [
    ['cream', 'Cream or ointment'],
    ['pills', 'Pills'],
    ['shots', 'Shots'],
    ['light', 'Light therapy'],
    ['none', 'None in the past year'],
  ],
  skinGate,
  { section: 'skin', createsEachOption: false },
);
single(
  'skin.treatmentDuration',
  'How much of the past year?',
  [
    ['under_6', 'Less than 6 weeks in the past year'],
    ['6_not_constant', '6 weeks or more but not constant'],
    ['constant', 'Constant or near-constant'],
  ],
  skinGate,
  { section: 'skin' },
);
scar(skinGate);
tail('skin', skinGate);

spine('back', 'back', 'leg', 'Does the pain travel down either leg?');
spine('neck', 'neck', 'arm', 'Does the pain travel into either arm?');

const jointGate = yes('joints');
const JOINTS = [
  ['shoulder', 'Shoulder'],
  ['arm', 'Arm'],
  ['elbow', 'Elbow'],
  ['forearm', 'Forearm'],
  ['wrist', 'Wrist'],
  ['hand', 'Hand or fingers'],
  ['hip', 'Hip'],
  ['thigh', 'Thigh'],
  ['knee', 'Knee'],
  ['lower_leg', 'Lower leg'],
  ['ankle', 'Ankle'],
  ['foot', 'Foot or toes'],
];
multi('joint.where', 'Which parts?', JOINTS, jointGate, { section: 'joints' });
for (const [value, label] of JOINTS) {
  const shown = includes('joint.where', value);
  yesNo(`joint.${value}.flare`, `Does the ${label.toLowerCase()} flare up?`, shown, { section: 'joints' });
  single(
    `joint.${value}.flareFrequency`,
    'How often?',
    [
      ['few', 'A few times a year'],
      ['monthly', 'Monthly'],
      ['weekly', 'Weekly'],
      ['more', 'More often than weekly'],
    ],
    yes(`joint.${value}.flare`),
    { section: 'joints' },
  );
  yesNo(
    `joint.${value}.device`,
    `Do you use a cane, walker, brace, crutches, or a wheelchair because of the ${label.toLowerCase()}?`,
    shown,
    { section: 'joints' },
  );
}
yesNo('knee.giveWay', 'Does the knee give way or feel unstable?', includes('joint.where', 'knee'), {
  section: 'joints',
});
yesNo('knee.swelling', 'Does the knee swell often?', includes('joint.where', 'knee'), { section: 'joints' });
yesNo('knee.lock', 'Does the knee lock?', includes('joint.where', 'knee'), { section: 'joints' });
yesNo('knee.tear', 'Have you been told you have a ligament or meniscus tear?', includes('joint.where', 'knee'), {
  section: 'joints',
});
yesNo('knee.repair', 'Has that tear been repaired?', yes('knee.tear'), { section: 'joints' });
yesNo('knee.shin', 'Have you had shin splints?', includes('joint.where', 'knee'), { section: 'joints' });
multi(
  'ankle.which',
  'Which ankle problem was named?',
  [
    ['sprain', 'A ligament sprain that keeps coming back'],
    ['tendon', 'A tendon problem, including Achilles'],
    ['achilles_torn', 'Achilles tendon torn'],
    ['stress', 'A stress fracture'],
    ['shin', 'Shin splints'],
    ['replaced', 'The joint was replaced'],
    ['stuck', 'The joint is stuck'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'ankle'),
  { section: 'joints' },
);
yesNo('ankle.giveWay', 'Does the ankle give way?', includes('joint.where', 'ankle'), { section: 'joints' });
single(
  'ankle.shinCare',
  'How long were shin splints treated?',
  [
    ['none', 'No treatment'],
    ['under_12', 'Treatment for less than 12 months'],
    ['12_plus', 'Treatment for 12 months or more'],
  ],
  includes('ankle.which', 'shin'),
  { section: 'joints' },
);
yesNo('ankle.stuck', 'Is the ankle stuck?', includes('joint.where', 'ankle'), { section: 'joints' });
single(
  'ankle.stuckWeight',
  'How does it bear weight?',
  [
    ['well', 'It still bears weight well'],
    ['poor', 'It bears weight poorly'],
  ],
  yes('ankle.stuck'),
  { section: 'joints' },
);
multi(
  'elbow.which',
  'Which elbow or forearm problem was named?',
  [
    ['epicondyle', "Tennis or golfer's elbow"],
    ['tendinitis', 'Tendinitis'],
    ['dislocated', 'It dislocated'],
    ['replaced', 'It was replaced'],
    ['stuck', 'It is stuck'],
    ['fracture', 'A fracture that healed crooked or did not heal'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'elbow'),
  { section: 'joints' },
);
multi(
  'elbow.painMove',
  'Which movements hurt?',
  [
    ['bend', 'Bending'],
    ['straight', 'Straightening'],
    ['up', 'Turning the palm up'],
    ['down', 'Turning the palm down'],
  ],
  includes('joint.where', 'elbow'),
  { section: 'joints', createsEachOption: false },
);
yesNo('elbow.stuck', 'Is it stuck?', includes('joint.where', 'elbow'), { section: 'joints' });
multi(
  'elbow.stuckHow',
  'What cannot you do?',
  [
    ['up', 'I cannot turn the palm up'],
    ['down', 'I cannot turn the palm down'],
    ['neither', 'Neither'],
  ],
  yes('elbow.stuck'),
  { section: 'joints', createsEachOption: false },
);
multi(
  'wrist.which',
  'Which wrist problem was named?',
  [
    ['sprain', 'A sprain that stayed'],
    ['ganglion', 'A ganglion cyst'],
    ['thumb', 'Arthritis at the base of the thumb'],
    ['dequervain', "DeQuervain's"],
    ['replaced', 'The wrist was replaced'],
    ['stuck', 'The wrist is stuck'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'wrist'),
  { section: 'joints' },
);
yesNo('wrist.stuck', 'Is the wrist stuck in a bent or unusable position?', includes('joint.where', 'wrist'), {
  section: 'joints',
});
multi(
  'hip.which',
  'Which hip or thigh problem was named?',
  [
    ['arthritis', 'Arthritis'],
    ['bursitis', 'Bursitis at the outside of the hip'],
    ['labrum', 'A labral tear or pinching'],
    ['tendon', 'A tendon problem'],
    ['stress', 'A stress fracture of the hip'],
    ['avn', 'The bone died (avascular necrosis)'],
    ['replaced', 'The joint was replaced or resurfaced'],
    ['stuck', 'The joint is stuck'],
    ...RARE_JOINT.filter(([value]) => value !== 'bursitis'),
  ],
  includes('joint.where', 'hip'),
  { section: 'joints' },
);
yesNo('hip.giveWay', 'Does the hip give way or feel unstable?', includes('joint.where', 'hip'), {
  section: 'joints',
});
multi(
  'shoulder.which',
  'Which shoulder or arm problem was named?',
  [
    ['strain', 'Strain'],
    ['impingement', 'Impingement'],
    ['biceps', 'Biceps tendon trouble'],
    ['cuff_tendon', 'Rotator cuff tendonitis'],
    ['cuff_tear', 'Rotator cuff tear'],
    ['labrum', 'Labral tear'],
    ['slip', 'The shoulder slips out'],
    ['clavicle', 'Collarbone fracture or a collarbone that healed crooked'],
    ['ac', 'AC joint trouble'],
    ['humerus', 'Upper arm bone that healed crooked'],
    ['replaced', 'The joint was replaced'],
    ['stuck', 'The joint is stuck'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'shoulder'),
  { section: 'joints' },
);
yesNo('shoulder.slip', 'Does the shoulder slip out of place?', includes('shoulder.which', 'slip'), {
  section: 'joints',
});
single(
  'shoulder.slipOften',
  'How often does it slip?',
  [
    ['once', 'It happened once'],
    ['keeps', 'It keeps happening'],
  ],
  yes('shoulder.slip'),
  { section: 'joints' },
);
yesNo('shoulder.slipUse', 'Can you still use the arm after it happens?', yes('shoulder.slip'), {
  section: 'joints',
});
multi(
  'hand.which',
  'Which hand or finger problem was named?',
  [
    ['trigger', 'Trigger finger'],
    ['dupuytren', "Dupuytren's contracture"],
    ['stuck_shape', 'A finger stuck in a bent or swan-neck shape'],
    ['mallet', 'Mallet finger'],
    ['gamekeeper', "Gamekeeper's thumb"],
    ['sprain', 'A ligament sprain that stayed'],
    ['replaced', 'A joint was replaced'],
    ['stuck', 'A finger joint is stuck'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'hand'),
  { section: 'joints' },
);
multi(
  'hand.whichFingers',
  'Which fingers?',
  [
    ['thumb', 'Thumb'],
    ['index', 'Index'],
    ['middle', 'Middle'],
    ['ring', 'Ring'],
    ['little', 'Little'],
  ],
  includes('joint.where', 'hand'),
  { section: 'joints', createsEachOption: false },
);
single('hand.side', 'Which hand?', SIDE, includes('joint.where', 'hand'), { section: 'joints' });
multi(
  'foot.which',
  'Which foot problem was named?',
  [
    ['flat', 'Flat feet'],
    ['fascia', 'Plantar fasciitis'],
    ['morton', "Morton's neuroma"],
    ['ball', 'Pain in the ball of the foot'],
    ['hammer', 'Hammer toes'],
    ['bunion', 'Bunion'],
    ['hallux', 'Hallux rigidus, a stiff big toe'],
    ['claw', 'Claw foot'],
    ['malunion', 'A foot bone that healed crooked or did not heal'],
    ['other_injury', 'Another foot injury'],
    ...RARE_JOINT,
  ],
  includes('joint.where', 'foot'),
  { section: 'joints' },
);
single('foot.side', 'Which foot?', SIDE, includes('joint.where', 'foot'), { section: 'joints' });
single(
  'hallux.level',
  'How stiff is the big toe?',
  MILD,
  includes('foot.which', 'hallux'),
  { section: 'joints' },
);
multi(
  'flatfoot.symptoms',
  'What do the flat feet do?',
  [
    ['pain', 'Pain when I use them'],
    ['worse', 'Worse with use'],
    ['swell', 'Swelling with use'],
    ['callus', 'Calluses'],
    ['tender', 'Very tender soles'],
    ['none', 'None of these'],
  ],
  includes('foot.which', 'flat'),
  { section: 'joints', createsEachOption: false },
);
yesNo('flatfoot.supports', 'Have you tried arch supports or built-up shoes?', includes('foot.which', 'flat'), {
  section: 'joints',
});
single(
  'flatfoot.supportsHelp',
  'Did they help?',
  [
    ['yes', 'They relieve it'],
    ['no', 'They do not'],
  ],
  yes('flatfoot.supports'),
  { section: 'joints' },
);
single(
  'fascia.care',
  'Did non-surgical treatment help the plantar fasciitis?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_tried', 'I have not tried it'],
  ],
  includes('foot.which', 'fascia'),
  { section: 'joints' },
);
single(
  'fascia.surgery',
  'Did surgery help?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_had', 'I have not had it'],
  ],
  includes('foot.which', 'fascia'),
  { section: 'joints' },
);
yesNo(
  'fascia.cannot',
  'Did a doctor say you need surgery but you cannot have it?',
  includes('foot.which', 'fascia'),
  { section: 'joints' },
);
multi(
  'hammer.toes',
  'Which toes are hammer toes?',
  [
    ['great', 'Great'],
    ['second', 'Second'],
    ['third', 'Third'],
    ['fourth', 'Fourth'],
    ['little', 'Little'],
  ],
  includes('foot.which', 'hammer'),
  { section: 'joints', createsEachOption: false },
);
single(
  'bunion.level',
  'How bad is the bunion?',
  [
    ['mild', 'Mild or moderate'],
    ['severe', 'Severe enough that the big toe might as well be gone'],
  ],
  includes('foot.which', 'bunion'),
  { section: 'joints' },
);
single(
  'bunion.surgery',
  'What surgery?',
  [
    ['none', 'None'],
    ['head', 'The metatarsal head was removed'],
    ['osteotomy', 'An osteotomy'],
    ['other', 'Another surgery'],
  ],
  includes('foot.which', 'bunion'),
  { section: 'joints' },
);
yesNo('muscle.ask', 'Was a muscle injured, separate from the joint itself?', jointGate, {
  section: 'joints',
});
const muscleGate = yes('muscle.ask');
multi(
  'muscle.which',
  'Which muscle groups were injured?',
  MUSCLE_GROUPS,
  muscleGate,
  { section: 'joints' },
);
perChecked('muscle.which', MUSCLE_GROUPS, (value, label, shown) => {
  single(`muscle.${value}.side`, `Which side is the ${label.toLowerCase()} injury?`, SIDE, shown, {
    section: 'joints',
  });
  single(
    `muscle.${value}.severity`,
    `How limiting is the ${label.toLowerCase()} injury?`,
    [
      ['slight', 'Slight'],
      ['moderate', 'Moderate'],
      ['moderately_severe', 'Moderately severe'],
      ['severe', 'Severe'],
    ],
    shown,
    { section: 'joints' },
  );
});
multi(
  'muscle.how',
  'How did the muscle injury happen, and what is left?',
  [
    ['through', 'A through-and-through wound'],
    ['surgery', 'Surgery'],
    ['hurts', 'It still hurts'],
    ['weak', 'It is weak'],
    ['scar', 'A scar'],
    ['none', 'None of these'],
  ],
  muscleGate,
  { section: 'joints', createsEachOption: false },
);
yesNo('bone.infection', 'Have you had a bone infection?', jointGate, {
  section: 'joints',
  createsCondition: 'Bone infection',
});
multi(
  'bone.infectionWhere',
  'Where?',
  [
    ['pelvis', 'Pelvis'],
    ['neck', 'Neck bones'],
    ['back', 'Back bones'],
    ['arm', 'Arm'],
    ['leg', 'Leg'],
    ['finger', 'Finger'],
    ['toe', 'Toe'],
  ],
  yes('bone.infection'),
  { section: 'joints', createsEachOption: false },
);
single('bone.infectionSide', 'Which side?', SIDE, yes('bone.infection'), { section: 'joints' });
single(
  'bone.infectionNow',
  'Is it active?',
  [
    ['active', 'Active'],
    ['inactive', 'Inactive'],
    ['resolved', 'Resolved'],
  ],
  yes('bone.infection'),
  { section: 'joints' },
);
single(
  'bone.infectionAgain',
  'How many times did it come back?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4', '4'],
    ['5_plus', '5 or more'],
  ],
  yes('bone.infection'),
  { section: 'joints' },
);
multi(
  'bone.infectionFeel',
  'What does it do?',
  [
    ['pain', 'Pain'],
    ['swelling', 'Swelling'],
    ['drain', 'A draining sore'],
    ['fever', 'Fever or feeling ill'],
    ['joint', 'A joint that no longer moves well'],
    ['none', 'None of these'],
  ],
  yes('bone.infection'),
  { section: 'joints', createsEachOption: false },
);
const NAMED_BONES = [
  ['skull_fracture', 'Skull fracture'],
  ['skull_loss', 'Loss of part of the skull'],
  ['rib_fracture', 'Rib fracture'],
  ['rib_removal', 'Rib removal'],
  ['costochondritis', 'Costochondritis'],
  ['coccyx', 'Coccyx removal'],
];
multi('bone.which', 'Has a doctor named any of these bone conditions?', NAMED_BONES.concat([['none', 'None of these']]), jointGate, {
  section: 'joints',
});
perChecked(
  'bone.which',
  NAMED_BONES.filter(([value]) => value !== 'coccyx'),
  (value, label, shown) => {
    single(`bone.${value}.side`, `Which side is the ${label.toLowerCase()}?`, SIDE, shown, {
      section: 'joints',
    });
  },
);
yesNo('amp.ask', 'Is an arm, hand, leg, foot, or finger missing?', jointGate, {
  section: 'joints',
});
const ampGate = yes('amp.ask');
multi(
  'amp.site',
  'Where was a limb or digit removed?',
  [
    ['arm', 'Arm'],
    ['forearm', 'Forearm'],
    ['hand', 'Hand or fingers'],
    ['thigh', 'Thigh'],
    ['lower_leg', 'Lower leg'],
    ['foot', 'Foot or toes'],
    ['none', 'None of these'],
  ],
  ampGate,
  { section: 'joints' },
);
single(
  'amp.armLevel',
  'How much of the arm?',
  [
    ['below', 'Below the shoulder muscle'],
    ['above', 'Above the shoulder muscle'],
    ['whole', 'The whole shoulder, including the shoulder blade or collarbone'],
    ['joint', 'At the shoulder joint only'],
  ],
  includes('amp.site', 'arm'),
  { section: 'joints' },
);
single(
  'amp.forearmLevel',
  'How much of the forearm?',
  [
    ['below', 'Below the middle of the forearm'],
    ['above', 'Above the middle'],
    ['hand', 'The hand cannot be used'],
  ],
  includes('amp.site', 'forearm'),
  { section: 'joints' },
);
multi(
  'amp.finger',
  'Which fingers?',
  [
    ['thumb', 'Thumb'],
    ['index', 'Index'],
    ['middle', 'Middle'],
    ['ring', 'Ring'],
    ['little', 'Little'],
  ],
  includes('amp.site', 'hand'),
  { section: 'joints', createsEachOption: false },
);
single('amp.fingerSide', 'Which hand?', SIDE, includes('amp.site', 'hand'), { section: 'joints' });
single(
  'amp.fingerLevel',
  'How much of the finger?',
  [
    ['tip', 'Tip'],
    ['near', 'Through the near joint'],
    ['bone', 'Including the hand bone'],
  ],
  includes('amp.site', 'hand'),
  { section: 'joints' },
);
single(
  'amp.thighLevel',
  'How much of the thigh?',
  [
    ['lower', 'Lower or middle thigh'],
    ['upper', 'Upper thigh'],
    ['hip', 'At the hip joint'],
    ['pelvis', 'Through the pelvis'],
  ],
  includes('amp.site', 'thigh'),
  { section: 'joints' },
);
single(
  'amp.legLevel',
  'How much of the lower leg or foot?',
  [
    ['forefoot', 'Forefoot'],
    ['ankle', 'Through the ankle'],
    ['below', 'Below the knee'],
    ['knee', 'Through the knee'],
  ],
  includes('amp.site', 'lower_leg'),
  { section: 'joints' },
);
single(
  'amp.footLevel',
  'How much of the foot?',
  [
    ['toes', 'Toes'],
    ['forefoot', 'Forefoot'],
    ['ankle', 'Through the ankle'],
  ],
  includes('amp.site', 'foot'),
  { section: 'joints' },
);
single(
  'amp.prosthetic',
  'Can you use a prosthesis on that side?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_applicable', 'Not applicable'],
  ],
  ampGate,
  { section: 'joints' },
);
single(
  'amp.cause',
  'Why was it removed?',
  [
    ['injury', 'Injury in service'],
    ['surgery', 'Surgery'],
    ['other', 'Something else'],
  ],
  ampGate,
  { section: 'joints' },
);
tail('joints', jointGate);

const nerveGate = yes('nerves');
multi(
  'nerve.where',
  'Where is the numbness, tingling, or weakness?',
  [
    ['right_arm', 'Right arm'],
    ['left_arm', 'Left arm'],
    ['right_leg', 'Right leg'],
    ['left_leg', 'Left leg'],
  ],
  nerveGate,
  { section: 'nerves', createsEachOption: true },
);
multi(
  'nerve.feel',
  'How does it feel?',
  [
    ['constant', 'Constant pain'],
    ['intermittent', 'Pain that comes and goes'],
    ['numb', 'Numbness'],
    ['tingle', 'Tingling'],
  ],
  nerveGate,
  { section: 'nerves', createsEachOption: false },
);
single('nerve.severity', 'How bad is it?', MILD, nerveGate, { section: 'nerves' });
yesNo('nerve.device', 'Do you use a cane, walker, brace, crutches, or a wheelchair because of this?', nerveGate, {
  section: 'nerves',
});
multi('nerve.deviceWhich', 'Which ones?', DEVICES, yes('nerve.device'), {
  section: 'nerves',
  createsEachOption: false,
});
tail('nerves', nerveGate);

const mentalGate = yes('mental');
multi(
  'mental.which',
  'Which of these do you want to include?',
  [
    ['depression', 'Depression'],
    ['anxiety', 'Anxiety'],
    ['panic', 'Panic'],
    ['ptsd', 'PTSD or a reaction to a traumatic event'],
    ['eating', 'An eating disorder'],
    ['substance', 'Alcohol or drug use that concerns you'],
    ['none', 'None of these'],
  ],
  mentalGate,
  { section: 'mental' },
);
single(
  'mental.twoWeeks',
  'Over the last 2 weeks, how often have you had little interest in doing things, or felt down or hopeless?',
  [
    ['none', 'Not at all'],
    ['several', 'Several days'],
    ['half', 'More than half the days'],
    ['daily', 'Nearly every day'],
  ],
  mentalGate,
  { section: 'mental' },
);
yesNo(
  'mental.trauma',
  'Have you lived through something unusually frightening or horrible, such as combat, assault, or a serious accident?',
  mentalGate,
  { section: 'mental' },
);
multi(
  'ptsd.symptoms',
  'Since then, which of these have stayed with you? You do not need to describe the event.',
  [
    ['memories', 'Unwanted memories'],
    ['nightmares', 'Nightmares'],
    ['flashbacks', 'Flashbacks'],
    ['distress', 'Strong distress at reminders'],
    ['physical', 'A physical reaction at reminders'],
    ['avoid_feelings', 'Avoiding memories or feelings'],
    ['avoid_people', 'Avoiding people, places, or conversations'],
    ['memory_gap', 'Unable to remember an important part of it'],
    ['beliefs', 'Strong negative beliefs about yourself or the world'],
    ['blame', 'Blaming yourself or someone else'],
    ['emotion', 'Fear, horror, anger, guilt, or shame that stays'],
    ['interest', 'Much less interest in things you used to do'],
    ['detached', 'Feeling detached from other people'],
    ['numb', 'Unable to feel happiness or love'],
    ['anger', 'Irritable or angry outbursts'],
    ['reckless', 'Reckless behavior'],
    ['guard', 'Being on guard'],
    ['startle', 'Easily startled'],
    ['focus', 'Trouble concentrating'],
    ['sleep', 'Poor sleep'],
  ],
  yes('mental.trauma'),
  { section: 'mental', createsEachOption: false },
);
multi(
  'mental.symptoms',
  'Which of these have been part of your days?',
  [
    ['depressed', 'Depressed mood'],
    ['anxiety', 'Anxiety'],
    ['suspicion', 'Suspicion'],
    ['panic_less', 'Panic weekly or less'],
    ['panic_more', 'Panic more than once a week'],
    ['hard_function', 'Panic or depression that makes it hard to function'],
    ['sleep', 'Poor sleep'],
    ['forget', 'Forgetting names, directions, or recent events'],
    ['tasks', 'Trouble keeping up with tasks'],
    ['identity', 'Trouble knowing close family, your job, or your own name'],
    ['relationships', 'Hard to start or stay in relationships'],
    ['stress', 'Hard time with stress'],
    ['suicide', 'Thoughts of suicide', { crisisNotice: '988' }],
    ['rituals', 'Rituals that interfere with your day'],
    ['anger', 'Anger or violence you did not mean to start'],
    ['perception', 'Seeing or hearing things others do not'],
    ['hygiene', 'Neglecting hygiene'],
    ['none', 'None of these'],
  ],
  mentalGate,
  { section: 'mental', createsEachOption: false },
);
single(
  'mental.substances',
  'In the past year, how often did you have a drink, or use a drug, enough that it concerned you?',
  [
    ['never', 'Never'],
    ['monthly', 'Monthly or less'],
    ['weekly', 'Weekly'],
    ['most_days', 'Most days'],
  ],
  mentalGate,
  { section: 'mental' },
);
multi(
  'eating.which',
  'Which eating pattern fits?',
  [
    ['restrict', 'Bingeing and then trying not to gain'],
    ['purge', 'Bingeing and then vomiting'],
    ['low', 'Weight kept off even when it is already low'],
    ['none', 'None of these'],
  ],
  includes('mental.which', 'eating'),
  { section: 'mental' },
);
single(
  'eating.bed',
  'In the past year, how long were you in bed because a doctor was treating this?',
  [
    ['none', 'None'],
    ['2_weeks', 'Up to 2 weeks'],
    ['under_6', 'More than 2 weeks but less than 6'],
    ['6_plus', '6 weeks or more'],
  ],
  includes('mental.which', 'eating'),
  { section: 'mental' },
);
yesNo(
  'eating.hospital',
  'Were you hospitalized more than twice in the past year for tube feeding or IV nutrition?',
  includes('mental.which', 'eating'),
  { section: 'mental' },
);
tail('mental', mentalGate);

const dentalGate = yes('dental');
multi(
  'dental.which',
  'Which of these came from service, an injury, or a disease other than cavities or gum disease?',
  [
    ['tmj', 'Jaw pain or a jaw that locks or pops'],
    ['lower_loss', 'Loss of part of the lower jaw from injury or disease, not from gum disease'],
    ['upper_loss', 'Loss of part of the upper jaw from injury or disease'],
    ['union', 'A broken jaw that healed crooked or did not heal'],
    ['teeth', 'Teeth lost because of an injury or bone infection, not from cavities or gum disease'],
    ['mouth', 'An injury to the mouth, lips, or tongue'],
    ['infection', 'Bone infection of the jaw'],
    ['cancer', 'Oral cancer'],
    ['none', 'None of these'],
  ],
  dentalGate,
  { section: 'dental' },
);
single(
  'jaw.loss',
  'How much of the lower jaw was lost?',
  [
    ['under_half_joint', 'Less than half, and the jaw joint is still there'],
    ['under_half_lost', 'Less than half, and the jaw joint was lost'],
    ['half', 'Half or more'],
    ['half_joint', 'Half or more including the jaw joint'],
    ['front', 'The whole front of the jaw between the angles'],
  ],
  includes('dental.which', 'lower_loss'),
  { section: 'dental' },
);
single(
  'jaw.prosthesis',
  'Can a prosthesis replace it?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_sure', "I'm not sure"],
  ],
  includes('dental.which', 'lower_loss'),
  { section: 'dental' },
);
single(
  'jaw.union',
  'How did the broken jaw heal?',
  [
    ['mild', 'Crooked, and my bite is only mildly off'],
    ['moderate', 'Crooked, and my bite is moderately off'],
    ['severe', 'Crooked, and my bite is severely off'],
    ['nonunion', 'It did not heal'],
    ['false', 'A doctor said it moves where it should not'],
  ],
  includes('dental.which', 'union'),
  { section: 'dental' },
);
single(
  'maxilla.loss',
  'How much of the upper jaw was lost?',
  [
    ['under_quarter', 'Less than a quarter'],
    ['quarter_half', 'A quarter to a half'],
    ['over_half', 'More than half'],
  ],
  includes('dental.which', 'upper_loss'),
  { section: 'dental' },
);
single(
  'maxilla.prosthesis',
  'Can a prosthesis replace the upper jaw?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_sure', "I'm not sure"],
  ],
  includes('dental.which', 'upper_loss'),
  { section: 'dental' },
);
yesNo('palate.loss', 'Was part of the hard palate lost?', dentalGate, {
  section: 'dental',
  createsCondition: 'Loss of part of the hard palate',
});
single(
  'palate.amount',
  'How much?',
  [
    ['under_half', 'Less than half'],
    ['half', 'Half or more'],
  ],
  yes('palate.loss'),
  { section: 'dental' },
);
yesNo(
  'teeth.cause',
  'Was that from the jaw bone being lost, or from an injury or bone infection, rather than cavities or gum disease?',
  includes('dental.which', 'teeth'),
  { section: 'dental' },
);
yesNo('teeth.replace', 'Can a dentist replace the chewing surface?', includes('dental.which', 'teeth'), {
  section: 'dental',
});
single(
  'tongue.loss',
  'What happened with the tongue?',
  [
    ['gone', 'Part or all of it is gone but swallowing is fine'],
    ['impaired', 'Swallowing is impaired'],
    ['diet', 'Swallowing needs a special diet'],
    ['none', 'I cannot take food by mouth'],
  ],
  includes('dental.which', 'mouth'),
  { section: 'dental' },
);
yesNo('tmj.lock', 'Does the jaw lock?', includes('dental.which', 'tmj'), { section: 'dental' });
yesNo('tmj.eat', 'Do you need a soft diet because of the jaw?', includes('dental.which', 'tmj'), {
  section: 'dental',
});
tail('dental', dentalGate);

const reproGate = yes('reproductive');
single(
  'repro.whichList',
  'Which list applies to you?',
  [
    ['male', 'Male reproductive'],
    ['female', 'Female reproductive'],
    ['neither', 'Neither'],
  ],
  reproGate,
  { section: 'reproductive' },
);
multi(
  'male.which',
  'Which of these fit?',
  [
    ['erection', 'Trouble getting or keeping an erection'],
    ['one', 'One testicle removed'],
    ['both', 'Both testicles removed'],
    ['shrunken', 'A shrunken testicle'],
    ['prostate', 'Prostate trouble or an enlarged prostate'],
    ['cancer', 'Prostate cancer'],
    ['prostatitis', 'Chronic prostatitis or a related infection'],
    ['retrograde', 'Retrograde ejaculation'],
    ['none', 'None of these'],
  ],
  [{ questionId: 'repro.whichList', equals: 'male' }],
  { section: 'reproductive' },
);
single('male.orchiectomy', 'Which testicle was removed?', SIDE, includes('male.which', 'one'), {
  section: 'reproductive',
});
single(
  'male.reason',
  'Why was it removed?',
  [
    ['undescended', 'Undescended'],
    ['underdeveloped', 'Underdeveloped'],
    ['disease', 'Disease or injury'],
    ['other', 'Another reason'],
  ],
  includes('male.which', 'one'),
  { section: 'reproductive' },
);
multi(
  'prostate.treatment',
  'What treatment did the prostate cancer have?',
  [
    ['removed', 'Prostate removed'],
    ['radical', 'Radical prostatectomy'],
    ['turp', 'TURP'],
    ['radiation', 'Radiation'],
    ['seeds', 'Seeds'],
    ['hormone', 'Hormone therapy'],
    ['none', 'None of these'],
  ],
  includes('male.which', 'cancer'),
  { section: 'reproductive', createsEachOption: false },
);
multi(
  'gyn.symptoms',
  'Which of these fit?',
  [
    ['mild_comes', 'Mild pain that comes and goes'],
    ['mild_constant', 'Mild pain that is constant'],
    ['mod_comes', 'Moderate pain that comes and goes'],
    ['mod_constant', 'Moderate pain that is constant'],
    ['severe_comes', 'Severe pain that comes and goes'],
    ['severe_constant', 'Severe pain that is constant'],
    ['pressure', 'Pelvic pressure'],
    ['irregular', 'Irregular periods'],
    ['painful', 'Painful periods'],
    ['stopped', 'Periods that stopped'],
    ['intercourse', 'Pain during intercourse'],
    ['arousal', 'Trouble with lubrication or arousal'],
    ['urine', 'Leaking urine'],
    ['stool', 'Leaking stool'],
    ['endo', 'Endometriosis'],
    ['endo_bleed', 'Heavy or irregular bleeding from endometriosis'],
    ['fibroid', 'Fibroids'],
    ['hysterectomy', 'A hysterectomy'],
    ['ovary', 'An ovary removed'],
    ['prolapse', 'Pelvic organ prolapse'],
    ['none', 'None of these'],
  ],
  [{ questionId: 'repro.whichList', equals: 'female' }],
  { section: 'reproductive' },
);
single(
  'gyn.treatment',
  'Do the symptoms need treatment all the time?',
  [
    ['no', 'No'],
    ['controls', 'Yes and treatment controls them'],
    ['not', 'Yes and treatment does not control them'],
  ],
  [{ questionId: 'repro.whichList', equals: 'female' }],
  { section: 'reproductive' },
);
yearMonth('gyn.hysterectomy', 'About when was the hysterectomy?', includes('gyn.symptoms', 'hysterectomy'));
single(
  'gyn.ovary',
  'How much of the ovary was removed?',
  [
    ['part', 'Part of one'],
    ['one', 'All of one'],
    ['both', 'Both'],
  ],
  includes('gyn.symptoms', 'ovary'),
  { section: 'reproductive' },
);
single('gyn.ovarySide', 'Which side?', SIDE, includes('gyn.symptoms', 'ovary'), {
  section: 'reproductive',
});
single(
  'gyn.endo',
  'Were you told endometriosis was confirmed by a scope?',
  [
    ['yes', 'Yes'],
    ['no', 'No'],
    ['not_sure', "I'm not sure"],
  ],
  includes('gyn.symptoms', 'endo'),
  { section: 'reproductive' },
);
yesNo('gyn.fistula', 'Do you leak stool through the vagina?', [{ questionId: 'repro.whichList', equals: 'female' }], {
  section: 'reproductive',
  createsCondition: 'Leak of stool through the vagina',
});
single(
  'gyn.fistulaOften',
  'How often?',
  [
    ['under_weekly', 'Less than weekly'],
    ['1_3', '1 to 3 times a week'],
    ['4_plus', '4 or more times a week'],
    ['daily', 'Daily'],
    ['pad', 'I wear a pad'],
  ],
  yes('gyn.fistula'),
  { section: 'reproductive' },
);
multi(
  'breast.which',
  'Which breast condition was named?',
  [
    ['benign', 'A growth that was benign'],
    ['cancer', 'Breast cancer'],
    ['surgery', 'Surgery'],
    ['none', 'None of these'],
  ],
  [{ questionId: 'repro.whichList', equals: 'female' }],
  { section: 'reproductive' },
);
single('breast.side', 'Which side?', SIDE, [{ questionId: 'repro.whichList', equals: 'female' }], {
  section: 'reproductive',
});
single(
  'breast.cancerStatus',
  'Where is treatment?',
  [
    ['treating', 'Still being treated'],
    ['finished', 'Treatment finished'],
    ['watching', 'Watching it'],
    ['not_sure', "I'm not sure"],
  ],
  includes('breast.which', 'cancer'),
  { section: 'reproductive' },
);
multi(
  'breast.surgery',
  'What surgery?',
  [
    ['biopsy', 'Biopsy'],
    ['lumpectomy', 'Lumpectomy or a portion removed'],
    ['simple', 'Simple mastectomy'],
    ['modified', 'Modified radical mastectomy'],
    ['radical', 'Radical mastectomy'],
    ['nodes', 'Lymph nodes removed'],
    ['none', 'None of these'],
  ],
  includes('breast.which', 'surgery'),
  { section: 'reproductive', createsEachOption: false },
);
yesNo('breast.form', 'Did the surgery change the size or shape in a way you can see?', includes('breast.which', 'surgery'), {
  section: 'reproductive',
});
yesNo(
  'breast.residual',
  'After treatment, do you have arm swelling, nerve trouble in the arm, or another leftover problem?',
  includes('breast.which', 'cancer'),
  { section: 'reproductive' },
);
tail('reproductive', reproGate);

const bloodGate = yes('blood');
multi(
  'blood.which',
  'Which of these fit?',
  [
    ['anemia', 'Anemia or low platelets'],
    ['leukemia', 'Leukemia or lymphoma'],
    ['myeloma', 'Multiple myeloma'],
    ['sickle', 'Sickle cell disease'],
    ['hiv', 'HIV'],
    ['tb', 'Tuberculosis'],
    ['gulf', 'A Gulf War or Afghanistan infection'],
    ['infection', 'Another infection'],
    ['nutrition', 'A vitamin deficiency such as pellagra or beriberi'],
    ['none', 'None of these'],
  ],
  bloodGate,
  { section: 'blood' },
);
yesNo('blood.medicine', 'Do you take medicine regularly for this?', bloodGate, { section: 'blood' });
const ANEMIAS = [
  ['iron', 'Iron deficiency'],
  ['b12', 'B12 or pernicious anemia'],
  ['folic', 'Folic acid deficiency'],
  ['hemolytic', 'Hemolytic anemia'],
  ['aplastic', 'Aplastic anemia'],
  ['itp', 'Immune thrombocytopenia'],
  ['sickle', 'Sickle cell'],
  ['treatment', 'Caused by treatment for something else'],
  ['not_sure', "I'm not sure"],
];
multi('anemia.which', 'Which anemia or platelet problem was named?', ANEMIAS, includes('blood.which', 'anemia'), {
  section: 'blood',
});
perChecked('anemia.which', ANEMIAS.filter(([value]) => value !== 'not_sure'), (value, label, shown) => {
  single(
    `anemia.${value}.transfusion`,
    `In the past year, how often did ${label.toLowerCase()} need a transfusion?`,
    [
      ['none', 'None'],
      ['once', 'About once'],
      ['3_months', 'About every 3 months'],
      ['6_weeks', 'About every 6 weeks'],
    ],
    shown,
    { section: 'blood' },
  );
  single(
    `anemia.${value}.status`,
    `Is ${label.toLowerCase()} still being treated?`,
    [
      ['treating', 'Still being treated'],
      ['finished', 'Treatment finished'],
      ['watching', 'Watching it'],
      ['not_sure', "I'm not sure"],
    ],
    shown,
    { section: 'blood' },
  );
});
const LEUKEMIAS = [
  ['all', 'Acute lymphoblastic leukemia'],
  ['aml', 'Acute myeloid leukemia'],
  ['cll', 'Chronic lymphocytic leukemia'],
  ['cml', 'Chronic myeloid leukemia'],
  ['hodgkin', 'Hodgkin lymphoma'],
  ['non_hodgkin', 'Non-Hodgkin lymphoma'],
  ['myeloma', 'Multiple myeloma'],
];
multi(
  'leukemia.which',
  'Which leukemia, lymphoma, or myeloma was named?',
  LEUKEMIAS,
  bloodGate,
  { section: 'blood' },
);
perChecked('leukemia.which', LEUKEMIAS, (value, label, shown) => {
  single(
    `leukemia.${value}.status`,
    `Where is ${label} now?`,
    [
      ['active', 'Active and not treating'],
      ['treating', 'In treatment'],
      ['remission', 'In remission, treatment finished'],
      ['not_sure', "I'm not sure"],
    ],
    shown,
    { section: 'blood' },
  );
  single(
    `leukemia.${value}.transfusion`,
    `In the past year, how often did ${label} need a transfusion?`,
    [
      ['none', 'None'],
      ['once', 'About once'],
      ['3_months', 'About every 3 months'],
      ['6_weeks', 'About every 6 weeks'],
    ],
    shown,
    { section: 'blood' },
  );
});
yesNo('hiv.medicine', 'Do you take medicine regularly for HIV?', includes('blood.which', 'hiv'), {
  section: 'blood',
});
multi(
  'hiv.symptoms',
  'Which of these have you had with HIV?',
  [
    ['fever', 'Fever, fatigue, or poor appetite that keeps coming back'],
    ['diarrhea', 'Diarrhea'],
    ['weight', 'Weight loss that will not stop'],
    ['depression', 'Depression', { opensGate: 'mental' }],
    ['memory', 'Memory trouble', { opensGate: 'mental' }],
    ['opportunistic', 'An opportunistic infection or a cancer a doctor tied to HIV'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'hiv'),
  { section: 'blood', createsEachOption: false },
);
multi(
  'tb.which',
  'Which tuberculosis description fits?',
  [
    ['active', 'Active tuberculosis'],
    ['inactive', 'Treatment finished and it is inactive'],
    ['latent', 'A positive skin test or blood test without active disease'],
    ['outside', 'Outside the lungs'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'tb'),
  { section: 'blood' },
);
multi(
  'tb.where',
  'Where outside the lungs?',
  [
    ['lining', 'Lung lining'],
    ['belly', 'Belly'],
    ['brain', 'Brain lining'],
    ['voice', 'Voice box'],
    ['bones', 'Bones'],
    ['kidney', 'Kidney or bladder'],
    ['gut', 'Gut'],
    ['nodes', 'Lymph nodes'],
    ['skin', 'Skin'],
    ['eyes', 'Eyes'],
    ['other', 'Other'],
  ],
  includes('tb.which', 'outside'),
  { section: 'blood', createsEachOption: false },
);
single(
  'tb.treatment',
  'Are you on treatment, or did you finish it?',
  [
    ['now', 'On it now'],
    ['finished', 'Finished'],
    ['never', 'Never treated'],
  ],
  includes('blood.which', 'tb'),
  { section: 'blood' },
);
multi(
  'gulf.which',
  'Which infection was named?',
  [
    ['brucella', 'Brucellosis'],
    ['campylobacter', 'Campylobacter'],
    ['q_fever', 'Q fever'],
    ['malaria', 'Malaria'],
    ['salmonella', 'Salmonella'],
    ['shigella', 'Shigella'],
    ['leishmania', 'Visceral leishmaniasis'],
    ['west_nile', 'West Nile'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'gulf'),
  { section: 'blood' },
);
multi(
  'infection.which',
  'Which other infection was named?',
  [
    ['lyme', 'Lyme disease'],
    ['malaria', 'Malaria'],
    ['hemorrhagic', 'Dengue, yellow fever, or another hemorrhagic fever'],
    ['leprosy', 'Leprosy'],
    ['rheumatic', 'Rheumatic fever'],
    ['syphilis', 'Syphilis'],
    ['schisto', 'Schistosomiasis'],
    ['plague', 'Plague'],
    ['cholera', 'Cholera'],
    ['strongyloides', 'Strongyloides'],
    ['parasite', 'A parasite not listed'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'infection'),
  { section: 'blood' },
);
single(
  'infection.status',
  'Is that infection active?',
  [
    ['active', 'Active'],
    ['inactive', 'Inactive'],
  ],
  includes('blood.which', 'infection'),
  { section: 'blood' },
);
multi(
  'nutrition.which',
  'Which deficiency was named?',
  [
    ['pellagra', 'Pellagra or a general vitamin lack'],
    ['beriberi', 'Beriberi'],
    ['other', 'Another vitamin deficiency'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'nutrition'),
  { section: 'blood' },
);
multi(
  'nutrition.symptoms',
  'What did it do?',
  [
    ['appetite', 'Poor appetite, weakness, or trouble concentrating'],
    ['mouth', 'Sores in the mouth'],
    ['diarrhea', 'Diarrhea'],
    ['rash', 'A rash on both sides'],
    ['mental', 'Mental changes'],
    ['numb', 'Numbness or weak legs'],
    ['heart', 'Heart trouble'],
    ['none', 'None of these'],
  ],
  includes('blood.which', 'nutrition'),
  { section: 'blood', createsEachOption: false },
);
tail('blood', bloodGate);

const generalGate = yes('general');
multi(
  'general.which',
  'Which of these fit?',
  [
    ['cfs', 'Chronic fatigue syndrome'],
    ['fibro', 'Fibromyalgia'],
    ['auto', 'Lupus or another autoimmune disease'],
    ['arthritis', 'Arthritis in several joints'],
    ['amp', 'A missing arm, hand, leg, or foot'],
    ['none', 'None of these'],
  ],
  generalGate,
  { section: 'general' },
);
yesNo('fibro.medicine', 'Do you take medicine regularly for this?', includes('general.which', 'fibro'), {
  section: 'general',
});
multi(
  'fibro.symptoms',
  'Which of these come with the fibromyalgia?',
  [
    ['widespread', 'Pain on both sides, above and below the waist, including the spine or chest'],
    ['stiff', 'Stiffness'],
    ['weak', 'Muscle weakness'],
    ['fatigue', 'Fatigue'],
    ['sleep', 'Poor sleep'],
    ['numb', 'Numbness or tingling'],
    ['headache', 'Headache'],
    ['depression', 'Depression'],
    ['anxiety', 'Anxiety'],
    ['ibs', 'Irritable bowel symptoms'],
    ['color', 'Fingers that change color in the cold'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'fibro'),
  { section: 'general', createsEachOption: false },
);
single(
  'fibro.often',
  'How much of the time are they there?',
  [
    ['none', 'No symptoms now'],
    ['comes', 'They come and go'],
    ['third', 'Present more than one-third of the time'],
    ['constant', 'Constant or nearly constant'],
  ],
  includes('general.which', 'fibro'),
  { section: 'general' },
);
yesNo('fibro.stress', 'Do stress, weather, or overdoing it set them off?', includes('general.which', 'fibro'), {
  section: 'general',
});
yesNo('cfs.medicine', 'Do you take medicine regularly for this?', includes('general.which', 'cfs'), {
  section: 'general',
});
single(
  'cfs.medicineHelps',
  'Does the medicine control the symptoms?',
  [
    ['yes', 'It controls the symptoms'],
    ['no', 'It does not'],
  ],
  yes('cfs.medicine'),
  { section: 'general' },
);
yesNo(
  'cfs.cut',
  'Has the fatigue cut your daily activity to less than half of what it was?',
  includes('general.which', 'cfs'),
  { section: 'general' },
);
single(
  'cfs.cutDuration',
  'How long has it been that way?',
  [
    ['under_6', 'Less than 6 months'],
    ['6_plus', '6 months or longer'],
  ],
  yes('cfs.cut'),
  { section: 'general' },
);
multi(
  'cfs.symptoms',
  'Which of these come with the fatigue?',
  [
    ['floor', 'Fatigue that floors you'],
    ['headache', 'A headache that is different from ones you had before'],
    ['fever', 'Low fever'],
    ['joint', 'Joint pain that moves around'],
    ['throat', 'Sore throat without pus'],
    ['nodes', 'Swollen or tender lymph nodes'],
    ['thinking', 'Trouble thinking'],
    ['muscle', 'Muscle aches or weakness'],
    ['after', 'Fatigue that lasts a day or more after exercise'],
    ['sleep', 'Poor sleep'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'cfs'),
  { section: 'general', createsEachOption: false },
);
multi(
  'cfs.thinking',
  'What kind of trouble thinking?',
  [
    ['focus', 'Cannot concentrate'],
    ['forget', 'Forgetfulness'],
    ['confusion', 'Confusion'],
  ],
  includes('cfs.symptoms', 'thinking'),
  { section: 'general', createsEachOption: false },
);
single(
  'cfs.often',
  'How constant is it?',
  [
    ['constant', 'Nearly constant'],
    ['comes', 'They come and go'],
  ],
  includes('general.which', 'cfs'),
  { section: 'general' },
);
single(
  'cfs.restrict',
  'How much activity is left?',
  [
    ['care', 'Almost unable to care for myself'],
    ['under_half', 'Less than half of my old activity'],
    ['half', 'About half to three-quarters'],
    ['quarter', 'Less than a quarter less than before'],
  ],
  [{ questionId: 'cfs.often', equals: 'constant' }],
  { section: 'general' },
);
single(
  'cfs.bed',
  'In the past year, how much time were you in bed because a doctor was treating this?',
  [
    ['none', 'None'],
    ...BED,
  ],
  includes('general.which', 'cfs'),
  { section: 'general' },
);
multi(
  'arthritis.which',
  'Which arthritis in more than one joint was named?',
  [
    ['rheumatoid', 'Rheumatoid or another arthritis in two or more joints'],
    ['psoriatic', 'Psoriatic arthritis'],
    ['gout', 'Gout'],
    ['infection', 'An infection a doctor tied to the joints'],
    ['decompression', 'Decompression illness'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'arthritis'),
  { section: 'general' },
);
multi(
  'arthritis.health',
  'Has it affected your general health in these ways?',
  [
    ['weight', 'Weight loss that affected my health'],
    ['anemia', 'Anemia that affected my health'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'arthritis'),
  { section: 'general', createsEachOption: false },
);
single(
  'arthritis.flares',
  'In a typical year, how many flares did not put you on doctor-ordered bed rest?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4_plus', '4 or more'],
  ],
  includes('general.which', 'arthritis'),
  { section: 'general' },
);
single(
  'arthritis.down',
  'How many flares did, with bed rest a doctor ordered?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['4_plus', '4 or more'],
  ],
  includes('general.which', 'arthritis'),
  { section: 'general' },
);
single('arthritis.downTime', 'About how long was that bed rest, in total?', BED, includes('general.which', 'arthritis'), {
  section: 'general',
});
multi(
  'auto.which',
  'Which autoimmune disease was named?',
  [
    ['sle', 'Systemic lupus'],
    ['discoid', 'Discoid or skin lupus'],
    ['ra', 'Rheumatoid arthritis'],
    ['scleroderma', 'Scleroderma'],
    ['sjogren', "Sjogren's"],
    ['gca', 'Giant cell arteritis'],
    ['wegener', "Wegener's"],
    ['guillain', 'Guillain-Barre'],
    ['pmr', 'Polymyalgia rheumatica'],
    ['goodpasture', "Goodpasture's"],
    ['type1', 'Type 1 diabetes'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'auto'),
  { section: 'general' },
);
multi(
  'auto.medicine',
  'What medicine do you take for it?',
  [
    ['pills', 'Steroid pills'],
    ['cream', 'Steroid cream'],
    ['immune', 'Other immune medicine'],
    ['none', 'None of these'],
  ],
  includes('general.which', 'auto'),
  { section: 'general', createsEachOption: false },
);
single(
  'auto.flares',
  'In a typical year, how many flares?',
  [
    ['0', '0'],
    ['1', '1'],
    ['2', '2'],
    ['3', '3'],
    ['more', 'More than 3'],
  ],
  includes('general.which', 'auto'),
  { section: 'general' },
);
tail('general', generalGate);

single(
  'sb.type',
  'What form of spina bifida was named for the child?',
  [
    ['occulta', 'Occulta only'],
    ['other', 'Another form'],
  ],
  [],
  { section: 'spinaBifida', includeInIntake: false },
);
yesNo(
  'sb.walk',
  'Is a wheelchair the main way they get around in the community?',
  [{ questionId: 'sb.type', equals: 'other' }],
  { section: 'spinaBifida', includeInIntake: false },
);
yesNo(
  'sb.arms',
  'Is there weakness or numbness in the arms?',
  [{ questionId: 'sb.type', equals: 'other' }],
  { section: 'spinaBifida', includeInIntake: false },
);
single(
  'sb.urine',
  'How is urine control?',
  [
    ['controlled', 'Controlled'],
    ['medicine', 'Medicine keeps leaks to twice a week or less'],
    ['leaks', 'Leaks at least three times a week despite medicine'],
  ],
  [{ questionId: 'sb.type', equals: 'other' }],
  { section: 'spinaBifida', includeInIntake: false },
);
single(
  'sb.bowel',
  'How is bowel control?',
  [
    ['managed', 'Managed without bad leaks'],
    ['leaks', 'Leaks often despite a program'],
    ['manual', 'Needs manual emptying or digital stimulation'],
  ],
  [{ questionId: 'sb.type', equals: 'other' }],
  { section: 'spinaBifida', includeInIntake: false },
);
multi(
  'sb.other',
  'Has a doctor also named any of these?',
  [
    ['blind', 'Blindness'],
    ['seizure', 'Seizures that are not controlled'],
    ['kidney', 'Kidney failure'],
    ['none', 'None of these'],
  ],
  [{ questionId: 'sb.type', equals: 'other' }],
  { section: 'spinaBifida', includeInIntake: false },
);

module.exports = { definition };
