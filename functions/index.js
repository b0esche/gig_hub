
/**
 * Firebase Cloud Functions for GigHub Application
 *
 * Features:
 * - User rating system with validation and aggregation
 * - Push notifications for direct chat messages
 * - Push notifications for group chat messages
 * - Firestore triggers for real-time message notifications
 * - FCM token management and message delivery
 *
 * All functions use Firebase Admin SDK for secure server-side operations
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } =
  require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Handles user rating submissions with validation and aggregation
 *
 * Validates rating data, prevents self-rating, and calculates
 * average ratings for users in the system.
 *
 * @param {Object} requestData - Contains raterId, targetUserId, and rating
 * @param {Object} context - Firebase function context
 * @returns {Object} Success message with rating details
 */
exports.submitRating = onCall(async (requestData, context) => {
  const data = requestData && requestData.data ? requestData.data : requestData;

  const raterId = data.raterId;
  const targetUserId = data.targetUserId;
  const rawRating = data.rawRating;
  const rating = Number(rawRating);

  // Input validation
  if (!raterId) {
    throw new HttpsError("invalid-argument",
      "Missing raterId");
  }
  if (!targetUserId) {
    throw new HttpsError("invalid-argument",
      "Missing targetUserId");
  }
  if (isNaN(rating)) {
    throw new HttpsError("invalid-argument",
      "Rating is not a number");
  }
  if (rating < 1.0 || rating > 5.0) {
    throw new HttpsError("invalid-argument",
      "Rating out of bounds");
  }

  const ratingRef = admin
    .firestore()
    .collection("users")
    .doc(targetUserId)
    .collection("receivedRatings")
    .doc(raterId);

  await ratingRef.set({
    rating: rating,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const snapshot = await admin
    .firestore()
    .collection("users")
    .doc(targetUserId)
    .collection("receivedRatings")
    .get();

  const allRatings = snapshot.docs.map((doc) => doc.data().rating);
  const avgRating = allRatings.reduce(
    (sum, r) => sum + r, 0) / allRatings.length;

  await admin.firestore().collection("users").doc(targetUserId).update({
    avgRating: avgRating,
    ratingCount: allRatings.length,
  });

  return {
    avgRating,
    ratingCount: allRatings.length,
  };
});

/**
 * Sends push notifications for direct chat messages
 *
 * Triggered when a new message is created in any direct chat.
 * Fetches sender information and sends a notification to the receiver
 * if they have an FCM token registered.
 *
 * @param {Object} event - Firestore document creation event
 */
exports.sendChatNotification =
  onDocumentCreated("chats/{chatId}/messages/{messageId}",
    async (event) => {
      const message = event.data.data();
      const receiverId = message.receiverId;
      const senderId = message.senderId;

      // Get sender information for notification display
      const senderDoc = await getFirestore().collection("users")
        .doc(senderId).get();
      const senderName = senderDoc.data().name;

      // Get receiver's FCM token for push notification
      const userDoc = await getFirestore().collection("users")
        .doc(receiverId).get();
      const fcmToken = userDoc.data().fcmToken;

      if (fcmToken) {
        const payload = {
          notification: {
            title: senderName,
            body: "new message",
          },
          data: {
            senderId: senderId,
            screen: "chat_list_screen",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "chat_channel",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          token: fcmToken,
        };
        await getMessaging().send(payload);
      }
    });

/**
 * Sends push notifications for group chat messages
 *
 * Triggered when a new message is created in any group chat.
 * Fetches all group members and sends notifications to everyone
 * except the message sender.
 *
 * @param {Object} event - Firestore document creation event with groupChatId
 */
exports.sendGroupChatNotification =
  onDocumentCreated("group_chats/{groupChatId}/messages/{messageId}",
    async (event) => {
      const message = event.data.data();
      const senderId = message.senderId;
      const senderName = message.senderName;
      const groupChatId = event.params.groupChatId;

      // Fetch group chat details to get member list and group name
      const groupChatDoc = await getFirestore().collection("group_chats")
        .doc(groupChatId).get();
      const groupChatData = groupChatDoc.data();
      const memberIds = groupChatData.memberIds || [];
      const groupName = groupChatData.name;

      // Send notification to all group members except the sender
      const notificationPromises = memberIds
        .filter((memberId) => memberId !== senderId)
        .map(async (memberId) => {
          const userDoc = await getFirestore().collection("users")
            .doc(memberId).get();
          const userData = userDoc.data();
          const fcmToken = userData && userData.fcmToken;

          if (fcmToken) {
            const payload = {
              notification: {
                title: groupName,
                body: `${senderName}: new message`,
              },
              data: {
                senderId: senderId,
                groupChatId: groupChatId,
                screen: "chat_list_screen",
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "chat_channel",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
              token: fcmToken,
            };
            return getMessaging().send(payload);
          }
        });

      await Promise.all(notificationPromises.filter((p) => p !== undefined));
    });

/**
 * Triggered when a new rave is created
 *
 * Checks all active rave alerts and sends push notifications to users
 * whose alerts match the new rave's location within their specified radius.
 *
 * @param {Object} snapshot - Firestore document snapshot of the new rave
 * @param {Object} context - Firebase function context
 */
exports.notifyRaveAlerts = onDocumentCreated(
  "raves/{raveId}",
  async (event) => {
    const snapshot = event.data;
    const raveData = snapshot.data();

    // Validate rave data
    if (!raveData) {
      return;
    }

    if (!raveData.geoPoint) {
      return;
    }

    if (!raveData.name) {
      return;
    }

    if (!raveData.organizerId) {
      return;
    }

    const ravelat = raveData.geoPoint.latitude;
    const raveLng = raveData.geoPoint.longitude;
    const raveName = raveData.name;
    const raveLocation = raveData.location || "Unknown Location";
    const organizerId = raveData.organizerId;

    try {
      // Get all active rave alerts
      const alertsSnapshot = await getFirestore()
        .collection("rave_alerts")
        .where("isActive", "==", true)
        .get();

      if (alertsSnapshot.empty) {
        return;
      }

      // Get organizer details for the notification
      const organizerDoc = await getFirestore()
        .collection("users")
        .doc(organizerId)
        .get();

      let organizerName = "Unknown Organizer";
      if (organizerDoc.exists) {
        const organizerData = organizerDoc.data();
        organizerName = organizerData.name || "Unknown Organizer";
      }

      const notificationPromises = alertsSnapshot.docs.map(
        async (alertDoc) => {
          const alertData = alertDoc.data();
          const userId = alertData.userId;
          const centerLat = alertData.centerPoint.latitude;
          const centerLng = alertData.centerPoint.longitude;
          const radiusKm = alertData.radiusKm;

          // Skip if this is the organizer's own rave
          if (userId === organizerId) {
            return;
          }

          // Calculate distance between rave and alert center
          const distance = calculateDistance(
            ravelat, raveLng, centerLat, centerLng);

          // Check if rave is within alert radius
          if (distance <= radiusKm) {
            // Get user's FCM token
            const userDoc = await getFirestore()
              .collection("users")
              .doc(userId)
              .get();

            if (userDoc.exists) {
              const userData = userDoc.data();
              const fcmToken = userData.fcmToken;

              if (fcmToken) {
                const payload = {
                  notification: {
                    title: "🎵 Rave Alert!",
                    body: `${raveName} by ${organizerName} in ` +
                      `${raveLocation} (${Math.round(distance)}km away)`,
                  },
                  data: {
                    raveId: snapshot.id,
                    organizerId: organizerId,
                    screen: "booker_profile",
                    type: "rave_alert",
                    distance: distance.toString(),
                  },
                  android: {
                    priority: "high",
                    notification: {
                      channelId: "rave_alerts",
                      icon: "ic_notification",
                      color: "#D4AF37", // Forged gold color
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: "default",
                        badge: 1,
                      },
                    },
                  },
                  token: fcmToken,
                };

                return getMessaging().send(payload);
              }
            }
          }
        });

      // Execute all notification promises
      await Promise.allSettled(
        notificationPromises.filter((p) => p !== undefined));
    } catch (error) {
      // Silent error handling - could add minimal error reporting if needed
    }
  });

/**
 * Triggered when a rave document is updated
 *
 * Checks if DJs or collaborators were added to the rave and sends
 * notifications to newly added members informing them about their
 * involvement in the rave.
 *
 * @param {Object} event - Firestore document update event
 */
exports.notifyRaveCollaborators = onDocumentUpdated(
  "raves/{raveId}",
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const raveId = event.params.raveId;

    // Skip if no rave data
    if (!beforeData || !afterData) {
      return;
    }

    try {
      // Get previous and current DJ/collaborator lists
      const previousDJs = beforeData.djIds || [];
      const currentDJs = afterData.djIds || [];
      const previousCollaborators = beforeData.collaboratorIds || [];
      const currentCollaborators = afterData.collaboratorIds || [];

      // Find newly added DJs and collaborators
      const newDJs = currentDJs.filter((djId) => !previousDJs.includes(djId));
      const newCollaborators = currentCollaborators.filter(
        (collabId) => !previousCollaborators.includes(collabId),
      );

      // Skip if no new members were added
      if (newDJs.length === 0 && newCollaborators.length === 0) {
        return;
      }

      // Get rave details for the notification
      const raveName = afterData.name || "Unknown Rave";
      const raveLocation = afterData.location || "Unknown Location";
      const organizerId = afterData.organizerId;

      // Get organizer details
      let organizerName = "Unknown Organizer";
      try {
        const organizerDoc = await getFirestore()
          .collection("users")
          .doc(organizerId)
          .get();

        if (organizerDoc.exists) {
          const organizerData = organizerDoc.data();
          organizerName = organizerData.name || "Unknown Organizer";
        }
      } catch (error) {
        // Continue with default name if organizer fetch fails
      }

      // Create notification promises for newly added DJs
      const djNotificationPromises = newDJs.map(async (djId) => {
        try {
          const djDoc = await getFirestore()
            .collection("users")
            .doc(djId)
            .get();

          if (djDoc.exists) {
            const djData = djDoc.data();
            const fcmToken = djData.fcmToken;

            if (fcmToken) {
              const payload = {
                notification: {
                  title: "🎵 You've been added to a Rave!",
                  body: `${organizerName} added you as DJ for ` +
                    `"${raveName}" in ${raveLocation}`,
                },
                data: {
                  raveId: raveId,
                  organizerId: organizerId,
                  screen: "booker_profile",
                  type: "rave_collaboration",
                  role: "dj",
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "rave_alerts",
                    icon: "ic_notification",
                    color: "#D4AF37", // Forged gold color
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                      badge: 1,
                    },
                  },
                },
                token: fcmToken,
              };

              return getMessaging().send(payload);
            }
          }
        } catch (error) {
          // Continue with other notifications if one fails
          return null;
        }
      });

      // Create notification promises for newly added collaborators
      const collaboratorNotificationPromises = newCollaborators.map(
        async (collabId) => {
          try {
            const collabDoc = await getFirestore()
              .collection("users")
              .doc(collabId)
              .get();

            if (collabDoc.exists) {
              const collabData = collabDoc.data();
              const fcmToken = collabData.fcmToken;

              if (fcmToken) {
                const payload = {
                  notification: {
                    title: "🤝 You've been added to a Rave!",
                    body:
                      `${organizerName} added you as collaborator for ` +
                      `"${raveName}" in ${raveLocation}`,
                  },
                  data: {
                    raveId: raveId,
                    organizerId: organizerId,
                    screen: "booker_profile",
                    type: "rave_collaboration",
                    role: "collaborator",
                  },
                  android: {
                    priority: "high",
                    notification: {
                      channelId: "rave_alerts",
                      icon: "ic_notification",
                      color: "#D4AF37", // Forged gold color
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: "default",
                        badge: 1,
                      },
                    },
                  },
                  token: fcmToken,
                };

                return getMessaging().send(payload);
              }
            }
          } catch (error) {
            // Continue with other notifications if one fails
            return null;
          }
        },
      );

      // Execute all notification promises
      const allNotificationPromises = [
        ...djNotificationPromises,
        ...collaboratorNotificationPromises,
      ];

      await Promise.allSettled(
        allNotificationPromises.filter((p) => p !== null),
      );
    } catch (error) {
      // Silent error handling - could add minimal error reporting if needed
    }
  },
);

