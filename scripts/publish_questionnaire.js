'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');

const PROJECTS = {
  dev: 'veteran-claims-buddy-dev',
  prod: 'veteran-claims-buddy-prod',
};

const CHOICE_TYPES = new Set(['singleChoice', 'multiChoice']);
const ANSWER_TYPES = new Set([
  'singleChoice',
  'multiChoice',
  'yearMonth',
  'note',
]);

function parseArgs(argv) {
  const projectFlag = argv.indexOf('--project');
  const fileFlag = argv.indexOf('--file');
  const project = projectFlag >= 0 ? argv[projectFlag + 1] : '';
  const file = fileFlag >= 0 ? argv[fileFlag + 1] : '';
  return {
    project,
    file,
    confirmProd: argv.includes('--confirm-prod'),
  };
}

function assertPublishAllowed({ project, confirmProd }) {
  const projectId = PROJECTS[project];
  if (!projectId) {
    throw new Error('Pass --project dev or --project prod.');
  }
  if (project === 'prod' && !confirmProd) {
    throw new Error('Refusing to publish to production. Pass --confirm-prod.');
  }
  if (projectId.includes('prod') && project !== 'prod') {
    throw new Error(`Refusing to publish to ${projectId}.`);
  }
  return projectId;
}

function validateDefinition(definition) {
  if (!definition || typeof definition !== 'object') {
    throw new Error('Questionnaire file must be an object.');
  }
  if (!definition.id || typeof definition.id !== 'string') {
    throw new Error('Questionnaire id is required.');
  }
  if (!Number.isInteger(definition.version)) {
    throw new Error('Questionnaire version must be an integer.');
  }
  if (!['active', 'draft', 'retired'].includes(definition.status)) {
    throw new Error('Questionnaire status must be active, draft, or retired.');
  }
  if (!Array.isArray(definition.questions) || definition.questions.length === 0) {
    throw new Error('Questionnaire questions are required.');
  }
  const ids = new Set();
  for (const question of definition.questions) {
    if (!question.id || ids.has(question.id)) {
      throw new Error(`Duplicate or missing question id: ${question.id}`);
    }
    if (!/^[A-Za-z0-9_.-]+$/.test(question.id)) {
      throw new Error(`Question id has unsupported characters: ${question.id}`);
    }
    ids.add(question.id);
    if (!question.prompt || typeof question.prompt !== 'string') {
      throw new Error(`Question ${question.id} needs a prompt.`);
    }
    if (!ANSWER_TYPES.has(question.answerType)) {
      throw new Error(`Question ${question.id} has an unknown answer type.`);
    }
    if (CHOICE_TYPES.has(question.answerType)) {
      if (!Array.isArray(question.options) || question.options.length < 2) {
        throw new Error(`Question ${question.id} needs choices.`);
      }
      const values = new Set();
      for (const choice of question.options) {
        if (!choice.value || !choice.label || values.has(choice.value)) {
          throw new Error(`Question ${question.id} has a bad choice: ${choice.value}`);
        }
        values.add(choice.value);
      }
    }
  }
  if (!ids.has(definition.entryQuestionId)) {
    throw new Error('Entry question is missing.');
  }
  for (const question of definition.questions) {
    for (const rule of question.showWhen || []) {
      if (!ids.has(rule.questionId)) {
        throw new Error(
          `Question ${question.id} depends on missing question ${rule.questionId}.`,
        );
      }
      const parent = definition.questions.find((item) => item.id === rule.questionId);
      if (rule.equals !== undefined && CHOICE_TYPES.has(parent.answerType)) {
        const values = new Set(parent.options.map((choice) => choice.value));
        if (!values.has(rule.equals)) {
          throw new Error(
            `Question ${question.id} expects ${rule.questionId} to equal ${rule.equals}.`,
          );
        }
      }
      if (rule.includes !== undefined) {
        const values = new Set(parent.options.map((choice) => choice.value));
        if (!values.has(rule.includes)) {
          throw new Error(
            `Question ${question.id} expects ${rule.questionId} to include ${rule.includes}.`,
          );
        }
      }
    }
  }
  return definition;
}

