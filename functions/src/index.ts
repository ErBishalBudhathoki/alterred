import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const health = functions.region("australia-southeast1").https.onRequest((req, res) => {
  res.set("Cache-Control", "no-store");
  res.status(200).json({ ok: true, time: new Date().toISOString() });
});

