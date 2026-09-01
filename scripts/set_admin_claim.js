const admin = require('firebase-admin');

function usage() {
  console.error('Usage: node set_admin_claim.js <uid> [--revoke]');
  console.error('');
  console.error('Requires GOOGLE_APPLICATION_CREDENTIALS to point at a');
  console.error('service account key JSON for the orbit-placements project.');
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  const uid = args.find((arg) => !arg.startsWith('--'));
  const revoke = args.includes('--revoke');

  if (!uid) {
    usage();
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('GOOGLE_APPLICATION_CREDENTIALS is not set.');
    process.exit(1);
  }

  admin.initializeApp({ credential: admin.credential.applicationDefault() });

  const user = await admin.auth().getUser(uid);
  const claims = { ...(user.customClaims || {}) };

  if (revoke) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await admin.auth().setCustomUserClaims(uid, claims);
  await admin.auth().revokeRefreshTokens(uid);

  console.log(
    `${revoke ? 'Revoked' : 'Granted'} admin for ${user.email || uid}.`
  );
  console.log('The user must sign out and back in for the claim to take effect.');
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
