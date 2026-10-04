# Questionnaires

The condition-discovery catalog is versioned JSON in the repo. The app reads the published copy. It does not write it.

## Source

`questionnaires/catalog.js` is the editable catalog. `questionnaires/condition-discovery-v2.json` is the file the publish command reads. Rebuild the JSON from the catalog before publishing:

```bash
node -e "require('fs').writeFileSync('questionnaires/condition-discovery-v2.json', JSON.stringify(require('./questionnaires/catalog').definition(), null, 2))"
```

Run that from the repo root.

The current id is `condition-discovery-v2`. Its version is `2`. In development that id can be published again. Production still refuses to replace an active id.

## What a question stores

Each question has an id, a prompt, an answer type, choices when it is a choice, and `showWhen`. Every rule in `showWhen` must match or the question is not asked. `equals` matches one choice. `includes` matches one value inside a multiple choice. `includesAny` matches when any listed value is checked.

Answer types are `singleChoice`, `multiChoice`, `yearMonth`, and `note`. A note is optional and sits at the end of a section. A year and month is the only date.

A yes on a body-system gate does not create a condition. A checked diagnosis does. `createsEachOption` creates one possible condition for each checked choice, except `none`, `not_sure`, and `not_applicable`. `createsCondition` names the condition for a single yes.

`includeInIntake` is false for the spina bifida questions. Those questions are stored for a later claim about a child. This Veteran's questionnaire does not ask them.

If the choice `Thoughts of suicide` is selected, that question shows "If this is an emergency, call or text 988, then press 1." The answer is still saved. That choice is marked `crisisNotice`.

## What is asked

The gates are head, eyes, hearing, nose and throat, breathing, sleep, heart, stomach and bowel, kidney and urinary, hormones, skin, back, neck, joints, nerves, mental health, dental, reproductive, blood, and whole body. A no skips that system.

Each checked condition then asks the form's side, how often, or how bad, in the form's words. Degrees, centimeters, lab values, reflex grades, strength scores, imaging, and signatures are not asked. Bladder questions say "urinate." On the kidney and urinary page they follow leaking or frequency. On the head page they follow Parkinson's, multiple sclerosis, or ALS.

Muscle groups are the twenty-three groups from the muscle-injury form, each with a side and a severity. Foot choices include claw foot, hallux rigidus, and a bone that healed crooked or did not heal. Bone choices include skull fracture, skull loss, rib fracture, rib removal, costochondritis, and coccyx removal. Shoulder choices include the collarbone, the AC joint, and an upper arm bone that healed crooked. Parkinson's asks about speech, smell, taste, sleep, sexual function, and mental changes. Cranial-nerve questions ask where on the face and whether it is mild, moderate, or severe. Each named anemia and leukemia asks how often a transfusion was needed and whether treatment is finished.

## Publish

From the repo root:

```bash
npm run publish-questionnaire:dev
npm run publish-questionnaire:prod
```

The dev command writes `questionnaireDefinitions/condition-discovery-v2` and one `questionDefinitions` document per question in `veteran-claims-buddy-dev`. The prod command does the same in `veteran-claims-buddy-prod`. Prod refuses to run without `--confirm-prod`, including when the node script is called directly. The script also refuses to replace an id whose status is already `active`.

The script uses the active gcloud account, the same way `dev:reset-user` does. It does not print the token.

Firestore rules let a signed-in Veteran with a verified email and a confirmed second factor read the catalog. Client writes are denied. The publish script uses a user token with project access, so it is not blocked by those rules.

The app loads this catalog from Firestore. An answer set stored for an older shape is deleted in development, and the questionnaire starts on this catalog.

The first page asks the body-system yes or no questions together, and answering does not add questions to that page. Continue opens each Yes as its own page. A No leaves that system off the list. The topic name stays at the top of that page as the heading while the questions scroll, and the scrollbar stays visible. Under the topic name, a badge says "Nothing is filed with the VA at this step." A topic page lists every question for that area. A question that does not apply is disabled, with a quiet badge that names the answer it depends on. That changes as soon as the answer changes. Continue saves the page and moves to the next topic. A save writes only the answers that changed.
