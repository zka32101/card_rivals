import * as functions from 'firebase-functions/v1';
import {getFirestore, Timestamp, Transaction, QueryDocumentSnapshot} from 'firebase-admin/firestore';

const db = getFirestore();

// ============================================================
// Cloud Functions for Friend Management
// ============================================================

/**
 * Send friend request with validation
 * - Prevents duplicate requests
 * - Prevents requesting existing friends
 * - Validates user exists
 */
export const sendFriendRequest = functions.https.onCall(
  async (
    data: {
      senderId: string;
      recipientId: string;
      message?: string;
    },
    context
  ) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    if (context.auth.uid !== data.senderId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Cannot send request on behalf of another user'
      );
    }

    const { senderId, recipientId, message } = data;

    // Prevent self-friending
    if (senderId === recipientId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Cannot send friend request to yourself'
      );
    }

    try {
      return await db.runTransaction(async (transaction: Transaction) => {
        // Check if recipient exists
        const recipientDoc = await transaction.get(
          db.collection('users').doc(recipientId)
        );
        if (!recipientDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Recipient not found');
        }

        const recipientData = recipientDoc.data();
        if (!recipientData) {
          throw new functions.https.HttpsError('not-found', 'Recipient data not found');
        }

        // Get sender info
        const senderDoc = await transaction.get(
          db.collection('users').doc(senderId)
        );
        if (!senderDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Sender not found');
        }

        const senderData = senderDoc.data();
        if (!senderData) {
          throw new functions.https.HttpsError('not-found', 'Sender data not found');
        }

        // Check if already friends
        const friendDoc = await transaction.get(
          db.collection('users').doc(recipientId).collection('friends').doc(senderId)
        );
        if (friendDoc.exists) {
          throw new functions.https.HttpsError(
            'already-exists',
            'Already friends with this user'
          );
        }

        // Check for existing pending request
        const existingRequest = await transaction.get(
          db
            .collection('users')
            .doc(recipientId)
            .collection('friendRequests')
            .where('senderId', '==', senderId)
            .where('expiresAt', '>', Timestamp.now())
        );

        if (!existingRequest.empty) {
          throw new functions.https.HttpsError(
            'already-exists',
            'Friend request already sent'
          );
        }

        // Create friend request
        const now = Timestamp.now();
        const expiresAt = new Date(now.toDate());
        expiresAt.setDate(expiresAt.getDate() + 30);

        const requestId = db.collection('temp').doc().id;
        const requestRef = db
          .collection('users')
          .doc(recipientId)
          .collection('friendRequests')
          .doc(requestId);

        const requestData = {
          id: requestId,
          senderId,
          senderName: senderData.displayName || 'Unknown',
          senderRating: senderData.rating || 1000,
          recipientId,
          sentAt: now,
          message: message || null,
          viewedAt: false,
          expiresAt: Timestamp.fromDate(expiresAt),
        };

        transaction.set(requestRef, requestData);

        return {
          success: true,
          requestId,
          message: 'Friend request sent successfully',
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error('Error sending friend request:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send friend request');
    }
  }
);

/**
 * Accept friend request and establish mutual friendship
 */
export const acceptFriendRequest = functions.https.onCall(
  async (
    data: {
      requestId: string;
      userId: string;
      friendId: string;
    },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Cannot accept request for another user'
      );
    }

    const { requestId, userId, friendId } = data;

    try {
      return await db.runTransaction(async (transaction: Transaction) => {
        // Verify the friend request exists and is valid
        const requestRef = db
          .collection('users')
          .doc(userId)
          .collection('friendRequests')
          .doc(requestId);
        const requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Friend request not found');
        }

        const request = requestDoc.data();
        if (!request || request.expiresAt.toDate() < new Date()) {
          throw new functions.https.HttpsError('invalid-argument', 'Request has expired');
        }

        // Get both users' public data
        const userDoc = await transaction.get(db.collection('users').doc(userId));
        const friendDoc = await transaction.get(db.collection('users').doc(friendId));

        if (!userDoc.exists || !friendDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'User data not found');
        }

        const userData = userDoc.data();
        const friendData = friendDoc.data();

        if (!userData || !friendData) {
          throw new functions.https.HttpsError('not-found', 'User data is missing');
        }

        const now = Timestamp.now();

        // Add friend to user's friends list
        transaction.set(
          db.collection('users').doc(userId).collection('friends').doc(friendId),
          {
            friendId,
            friendName: friendData.displayName || 'Unknown',
            friendRating: friendData.rating || 1000,
            friendTier: friendData.tier || 1,
            addedAt: now,
            lastSeenAt: null,
            group: null,
            notificationsEnabled: true,
            customAlias: null,
            friendBattleCount: 0,
            friendWinRate: 0.0,
          }
        );

        // Add user to friend's friends list (reciprocal)
        transaction.set(
          db.collection('users').doc(friendId).collection('friends').doc(userId),
          {
            friendId: userId,
            friendName: userData.displayName || 'Unknown',
            friendRating: userData.rating || 1000,
            friendTier: userData.tier || 1,
            addedAt: now,
            lastSeenAt: null,
            group: null,
            notificationsEnabled: true,
            customAlias: null,
            friendBattleCount: 0,
            friendWinRate: 0.0,
          }
        );

        // Delete the friend request
        transaction.delete(requestRef);

        return {
          success: true,
          message: 'Friend request accepted',
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error('Error accepting friend request:', error);
      throw new functions.https.HttpsError('internal', 'Failed to accept request');
    }
  }
);

