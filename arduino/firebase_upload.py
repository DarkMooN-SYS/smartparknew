import serial
import time
import firebase_admin
from firebase_admin import credentials, db

import traceback

# Firebase config.json замыг зааж өгнө
cred = credentials.Certificate("arduino/firebase_config.json")  # ← Замыг харьцангуй болгож өгсөн
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://parkme-246a0-default-rtdb.asia-southeast1.firebasedatabase.app/'  # ← URL-ээ Firebase-ees хуулж оруул
})

try:
    ser = serial.Serial('COM7', 9600, timeout=1)
except serial.SerialException as e:
    print("[ERROR] Could not open serial port COM7:", str(e))
    exit(1)

def upload_to_firebase(s1: int, s2: int, s3: int, user_id: str) -> bool:
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            ref = db.reference("/parking")
            data = {
                'slot_1': 'Full' if s1 else 'Empty',
                'slot_2': 'Full' if s2 else 'Empty',
                'slot_3': 'Full' if s3 else 'Empty',
                'total': s1 + s2 + s3,
                'last_updated_by': user_id,
                'timestamp': {'.sv': 'timestamp'}
            }
            ref.set(data)
            print(f"[OK] Uploaded: s1={s1}, s2={s2}, s3={s3}, user={user_id}")
            return True
        except Exception as e:
            retry_count += 1
            print(f"[ERROR] Firebase upload error (attempt {retry_count}/{max_retries}):", str(e))
            if retry_count < max_retries:
                time.sleep(2)
                continue
            return False
    return False

while True:
    try:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8').strip()
            print(f"[DATA] From Arduino: {line}")
            parts = line.split(',')
            if len(parts) == 4:  # Now expecting 4 parts including user ID
                s1, s2, s3, user_id = parts[0], parts[1], parts[2], parts[3]
                upload_to_firebase(int(s1), int(s2), int(s3), user_id)
            else:
                print("[WARN] Unknown format:", line)
    except Exception as e:
        print("[ERROR] Main loop error:", e)
        traceback.print_exc()
        time.sleep(2)