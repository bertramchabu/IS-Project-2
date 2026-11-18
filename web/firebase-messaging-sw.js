importScripts(
    "https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js",
);
importScripts(
    "https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyA30d-hFVAlmJWW71lk6Q3x2QjuoUPJsvA",
  appId: "1:823236743234:web:9eef3870db5cb57b855ddb",
  messagingSenderId: "823236743234",
  projectId: "netvision-ai-0",
  authDomain: "netvision-ai-0.firebaseapp.com",
  storageBucket: "netvision-ai-0.firebasestorage.app",
  measurementId: "G-DJZ7XQ5E92",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const type = data.type;
  if (type !== "network_alert" && type !== "threat_alert") return;

  const title = payload.notification?.title || "Network alert";
  const body = payload.notification?.body || "A new alert needs your attention.";
  const alertId = type === "threat_alert" ? data.assessmentId : data.alertId;
  const target = new URL("/", self.location.origin);
  target.searchParams.set("notificationType", type);
  if (alertId) {
    target.searchParams.set(
        type === "threat_alert" ? "assessmentId" : "alertId",
        alertId,
    );
  }

  return self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/favicon.png",
    tag: alertId || "netvision-alert",
    data: {url: target.toString()},
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = event.notification.data?.url || self.location.origin;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({
      type: "window",
      includeUncontrolled: true,
    });
    for (const client of windows) {
      if (new URL(client.url).origin !== self.location.origin) continue;
      await client.navigate(targetUrl);
      return client.focus();
    }
    return self.clients.openWindow(targetUrl);
  })());
});
