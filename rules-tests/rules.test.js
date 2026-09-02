import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const UID = 'student-1';
const COMPANY = 'company-1';
const STATUS_ID = `${UID}_${COMPANY}`;

const vitToken = {
  email: 'nitin@vitstudent.ac.in',
  email_verified: true,
};

let testEnv;

function statusDoc(context) {
  return doc(context.firestore(), 'studentCompanyStatus', STATUS_ID);
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'orbit-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('studentCompanyStatus client create', () => {
  test('allows exactly the permitted field set', async () => {
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(
      setDoc(statusDoc(context), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: ['neopat-register'],
        updatedAt: new Date(),
      }),
    );
  });

  test('allows a partial create, since the doc is made lazily', async () => {
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(
      setDoc(statusDoc(context), {
        studentId: UID,
        companyId: COMPANY,
        completedRequirementIds: ['neopat-register'],
        updatedAt: new Date(),
      }),
    );
  });

  for (const [field, value] of [
    ['overallStatus', 'selected'],
    ['currentRoundId', 'technical-round-1'],
    ['roundHistory', [{ roundId: 'r1', result: 'cleared' }]],
    ['source', 'gmail_ingestion'],
  ]) {
    test(`rejects a create carrying ${field}`, async () => {
      const context = testEnv.authenticatedContext(UID, vitToken);
      await assertFails(
        setDoc(statusDoc(context), {
          studentId: UID,
          companyId: COMPANY,
          optedIn: true,
          completedRequirementIds: [],
          updatedAt: new Date(),
          [field]: value,
        }),
      );
    });
  }

  test('rejects a create for another student', async () => {
    const context = testEnv.authenticatedContext('someone-else', vitToken);
    await assertFails(
      setDoc(statusDoc(context), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: [],
        updatedAt: new Date(),
      }),
    );
  });

  test('rejects a doc id that does not match uid_companyId', async () => {
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertFails(
      setDoc(doc(context.firestore(), 'studentCompanyStatus', 'wrong-id'), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: [],
        updatedAt: new Date(),
      }),
    );
  });

  test('rejects a non-VIT account', async () => {
    const context = testEnv.authenticatedContext(UID, {
      email: 'someone@gmail.com',
      email_verified: true,
    });
    await assertFails(
      setDoc(statusDoc(context), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: [],
        updatedAt: new Date(),
      }),
    );
  });

  test('rejects an unverified email', async () => {
    const context = testEnv.authenticatedContext(UID, {
      email: 'nitin@vitstudent.ac.in',
      email_verified: false,
    });
    await assertFails(
      setDoc(statusDoc(context), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: [],
        updatedAt: new Date(),
      }),
    );
  });
});

describe('studentCompanyStatus client update', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'studentCompanyStatus', STATUS_ID), {
        studentId: UID,
        companyId: COMPANY,
        optedIn: true,
        completedRequirementIds: [],
        currentRoundId: 'technical-round-1',
        roundHistory: [{ roundId: 'technical-round-1', result: 'cleared' }],
        overallStatus: 'active',
        source: 'gmail_ingestion',
        updatedAt: new Date(),
      });
    });
  });

  test('allows toggling optedIn and ticking a requirement', async () => {
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(
      updateDoc(statusDoc(context), {
        optedIn: false,
        completedRequirementIds: ['neopat-register'],
        updatedAt: new Date(),
      }),
    );
  });

  for (const [field, value] of [
    ['overallStatus', 'selected'],
    ['currentRoundId', 'hr-round'],
    ['roundHistory', []],
    ['source', 'admin_manual'],
  ]) {
    test(`rejects an update touching ${field}`, async () => {
      const context = testEnv.authenticatedContext(UID, vitToken);
      await assertFails(
        updateDoc(statusDoc(context), {
          [field]: value,
          updatedAt: new Date(),
        }),
      );
    });
  }

  test('lets the owner read their own doc', async () => {
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(getDoc(statusDoc(context)));
  });

  test('stops another student reading it', async () => {
    const context = testEnv.authenticatedContext('someone-else', vitToken);
    await assertFails(getDoc(statusDoc(context)));
  });
});