function assertNotActive(existingStatus, projectId) {
  if (existingStatus === 'active' && projectId !== PROJECTS.dev) {
    throw new Error(
      'Refusing to replace a questionnaire that is already active. Publish a new id.',
    );
  }
}

function toValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number' && Number.isInteger(value)) {
    return { integerValue: String(value) };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toValue) } };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [key, entry] of Object.entries(value)) {
      fields[key] = toValue(entry);
    }
    return { mapValue: { fields } };
  }
  throw new Error(`Cannot store ${typeof value}.`);
}

function documentFields(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = toValue(value);
  }
  return fields;
}

function accessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
  }).trim();
}

async function api(projectId, url, { method = 'GET', body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken()}`,
      'x-goog-user-project': projectId,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const message = data.error?.message || text || response.statusText;
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return data;
}

function definitionName(projectId, id) {
  return `projects/${projectId}/databases/(default)/documents/questionnaireDefinitions/${id}`;
}

function questionName(projectId, definitionId, questionId) {
  return `${definitionName(projectId, definitionId)}/questionDefinitions/${questionId}`;
}

async function existingStatus(projectId, id) {
  try {
    const document = await api(
      projectId,
      `https://firestore.googleapis.com/v1/${definitionName(projectId, id)}`,
    );
    return document.fields?.status?.stringValue || '';
  } catch (error) {
    if (error.status === 404) return '';
    throw error;
  }
}

function questionDocument(definition, question) {
  return {
    definitionId: definition.id,
    key: question.id,
    prompt: question.prompt,
    answerType: question.answerType,
    options: question.options,
    required: question.required,
    order: question.order,
    section: question.section || '',
    showWhen: question.showWhen,
    createsCondition: question.createsCondition,
    createsEachOption: question.createsEachOption,
    createsExcept: question.createsExcept,
    includeInIntake: question.includeInIntake,
    schemaVersion: 1,
  };
}

async function commitWrites(projectId, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let index = 0; index < writes.length; index += 400) {
    await api(projectId, url, {
      method: 'POST',
      body: { writes: writes.slice(index, index + 400) },
    });
  }
}

async function publish({ projectId, definition }) {
  const status = await existingStatus(projectId, definition.id);
  assertNotActive(status, projectId);
  const parent = definitionName(projectId, definition.id);
  const stamp = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
  if (!status) stamp.push({ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' });
  const writes = [
    {
      update: {
        name: parent,
        fields: documentFields({
          name: definition.name,
          type: definition.type,
          version: definition.version,
          status: definition.status,
          entryQuestionId: definition.entryQuestionId,
          schemaVersion: definition.schemaVersion,
          questionCount: definition.questions.length,
        }),
      },
      updateTransforms: stamp,
    },
  ];
  for (const question of definition.questions) {
    writes.push({
      update: {
        name: questionName(projectId, definition.id, question.id),
        fields: documentFields(questionDocument(definition, question)),
      },
    });
  }
  await commitWrites(projectId, writes);
  return { projectId, id: definition.id, questions: definition.questions.length };
}

async function main(argv) {
  const args = parseArgs(argv);
  const projectId = assertPublishAllowed(args);
  if (!args.file) throw new Error('Pass --file and the questionnaire JSON path.');
  const definition = validateDefinition(JSON.parse(fs.readFileSync(args.file, 'utf8')));
  const result = await publish({ projectId, definition });
  console.log(
    `Published ${result.id} (${result.questions} questions) to ${result.projectId}.`,
  );
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = {
  PROJECTS,
  parseArgs,
  assertPublishAllowed,
  validateDefinition,
  assertNotActive,
  toValue,
};
