importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

const firebaseConfig = {
  apiKey: "AIzaSyBtS42vOJrBfLUxGF5viQ4GJLXBvwaf-hU",
  authDomain: "mddprod-2954f.firebaseapp.com",
  projectId: "mddprod-2954f",
  storageBucket: "mddprod-2954f.firebasestorage.app",
  messagingSenderId: "21940943998",
  appId: "1:21940943998:web:4c752c992d2ef5f4ffec2f",
  measurementId: "G-PC7F73PN6E"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // You can customize notification handling here if needed
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
