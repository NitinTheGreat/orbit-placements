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

describe('one-time NeoID edit', () => {
  const profile = {
    vitEmail: 'nitin@vitstudent.ac.in',
    name: 'Nitin Kumar Pandey 23BCT0098',
    neoId: 'L5P2U7S5',
    regNo: '23BCT0098',
  };

  function studentDoc(context) {
    return doc(context.firestore(), 'students', UID);
  }

  async function seed(extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'students', UID), {
        ...profile,
        ...extra,
      });
    });
  }

  test('allows the first change when it stamps neoIdEditedAt', async () => {
    await seed();
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(
      updateDoc(studentDoc(context), {
        neoId: 'CORRECT1',
        neoIdEditedAt: new Date(),
      }),
    );
  });

  test('rejects a change that does not stamp neoIdEditedAt', async () => {
    await seed();
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertFails(updateDoc(studentDoc(context), { neoId: 'CORRECT1' }));
  });

  test('rejects a second change once the stamp exists', async () => {
    await seed({ neoIdEditedAt: new Date() });
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertFails(
      updateDoc(studentDoc(context), {
        neoId: 'AGAIN123',
        neoIdEditedAt: new Date(),
      }),
    );
  });

  test('rejects an empty NeoID', async () => {
    await seed();
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertFails(
      updateDoc(studentDoc(context), { neoId: '', neoIdEditedAt: new Date() }),
    );
  });

  test('rejects smuggling another field in alongside the edit', async () => {
    await seed();
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertFails(
      updateDoc(studentDoc(context), {
        neoId: 'CORRECT1',
        neoIdEditedAt: new Date(),
        regNo: '23BCE0001',
      }),
    );
  });

  test('leaves unrelated profile edits working', async () => {
    await seed({ neoIdEditedAt: new Date() });
    const context = testEnv.authenticatedContext(UID, vitToken);
    await assertSucceeds(updateDoc(studentDoc(context), { name: 'Nitin P' }));
  });

  test('stops another student editing it', async () => {
    await seed();
    const context = testEnv.authenticatedContext('someone-else', vitToken);
    await assertFails(
      updateDoc(studentDoc(context), {
        neoId: 'STOLEN01',
        neoIdEditedAt: new Date(),
      }),
    );
  });
});
