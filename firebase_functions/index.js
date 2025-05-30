const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
admin.initializeApp();

// Validate parking data
function validateParkingData(data) {
    if (!data || typeof data.total !== 'number' || 
        !data.slot_1 || !data.slot_2 || !data.slot_3) {
        throw new Error('Invalid parking data format');
    }
    return true;
}

// Parking notification function
exports.parkingNotification = functions.database.ref('/parking')
    .onUpdate(async (change, context) => {
        try {
            const after = change.after.val();
            const before = change.before.val();
            
            // Validate data
            validateParkingData(after);
            
            // Only send notification if total changes
            if (after.total !== before.total) {
                const availableSpots = 3 - after.total;
                
                const payload = {
                    notification: {
                        title: 'Parking Update',
                        body: `Available parking spots: ${availableSpots}`,
                        clickAction: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    data: {
                        slot1: after.slot_1,
                        slot2: after.slot_2,
                        slot3: after.slot_3,
                        total: after.total.toString(),
                        timestamp: Date.now().toString()
                    }
                };

                await admin.messaging().sendToTopic('parking_updates', payload);
                console.log('[SUCCESS] Parking notification sent:', payload);
                return {success: true};
            }
            
            return {success: true, message: 'No notification needed'};
        } catch (error) {
            console.error('[ERROR] Parking notification failed:', error);
            return {error: error.message};
        }
    });

exports.sendNotification = functions.firestore
    .document('messages/{messageId}')
    .onCreate((snap, context) => {
        const message = snap.data();
        
        const payload = {
            notification: {
                title: 'New Message',
                body: message.text,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };

        return admin.messaging().sendToTopic('all_users', payload);
    });

exports.detectCars = functions.https.onRequest(async (req, res) => {
    try {
        const youtubeUrl = req.body.youtube_url;
        if (!youtubeUrl) {
            return res.status(400).send({ error: 'youtube_url parameter is required' });
        }

        const response = await axios.post('https://car-detection-service-808791551084.europe-west1.run.app/detect-cars', { youtube_url: youtubeUrl });
        return res.status(200).send(response.data);
    } catch (error) {
        return res.status(500).send({ error: error.message });
    }
});