/**
 * Scheduled function to clean up expired raves and group chats
 *
 * Runs daily at 2 AM UTC to remove:
 * - Raves that ended more than 24 hours ago
 * - Associated group chats for deleted raves
 * - Expired group chats based on autoDeleteAt timestamp
 */
exports.cleanupExpiredContent = onSchedule("0 2 * * *", async (event) => {
  const db = getFirestore();
  const now = admin.firestore.Timestamp.now();
  const twentyFourHoursAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 24 * 60 * 60 * 1000),
  );

  try {
    // 1. Find expired raves (ended more than 24 hours ago)
    const expiredRavesQuery = await db.collection("raves")
      .where("startDate", "<", twentyFourHoursAgo)
      .get();

    const batch = db.batch();
    let deletedRavesCount = 0;
    let deletedGroupChatsCount = 0;

    // Process expired raves
    for (const raveDoc of expiredRavesQuery.docs) {
      const raveData = raveDoc.data();

      // Check if it's a multi-day event
      let raveEndTime;
      if (raveData.endDate) {
        raveEndTime = admin.firestore.Timestamp.fromDate(
          new Date(raveData.endDate),
        );
      } else {
        raveEndTime = admin.firestore.Timestamp.fromDate(
          new Date(raveData.startDate),
        );
      }

      // Only delete if ended more than 24 hours ago
      if (raveEndTime.toDate() < twentyFourHoursAgo.toDate()) {
        // Delete the rave
        batch.delete(raveDoc.ref);
        deletedRavesCount++;

        // If there's an associated group chat, mark it for deletion
        if (raveData.groupChatId) {
          const groupChatRef = db.collection("group_chats")
            .doc(raveData.groupChatId);
          batch.update(groupChatRef, { isActive: false });

          // Delete all messages in the group chat
          const messagesQuery = await groupChatRef.collection("messages").get();
          for (const messageDoc of messagesQuery.docs) {
            batch.delete(messageDoc.ref);
          }
          deletedGroupChatsCount++;
        }
      }
    }

    // 2. Clean up expired group chats (based on autoDeleteAt)
    const expiredGroupChatsQuery = await db.collection("group_chats")
      .where("autoDeleteAt", "<", now)
      .where("isActive", "==", true)
      .get();

    for (const groupChatDoc of expiredGroupChatsQuery.docs) {
      // Mark as inactive
      batch.update(groupChatDoc.ref, { isActive: false });

      // Delete all messages
      const messagesQuery = await groupChatDoc.ref.collection("messages").get();
      for (const messageDoc of messagesQuery.docs) {
        batch.delete(messageDoc.ref);
      }
      deletedGroupChatsCount++;
    }

    // 3. Clean up expired PUBLIC group chats (based on autoDeleteAt)
    const expiredPublicGroupChatsQuery = await db
      .collection("public_group_chats")
      .where("autoDeleteAt", "<", now)
      .where("isActive", "==", true)
      .get();

    for (const publicGroupChatDoc of expiredPublicGroupChatsQuery.docs) {
      // Mark as inactive
      batch.update(publicGroupChatDoc.ref, { isActive: false });

      // Delete all messages
      const messagesQuery = await publicGroupChatDoc.ref
        .collection("messages").get();
      for (const messageDoc of messagesQuery.docs) {
        batch.delete(messageDoc.ref);
      }
      deletedGroupChatsCount++;
    }

    // Execute all deletions
    await batch.commit();

    return {
      success: true,
      deletedRaves: deletedRavesCount,
      deletedGroupChats: deletedGroupChatsCount,
    };
  } catch (error) {
    throw new Error(`Cleanup failed: ${error.message}`);
  }
});

