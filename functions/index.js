const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { google } = require('googleapis');

const GMAIL_OAUTH_CLIENT_ID = defineString('GMAIL_OAUTH_CLIENT_ID');
const GMAIL_PUBSUB_TOPIC = defineString('GMAIL_PUBSUB_TOPIC');
const GMAIL_OAUTH_CLIENT_SECRET = defineSecret('GMAIL_OAUTH_CLIENT_SECRET');

const ALLOWED_EMAIL_DOMAIN = '@vitstudent.ac.in';
const TOKENS_COLLECTION = 'gmailTokens';
const STUDENTS_COLLECTION = 'students';

admin.initializeApp();

function assertVitStudent(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign in before connecting Gmail.');
  }

  const email = auth.token.email;
  if (!email || !email.toLowerCase().endsWith(ALLOWED_EMAIL_DOMAIN)) {
    throw new HttpsError(
      'permission-denied',
      `Gmail can only be connected for a ${ALLOWED_EMAIL_DOMAIN} account.`
    );
  }

  return { uid: auth.uid, email };
}

async function exchangeCode(code) {
  const oauth2Client = new google.auth.OAuth2(
    GMAIL_OAUTH_CLIENT_ID.value(),
    GMAIL_OAUTH_CLIENT_SECRET.value(),
    ''
  );

  let tokens;
  try {
    ({ tokens } = await oauth2Client.getToken({ code, redirect_uri: '' }));
  } catch (error) {
    const detail =
      (error.response && error.response.data && error.response.data.error_description) ||
      error.message;
    throw new HttpsError(
      'invalid-argument',
      `Google rejected the authorization code: ${detail}`
    );
  }

  if (!tokens.refresh_token) {
    throw new HttpsError(
      'failed-precondition',
      'Google did not return a refresh token. Revoke Orbit at ' +
        'myaccount.google.com/permissions and connect again.'
    );
  }

  oauth2Client.setCredentials(tokens);
  return { oauth2Client, tokens };
}

async function registerWatch(oauth2Client) {
  const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

  try {
    const response = await gmail.users.watch({
      userId: 'me',
      requestBody: {
        topicName: GMAIL_PUBSUB_TOPIC.value(),
        labelIds: ['INBOX'],
        labelFilterBehavior: 'INCLUDE',
      },
    });
    return response.data;
  } catch (error) {
    const detail =
      (error.errors && error.errors[0] && error.errors[0].message) || error.message;
    throw new HttpsError('internal', `Gmail watch failed: ${detail}`);
  }
}

exports.connectGmail = onCall(
  { secrets: [GMAIL_OAUTH_CLIENT_SECRET], region: 'us-central1' },
  async (request) => {
    const { uid, email } = assertVitStudent(request);

    const code = request.data && request.data.code;
    if (typeof code !== 'string' || code.length === 0) {
      throw new HttpsError('invalid-argument', 'Missing authorization code.');
    }

    const db = admin.firestore();
    const studentRef = db.collection(STUDENTS_COLLECTION).doc(uid);

    const student = await studentRef.get();
    if (!student.exists) {
      throw new HttpsError(
        'failed-precondition',
        'Finish onboarding before connecting Gmail.'
      );
    }

    const { oauth2Client, tokens } = await exchangeCode(code);

    try {
      const watch = await registerWatch(oauth2Client);
      const watchExpiration = watch.expiration
        ? admin.firestore.Timestamp.fromMillis(Number(watch.expiration))
        : null;

      await db.collection(TOKENS_COLLECTION).doc(uid).set(
        {
          refreshToken: tokens.refresh_token,
          scope: tokens.scope || null,
          email,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await studentRef.set(
        {
          gmailSync: {
            status: 'connected',
            historyId: watch.historyId ? String(watch.historyId) : null,
            watchExpiration,
            connectedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastError: null,
          },
        },
        { merge: true }
      );

      return {
        status: 'connected',
        historyId: watch.historyId ? String(watch.historyId) : null,
        watchExpiration: watchExpiration ? watchExpiration.toMillis() : null,
      };
    } catch (error) {
      await studentRef.set(
        {
          gmailSync: {
            status: 'error',
            lastError: error.message || 'Unknown error',
          },
        },
        { merge: true }
      );
      throw error instanceof HttpsError
        ? error
        : new HttpsError('internal', error.message || 'Could not connect Gmail.');
    }
  }
);