/**
 * Reject/decline a friend request
 */
export const rejectFriendRequest = functions.https.onCall(
  async (
    data: {
      requestId: string;
      userId: string;
    },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Cannot reject request for another user'
      );
    }

    const { requestId, userId } = data;

    try {
      const requestRef = db
        .collection('users')
        .doc(userId)
        .collection('friendRequests')
        .doc(requestId);

      await requestRef.delete();

      return {
        success: true,
        message: 'Friend request rejected',
      };
    } catch (error) {
      console.error('Error rejecting friend request:', error);
      throw new functions.https.HttpsError('internal', 'Failed to reject request');
    }
  }
);

/**
 * Remove a friend (mutual removal)
 */
export const removeFriend = functions.https.onCall(
  async (
    data: {
      userId: string;
      friendId: string;
    },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Cannot remove friend for another user'
      );
    }

    const { userId, friendId } = data;

    try {
      return await db.runTransaction(async (transaction: Transaction) => {
        // Verify friendship exists
        const friendshipDoc = await transaction.get(
          db.collection('users').doc(userId).collection('friends').doc(friendId)
        );

        if (!friendshipDoc.exists) {
          throw new functions.https.HttpsError('not-found', 'Friendship not found');
        }

        // Remove from both users' friends lists
        transaction.delete(
          db.collection('users').doc(userId).collection('friends').doc(friendId)
        );

        transaction.delete(
          db.collection('users').doc(friendId).collection('friends').doc(userId)
        );

        return {
          success: true,
          message: 'Friend removed',
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error('Error removing friend:', error);
      throw new functions.https.HttpsError('internal', 'Failed to remove friend');
    }
  }
);

/**
 * Update friend metadata (alias, group, notifications)
 */
export const updateFriendMetadata = functions.https.onCall(
  async (
    data: {
      userId: string;
      friendId: string;
      customAlias?: string;
      group?: string;
      notificationsEnabled?: boolean;
    },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Cannot update friend for another user'
      );
    }

    const { userId, friendId, customAlias, group, notificationsEnabled } = data;

    try {
      const updateData: any = {};

      if (customAlias !== undefined) updateData.customAlias = customAlias;
      if (group !== undefined) updateData.group = group;
      if (notificationsEnabled !== undefined) {
        updateData.notificationsEnabled = notificationsEnabled;
      }

      await db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .doc(friendId)
        .update(updateData);

      return {
        success: true,
        message: 'Friend metadata updated',
      };
    } catch (error) {
      console.error('Error updating friend metadata:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to update friend metadata'
      );
    }
  }
);

/**
 * Batch update friend profiles when user stats change
 * Called after rating/tier updates to sync cached data
 */
export const updateFriendCachedData = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const oldData = change.before.data();
    const newData = change.after.data();

    // Check if rating or tier changed
    if (
      oldData?.rating === newData?.rating &&
      oldData?.tier === newData?.tier &&
      oldData?.displayName === newData?.displayName
    ) {
      return; // No relevant changes
    }

    try {
      // Get all users who have this user as a friend
      const reverseQuery = await db
        .collectionGroup('friends')
        .where('friendId', '==', userId)
        .get();

      const batch = db.batch();

      reverseQuery.docs.forEach((doc: QueryDocumentSnapshot) => {
        // doc.ref is: users/{otherUserId}/friends/{userId}
        const friendRef = doc.ref;

        batch.update(friendRef, {
          friendRating: newData?.rating || 1000,
          friendTier: newData?.tier || 1,
          friendName: newData?.displayName || 'Unknown',
        });
      });

      if (reverseQuery.docs.length > 0) {
        await batch.commit();
        console.log(`Updated friend caches for ${userId} (${reverseQuery.docs.length} friends)`);
      }
    } catch (error) {
      console.error('Error updating friend cached data:', error);
      // Don't throw - this is a best-effort update
    }
  });
