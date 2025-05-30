import logging
from typing import Optional, Dict, Any, Union
from firebase_functions import scheduler_fn, firestore_fn
from firebase_admin import initialize_app, firestore, messaging
from datetime import datetime, timedelta, timezone
from firebase_functions.scheduler_fn import ScheduledEvent
from firebase_functions.firestore_fn import Event, DocumentSnapshot

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
initialize_app()


@scheduler_fn.on_schedule(schedule="0 13 * * *")  # Run at 13:00 UTC daily
def send_parking_reminder(event: ScheduledEvent) -> None:
    # Calculate the time for parking start (1 hour from now)
    parking_start_time = datetime.utcnow() + timedelta(hours=1)

    payload = messaging.Message(
        notification=messaging.Notification(
            title="Parking Reminder",
            body=f"Your parking starts in 1 hour at {parking_start_time.strftime('%H:%M')}.",
        ),
        topic="parking_reminders",
    )

    try:
        response = messaging.send(payload)
        print(f"Successfully sent message: {response}")
    except Exception as e:
        print(f"Error sending message: {e}")


def add_notification(
    db: firestore.Client,
    address: str,
    fcm_token: str,
    notification_time: datetime,
    parking_time: str,
    sent: bool,
    parking_slot: str,
    user_id: str,
) -> Optional[str]:
    try:
        notifications_ref = db.collection("notifications")
        # Generate a new document ID
        new_doc_ref = notifications_ref.document()

        new_notification = {
            "address": address,
            "fcmToken": fcm_token,
            "notificationTime": notification_time,
            "parkingTime": parking_time,
            "sent": sent,
            "userId": user_id,
            "type": "Reminder",
            "parkingSlot": parking_slot,
            "createdAt": datetime.now(timezone.utc),
        }

        # Set document data
        new_doc_ref.set(new_notification)
        print(f"[SUCCESS] Notification added with ID: {new_doc_ref.id}")
        return new_doc_ref.id
    except Exception as e:
        print(f"[ERROR] Adding notification failed: {e}")
        return None


@scheduler_fn.on_schedule(schedule="*/5 * * * *")
def check_and_send_notifications(event: scheduler_fn.ScheduledEvent) -> None:
    try:
        print("[INFO] Function started")
        db = firestore.client()
        now = datetime.now(timezone.utc)

        # Query for unsent notifications
        docs = db.collection("bookings").where("sent", "==", False).stream()

        for doc in docs:
            data = doc.to_dict()
            try:
                fcm_token = data.get("fcmToken")
                if not fcm_token:
                    print(f"[WARN] No FCM token for document {doc.id}")
                    continue

                notification_time = data["notificationTime"].astimezone(timezone.utc)
                if notification_time > now:
                    continue

                parking_slot = (
                    f"Zone: {data['zone']}, Level: {data['level']}, Row: {data['row']}"
                )

                # Send notification
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="Parking Reminder",
                        body=f"Your parking starts at {data['time']}.",
                    ),
                    token=fcm_token,
                )

                response = messaging.send(message)
                print(f"[SUCCESS] Message sent: {response}")

                # Update booking status
                doc.reference.update({"sent": True})

                # Add notification record
                notification_id = add_notification(
                    db=db,
                    address=data["address"],
                    fcm_token=fcm_token,
                    notification_time=notification_time,
                    parking_time=data["time"],
                    sent=True,
                    parking_slot=parking_slot,
                    user_id=data.get("userId", ""),
                )

            except Exception as e:
                print(f"[ERROR] Processing document {doc.id} failed: {e}")
                continue

    except Exception as e:
        print(f"[ERROR] Main function failed: {e}")


@firestore_fn.on_document_created(document="notifications/{notificationId}")
def log_notification_created(event: Event[Union[DocumentSnapshot, None]]) -> None:
    print(f"Notification created: {event.params['notificationId']}")


def update_parking_status(s1: bool, s2: bool, s3: bool) -> None:
    try:
        db = firestore.client()
        ref = db.collection("parking").document("status")
        
        # Get previous state
        prev_state = ref.get().to_dict() or {}
        
        # New state
        new_state = {
            "slot_1": "Full" if s1 else "Empty",
            "slot_2": "Full" if s2 else "Empty",
            "slot_3": "Full" if s3 else "Empty",
            "total": sum([s1, s2, s3]),
            "updatedAt": datetime.now(timezone.utc)
        }
        
        # Update database
        ref.set(new_state)

        # Send notification to all users subscribed to parking updates
        if prev_state.get("total") != new_state["total"]:
            message = messaging.Message(
                notification=messaging.Notification(
                    title="Parking Status Update",
                    body=f"Available spots: {3 - new_state['total']}. Slots: 1-{'Full' if s1 else 'Empty'}, 2-{'Full' if s2 else 'Empty'}, 3-{'Full' if s3 else 'Empty'}",
                ),
                topic="parking_updates"
            )
            messaging.send(message)
            logger.info("[SUCCESS] Broadcast notification sent")

        logger.info(f"[SUCCESS] Parking status updated: {new_state}")
        
    except Exception as e:
        logger.error(f"[ERROR] Failed to update parking status: {e}")


@firestore_fn.on_document_created(document="arduino_data/{dataId}")
def process_arduino_data(event: Event[Union[DocumentSnapshot, None]]) -> None:
    try:
        if not event.data:
            return

        data = event.data.to_dict()
        if not data:
            return
            
        # Parse Arduino data with RFID/QR
        s1 = bool(int(data.get("s1", 0)))
        s2 = bool(int(data.get("s2", 0)))
        s3 = bool(int(data.get("s3", 0)))
        user_id = data.get("user_id", "") # From RFID/QR
        slot_id = data.get("slot_id", "") # Which slot triggered
        
        if user_id and slot_id:
            # Create or update parking session
            handle_parking_session(user_id, slot_id, is_occupied=True if slot_id=="slot_1" and s1 else False)
            
        # Update overall status
        update_parking_status(s1, s2, s3)

    except Exception as e:
        logger.error(f"[ERROR] Failed to process Arduino data: {e}")

def handle_parking_session(user_id: str, slot_id: str, is_occupied: bool) -> None:
    try:
        db = firestore.client()
        
        # Find active session
        session = db.collection("parking_sessions")\
            .where("user_id", "==", user_id)\
            .where("slot_id", "==", slot_id)\
            .where("is_active", "==", True)\
            .limit(1)\
            .stream()
            
        session_data = next(session, None)
        
        if is_occupied and not session_data:
            # Start new session
            db.collection("parking_sessions").add({
                "user_id": user_id,
                "slot_id": slot_id,
                "start_time": datetime.now(timezone.utc),
                "is_active": True
            })
            
        elif not is_occupied and session_data:
            # End session
            session_data.reference.update({
                "is_active": False,
                "end_time": datetime.now(timezone.utc)
            })
            
    except Exception as e:
        logger.error(f"[ERROR] Failed to handle parking session: {e}")
