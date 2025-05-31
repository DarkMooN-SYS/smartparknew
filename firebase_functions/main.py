from firebase_functions import scheduler_fn, firestore_fn
from firebase_admin import initialize_app, firestore, messaging
from datetime import datetime, timedelta, timezone

initialize_app()

@scheduler_fn.on_schedule(schedule="0 13 * * *")  # Run at 13:00 UTC daily
def send_parking_reminder():
    # Calculate the time for parking start (1 hour from now)
    parking_start_time = datetime.utcnow() + timedelta(hours=1)
    
    payload = messaging.Message(
        notification=messaging.Notification(
            title="Parking Reminder",
            body=f"Your parking starts in 1 hour at {parking_start_time.strftime('%H:%M')}."
        ),
        topic="parking_reminders",
    )

    try:
        response = messaging.send(payload)
        print(f"Successfully sent message: {response}")
    except Exception as e:
        print(f"Error sending message: {e}")

@scheduler_fn.on_schedule(schedule="*/5 * * * *")
def check_and_send_notifications(event: scheduler_fn.ScheduledEvent) -> None:
    print("Function started")
    db = firestore.client()
    now = datetime.now(timezone.utc)  # Use timezone-aware UTC time
    
    print(f"Checking for notifications at {now}")

    # Query for unsent notifications
    docs = db.collection('bookings').where('sent', '==', False).stream()

    for doc in docs:
        print(f"Processing document: {doc.id}")
        data = doc.to_dict()
        fcm_token = data.get('fcmToken')
        parking_time = data['time']
        address = data["address"]
        parkingSlot = 'Zone : ' + data["zone"] + ', Level : ' + data["level"] + ', Row : ' + data["row"]
        notification_time = data['notificationTime'].astimezone(timezone.utc)
        parking_time_date = notification_time + timedelta(hours=2)

        print(f"Notification time: {notification_time}, Current time: {now}")
        
        if notification_time <= now:
            print(f"Sending notification for parking at {parking_time}")

            if fcm_token:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="Parking Reminder",
                        body=f"Your parking starts at {parking_time}."
                    ),
                    token=fcm_token,
                )

                try:
                    response = messaging.send(message)
                    print(f"Successfully sent message: {response}")
                    doc.reference.update({'sent': True})

                    # Add the notification in DB here:
                    notification_id = add_notification(
                        db,
                        address,
                        fcm_token,
                        notification_time,
                        parking_time,
                        True,
                        parking_time_date,
                        data.get('userId', '')
                    )
                    if notification_id:
                        print(f"Notification added to database with ID: {notification_id}")
                    else:
                        print("Failed to add notification to database")

                except Exception as e:
                    print(f"Error sending message: {e}")
            else:
                print(f"No FCM token found for document {doc.id}")

    print("Function completed")

def add_notification(db, address, fcm_token, notification_time, parking_time, sent, user_id, parkingSlot):
    notifications_ref = db.collection('notifications')
    new_notification = {
        'address': address,
        'fcmToken': fcm_token,
        'notificationTime': notification_time,
        'parkingTime': parking_time,
        'sent': sent,
        'userId': user_id,
        'type': 'Reminder',
        'parkingSlot': parkingSlot
    }
    
    try:
        doc_ref = notifications_ref.add(new_notification)
        print(f"Notification added with ID: {doc_ref[1].id}")
        return doc_ref[1].id
    except Exception as e:
        print(f"Error adding notification: {e}")
        return None

@firestore_fn.on_document_created(document="notifications/{notificationId}")
def log_notification_created(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    print(f"Notification created: {event.params['notificationId']}")

@firestore_fn.on_document_created(document="arduino_data/{dataId}")
def process_arduino_data(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    try:
        data = event.data.to_dict()
        if not data:
            print("[ERROR] No data found in arduino_data document")
            return
            
        # Get sensor status
        s1 = int(data.get('s1', 0))
        s2 = int(data.get('s2', 0))
        s3 = int(data.get('s3', 0))
        total_occupied = s1 + s2 + s3
        
        # Update all parking documents
        db = firestore.client()
        parking_docs = db.collection('parkings').stream()
        
        for doc in parking_docs:
            try:
                parking_data = doc.to_dict()
                if not parking_data or 'slots_available' not in parking_data:
                    continue
                
                slots_data = parking_data['slots_available']
                total_slots = int(slots_data.split('/')[1])
                available = total_slots - total_occupied
                
                # Update parking document
                updates = {
                    'slots_available': f"{available}/{total_slots}",
                    'last_updated': firestore.SERVER_TIMESTAMP,
                    'arduino_status': {
                        'slot_1': 'Full' if s1 else 'Empty',
                        'slot_2': 'Full' if s2 else 'Empty',
                        'slot_3': 'Full' if s3 else 'Empty',
                    }
                }
                doc.reference.update(updates)
                
                # Send notification if status changed
                if available > 0:
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title="Parking Update",
                            body=f"Available spots: {available}. Slots: 1-{'Full' if s1 else 'Empty'}, 2-{'Full' if s2 else 'Empty'}, 3-{'Full' if s3 else 'Empty'}"
                        ),
                        topic="parking_updates"
                    )
                    messaging.send(message)
                
            except Exception as e:
                print(f"[ERROR] Failed to update parking {doc.id}: {e}")
                continue
                
    except Exception as e:
        print(f"[ERROR] Processing arduino data failed: {e}")