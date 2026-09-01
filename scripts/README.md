# Scripts

Grant yourself the admin custom claim (needed to write to `companies` and to see the admin route):

```bash
cd scripts && npm install firebase-admin
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
node set_admin_claim.js <your-firebase-uid>
```

Download the service account key from Firebase Console → Project settings → Service accounts → Generate new private key. Find your UID in Firebase Console → Authentication → Users. Pass `--revoke` to remove the claim. Sign out and back in for the change to reach the client.
