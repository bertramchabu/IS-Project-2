const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

setGlobalOptions({maxInstances: 10});
initializeApp();

const db = getFirestore();
const notificationRoles = ["role_network_admin", "role_system_admin"];
const notificationChannelId = "netvision_alerts";

/** Sends an FCM notification to active network and system administrators. */
async function sendAdminNotification({
  nodeId,
  notification,
  messageData,
}) {
  const users = [];
  for (const roleId of notificationRoles) {
    const matchingUsers = await db.collection("users")
        .where("roleId", "==", roleId)
        .get();
    users.push(...matchingUsers.docs.filter((user) =>
      user.get("isActive") !== false));
  }

  const deviceSnapshots = await Promise.all(users.map((user) =>
    user.ref.collection("devices").get()));
  const recipients = new Map();
  for (const device of deviceSnapshots.flatMap((result) => result.docs)) {
    const data = device.data();
    if (!["android", "web"].includes(data.platform) ||
        typeof data.token !== "string" ||
        data.token.length === 0) {
      continue;
    }
    const tokenDevices = recipients.get(data.token) || [];
    tokenDevices.push(device.ref);
    recipients.set(data.token, tokenDevices);
  }

  const entries = [...recipients.entries()];
  if (entries.length === 0) {
    logger.info("Network event has no registered push recipients.", {
      nodeId,
      ...messageData,
    });
    return;
  }

  for (let start = 0; start < entries.length; start += 500) {
    const batch = entries.slice(start, start + 500);
    const result = await getMessaging().sendEachForMulticast({
      tokens: batch.map(([token]) => token),
      notification,
      data: {nodeId, ...messageData},
      android: {
        priority: "high",
        notification: {
          channelId: notificationChannelId,
          icon: "ic_stat_netvision",
        },
      },
      webpush: {
        headers: {Urgency: "high"},
        notification: {
          title: notification.title,
          body: notification.body,
          icon: "/icons/Icon-192.png",
          tag: messageData.alertId ||
            messageData.assessmentId ||
            "netvision-alert",
        },
      },
    });

    const invalidTokenDeletes = [];
    result.responses.forEach((response, index) => {
      if (response.success) return;
      const code = response.error && response.error.code;
      if (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token") {
        invalidTokenDeletes.push(
            ...batch[index][1].map((deviceRef) => deviceRef.delete()),
        );
      } else {
        logger.warn("Failed to deliver a network event notification.", {
          nodeId,
          code,
          ...messageData,
        });
      }
    });
    const cleanupResults = await Promise.allSettled(invalidTokenDeletes);
    for (const cleanup of cleanupResults) {
      if (cleanup.status === "rejected") {
        logger.error("Could not remove an expired FCM device token.", {
          nodeId,
          error: cleanup.reason,
          ...messageData,
        });
      }
    }
  }
}

exports.notifyOnNetworkAlert = onDocumentCreated(
    {
      document: "networkNodes/{nodeId}/alerts/{alertId}",
      region: "africa-south1",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const alert = snapshot.data();
      if (alert.status !== "Active") return;
      await sendAdminNotification({
        nodeId: event.params.nodeId,
        notification: {
          title: alert.title || `Network alert on ${event.params.nodeId}`,
          body: alert.description || "A new network alert was created.",
        },
        messageData: {
          type: "network_alert",
          alertId: snapshot.id,
        },
      });
    },
);

exports.notifyOnThreatAssessment = onDocumentCreated(
    {
      document: "threatAssessments/{assessmentId}",
      region: "africa-south1",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const assessment = snapshot.data();
      const category = assessment.category;
      if (!["AVAILABILITY_ANOMALY", "OPERATIONAL_FAULT"].includes(category)) {
        return;
      }

      const nodeId = assessment.nodeId;
      const serviceId = assessment.serviceId;
      await sendAdminNotification({
        nodeId,
        notification: {
          title: `Threat monitoring: ${category.replaceAll("_", " ")}`,
          body: `Review the assessment for ${serviceId || nodeId}.`,
        },
        messageData: {
          type: "threat_alert",
          assessmentId: snapshot.id,
        },
      });
    },
);
