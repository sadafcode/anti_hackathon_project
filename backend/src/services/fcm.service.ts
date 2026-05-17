import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

let initialized = false;

function initFirebaseAdmin() {
  if (initialized || admin.apps.length > 0) return;

  // Try service account file first, then fall back to Application Default Credentials
  const keyPath = path.resolve(process.cwd(), 'serviceAccountKey.json');
  if (fs.existsSync(keyPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(keyPath),
    });
    console.log('[FCM] Firebase Admin initialized with service account key.');
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp();
    console.log('[FCM] Firebase Admin initialized with ADC.');
  } else {
    console.warn('[FCM] No Firebase credentials found — push notifications disabled. Add serviceAccountKey.json to root.');
    return;
  }
  initialized = true;
}

export interface FcmPayload {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendPushNotification(payload: FcmPayload): Promise<boolean> {
  initFirebaseAdmin();
  if (!initialized) return false;

  try {
    await admin.messaging().send({
      token: payload.token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'khidmatbot_bookings',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
    console.log(`[FCM] Notification sent to token ${payload.token.substring(0, 20)}...`);
    return true;
  } catch (err: any) {
    console.warn('[FCM] Notification send failed:', err?.message || err);
    return false;
  }
}

// Get FCM token for a provider from Firestore
export async function getProviderFcmToken(providerId: string): Promise<string | null> {
  initFirebaseAdmin();
  if (!initialized) return null;
  try {
    const db = admin.firestore();
    const doc = await db.collection('fcm_tokens').doc(`provider_${providerId}`).get();
    return doc.exists ? (doc.data()?.token as string) || null : null;
  } catch {
    return null;
  }
}

// Get FCM token for a client session from Firestore
export async function getClientFcmToken(sessionId: string): Promise<string | null> {
  initFirebaseAdmin();
  if (!initialized) return null;
  try {
    const db = admin.firestore();
    const doc = await db.collection('fcm_tokens').doc(`client_${sessionId}`).get();
    return doc.exists ? (doc.data()?.token as string) || null : null;
  } catch {
    return null;
  }
}
