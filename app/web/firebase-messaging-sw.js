// Firebase Messaging Service Worker — required for web background notifications.
// This file MUST be at the web root so the browser can register it.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBuxVxAq899VwMuXaPSNyJ6Gy2dotbBbrY',
  authDomain: 'khidmatbot-app.firebaseapp.com',
  projectId: 'khidmatbot-app',
  storageBucket: 'khidmatbot-app.firebasestorage.app',
  messagingSenderId: '251161399989',
  appId: '1:251161399989:web:70dc97c20b3afccf8fa4fc',
});

const messaging = firebase.messaging();

// Show notification when app is in background / closed
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'KhidmatBot';
  const body  = payload.notification?.body  || '';
  self.registration.showNotification(title, {
    body,
    icon:  '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data:  payload.data || {},
  });
});