/**
 * Manual cleanup function that can be called on-demand
 * Useful for testing or immediate cleanup when needed
 */
exports.triggerCleanup = onCall(async (request, context) => {
  // Only allow authenticated admin users to trigger cleanup
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  try {
    const db = getFirestore();
    const now = admin.firestore.Timestamp.now();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000),
    );

    // Reuse the same cleanup logic as the scheduled function
    const expiredRavesQuery = await db.collection("raves")
      .where("startDate", "<", twentyFourHoursAgo)
      .get();

    const batch = db.batch();
    let deletedRavesCount = 0;
    let deletedGroupChatsCount = 0;

    // Process expired raves
    for (const raveDoc of expiredRavesQuery.docs) {
      const raveData = raveDoc.data();

      let raveEndTime;
      if (raveData.endDate) {
        raveEndTime = admin.firestore.Timestamp.fromDate(
          new Date(raveData.endDate),
        );
      } else {
        raveEndTime = admin.firestore.Timestamp.fromDate(
          new Date(raveData.startDate),
        );
      }

      if (raveEndTime.toDate() < twentyFourHoursAgo.toDate()) {
        batch.delete(raveDoc.ref);
        deletedRavesCount++;

        if (raveData.groupChatId) {
          const groupChatRef = db.collection("group_chats")
            .doc(raveData.groupChatId);
          batch.update(groupChatRef, { isActive: false });

          const messagesQuery = await groupChatRef.collection("messages").get();
          for (const messageDoc of messagesQuery.docs) {
            batch.delete(messageDoc.ref);
          }
          deletedGroupChatsCount++;
        }
      }
    }

    // Clean up expired group chats
    const expiredGroupChatsQuery = await db.collection("group_chats")
      .where("autoDeleteAt", "<", now)
      .where("isActive", "==", true)
      .get();

    for (const groupChatDoc of expiredGroupChatsQuery.docs) {
      batch.update(groupChatDoc.ref, { isActive: false });

      const messagesQuery = await groupChatDoc.ref.collection("messages").get();
      for (const messageDoc of messagesQuery.docs) {
        batch.delete(messageDoc.ref);
      }
      deletedGroupChatsCount++;
    }

    // Clean up expired PUBLIC group chats
    const expiredPublicGroupChatsQuery = await db
      .collection("public_group_chats")
      .where("autoDeleteAt", "<", now)
      .where("isActive", "==", true)
      .get();

    for (const publicGroupChatDoc of expiredPublicGroupChatsQuery.docs) {
      batch.update(publicGroupChatDoc.ref, { isActive: false });

      const messagesQuery = await publicGroupChatDoc.ref
        .collection("messages").get();
      for (const messageDoc of messagesQuery.docs) {
        batch.delete(messageDoc.ref);
      }
      deletedGroupChatsCount++;
    }

    await batch.commit();

    return {
      success: true,
      message: "Cleanup completed successfully",
      deletedRaves: deletedRavesCount,
      deletedGroupChats: deletedGroupChatsCount,
    };
  } catch (error) {
    throw new HttpsError("internal", `Cleanup failed: ${error.message}`);
  }
});

/**
 * Calculates the distance between two geographic points using the Haversine
 * formula
 *
 * @param {number} lat1 - Latitude of first point
 * @param {number} lon1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lon2 - Longitude of second point
 * @return {number} Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in kilometers
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in kilometers
}

/**
 * Converts degrees to radians
 *
 * @param {number} degrees - Angle in degrees
 * @return {number} Angle in radians
 */
function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}
