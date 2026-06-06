importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCJUvzpz2wbS1Mf92nKWm_Xxt2vEZwLsK8",
  authDomain: "tistory-fcm-2605.firebaseapp.com",
  projectId: "tistory-fcm-2605",
  storageBucket: "tistory-fcm-2605.firebasestorage.app",
  messagingSenderId: "471395524735",
  appId: "1:471395524735:web:52cfc5d046521be385df4a",
  measurementId: "G-DZFP0J014T"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png"
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
