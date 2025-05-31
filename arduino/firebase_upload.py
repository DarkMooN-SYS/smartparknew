import serial
import time
import firebase_admin
from firebase_admin import credentials, firestore
import traceback
import os
import sys
import serial.tools.list_ports

def test_firebase_connection():
    try:
        db = firestore.client()
        test_ref = db.collection('arduino_data').document()
        test_ref.set({
            'test': True,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        test_ref.delete()
        print("[OK] Firebase холболт амжилттай")
        return True
    except Exception as e:
        print(f"[ERROR] Firebase холболт амжилтгүй: {str(e)}")
        return False

def test_serial_connection(port='COM7'):
    try:
        test_ser = serial.Serial(port, 9600, timeout=1)
        if test_ser.is_open:
            print(f"[OK] Serial connection test successful on {port}")
            test_ser.close()
            return True
    except serial.SerialException as e:
        print(f"[ERROR] Serial connection test failed on {port}: {str(e)}")
        return False
    return False

def is_port_in_use(port):
    """COM порт ашиглагдаж байгаа эсэхийг шалгах"""
    try:
        # Түр зуур нээж үзэх
        test_serial = serial.Serial(port, 9600)
        test_serial.close()
        return False
    except serial.SerialException:
        return True

def wait_for_port(port='COM7', timeout=30):
    """COM порт боломжтой болохыг хүлээх"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        if not is_port_in_use(port):
            return True
        print(f"[WAIT] COM порт {port} ашиглагдаж байна, хүлээж байна...")
        time.sleep(2)
    return False

def find_arduino_port():
    """Arduino холбогдсон COM портыг хайх"""
    ports = list(serial.tools.list_ports.comports())
    for port in ports:
        if 'Arduino' in port.description:
            return port.device
    return 'COM7'  # Default port if Arduino not found

def connect_to_arduino(port='COM7', max_attempts=3):
    """Arduino-тай холбогдох"""
    attempt = 0
    while attempt < max_attempts:
        try:
            if not wait_for_port(port, timeout=5):  # Reduce timeout to 5 seconds
                attempt += 1
                print(f"[RETRY] Холболтын оролдлого {attempt}/{max_attempts}")
                continue

            ser = serial.Serial(port, 9600, timeout=1)
            print(f"[OK] {port} порттой холбогдлоо")
            return ser
        except KeyboardInterrupt:
            print("\n[INFO] Хэрэглэгч програмыг зогсоолоо")
            raise
        except Exception as e:
            print(f"[ERROR] Холболтын алдаа: {e}")
            attempt += 1
            if attempt < max_attempts:
                time.sleep(2)
    return None

# Get absolute path to config file
current_dir = os.path.dirname(os.path.abspath(__file__))
config_path = os.path.join(current_dir, "firebase_config.json")

def initialize_firebase():
    try:
        # Check if already initialized
        try:
            app = firebase_admin.get_app()
            return True
        except ValueError:
            pass

        cred = credentials.Certificate(config_path)
        firebase_admin.initialize_app(cred)
        return test_firebase_connection()
    except Exception as e:
        print(f"[ERROR] Firebase initialization failed: {e}")
        return False

def update_slots_available(db, total_occupied: int):
    try:
        batch = db.batch()
        success = False
        
        parking_docs = db.collection('parkings').stream()
        for doc in parking_docs:
            try:
                parking_data = doc.to_dict()
                if not parking_data or 'slots_available' not in parking_data:
                    continue
                
                slots_data = parking_data['slots_available']
                total_slots = int(slots_data.split('/')[1])
                price = float(parking_data.get('price', '500'))  # Default price 500
                
                updates = {
                    'slots_available': f"{total_slots - total_occupied}/{total_slots}",
                    'last_updated': firestore.SERVER_TIMESTAMP,
                    'arduino_status': {
                        'slot_1': 'Full' if total_occupied > 0 else 'Empty',
                        'slot_2': 'Full' if total_occupied > 1 else 'Empty', 
                        'slot_3': 'Full' if total_occupied > 2 else 'Empty',
                    },
                    'current_amount': total_occupied * price  # Calculate total amount
                }
                
                batch.update(doc.reference, updates)
                success = True
                
            except Exception as e:
                print(f"[ERROR] Failed to update parking {doc.id}: {e}")
                continue
        
        if success:
            batch.commit()
            return True
            
        return False
        
    except Exception as e:
        print(f"[ERROR] Failed to update parkings: {e}")
        return False

# Initialize Firebase and test connection
try:
    if not initialize_firebase():
        raise Exception("Firebase initialization failed")
except Exception as e:
    print(f"[ERROR] Setup failed: {e}")
    exit(1)

# Test and initialize serial connection
try:
    arduino_port = find_arduino_port()
    print(f"[INFO] Arduino порт: {arduino_port}")
    ser = connect_to_arduino(arduino_port)
    if not ser:
        print("[ERROR] Arduino-тай холбогдож чадсангүй")
        exit(1)
except KeyboardInterrupt:
    print("\n[INFO] Программ зогссон")
    sys.exit(0)

def upload_to_firebase(s1: int, s2: int, s3: int, user_id: str) -> bool:
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            db = firestore.client()
            total_occupied = s1 + s2 + s3
            
            # Update arduino_data collection
            status_data = {
                's1': s1,
                's2': s2,
                's3': s3,
                'user_id': user_id,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'total_occupied': total_occupied,
                'parking_id': None  # Will be updated by Cloud Functions
            }
            
            # Add to arduino_data to trigger Cloud Function
            db.collection('arduino_data').add(status_data)
            
            # Update parking slots
            update_slots_available(db, total_occupied)
            
            print(f"[OK] Arduino data uploaded and slots updated")
            return True
            
        except Exception as e:
            retry_count += 1
            print(f"[ERROR] Firebase алдаа (оролдлого {retry_count}/{max_retries}):", str(e))
            if retry_count < max_retries:
                time.sleep(2)
                continue
            return False
    return False

def check_connections():
    """Бүх холболтуудыг шалгах"""
    if not test_firebase_connection():
        print("[ERROR] Firebase холболт тасарсан")
        print("[ERROR] Arduino холболт тасарсан")
        return False
    return True

def reset_arduino():
    """Arduino-г дахин ачаалах"""
    try:
        if ser.is_open:
            ser.write(b'RESET\n')  # Arduino рүү reset команд илгээх
            time.sleep(2)  # Arduino-г дахин ачаалахыг хүлээх
            print("[OK] Arduino дахин ачаалав")
    except Exception as e:
        print("[ERROR] Arduino дахин ачаалж чадсангүй:", e)

def cleanup():
    """Холболтуудыг аюулгүй хаах"""
    print("\n[INFO] Программыг зогсоож байна...")
    try:
        if 'ser' in globals() and ser.is_open:
            ser.write(b'RESET\n')  # Reset команд илгээх
            time.sleep(1)
            ser.close()
            print("[OK] Serial port хаагдлаа")
    except Exception as e:
        print("[ERROR] Serial port хаахад алдаа гарлаа:", e)
    
    try:
        firebase_admin.delete_app(firebase_admin.get_app())
        print("[OK] Firebase холболт хаагдлаа")
    except Exception as e:
        print("[ERROR] Firebase хаахад алдаа гарлаа:", e)

try:
    while True:
        try:
            # 1 минут тутамд холболтуудыг шалгах
            if time.time() % 60 == 0:
                if not check_connections():
                    print("[INFO] Холболтуудыг дахин тохируулж байна...")
                    time.sleep(5)
                    continue
                
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8').strip()
                # Зөвхөн зогсоолын төлөв агуулсан мөрийг шалгах
                if ',' in line and len(line.split(',')) == 4:
                    parts = line.split(',')
                    try:
                        s1, s2, s3 = map(int, parts[0:3])
                        user_id = parts[3].strip()
                        if upload_to_firebase(s1, s2, s3, user_id):
                            print("[OK] Амжилттай хадгаллаа")
                        else:
                            print("[ERROR] Хадгалж чадсангүй")
                    except ValueError:
                        print("[ERROR] Тоон утга буруу байна:", line)
                else:
                    print("[INFO] Лог мэдээлэл:", line)
                
        except serial.SerialException as e:
            print("[ERROR] Serial port алдаа:", e)
            time.sleep(5)
        except Exception as e:
            print("[ERROR] Ерөнхий алдаа:", e)
            traceback.print_exc()
            time.sleep(2)
            
except KeyboardInterrupt:
    print("\n[INFO] Программ зогсоох...")
except Exception as e:
    print(f"[ERROR] Програм алдаатай зогслоо: {e}")
    traceback.print_exc()
finally:
    cleanup()
    sys.exit(0)