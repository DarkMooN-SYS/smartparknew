import cv2
import numpy as np
import os
from flask import Flask, jsonify, Response, request
import time

app = Flask(__name__)

# Get absolute base path
base_path = os.path.dirname(os.path.abspath(__file__))

def load_yolo():
    """YOLO загварыг ачааллах"""
    try:
        # Файлуудын замыг зөв зааж өгөх
        weights_path = os.path.join(base_path, "yolov3.weights")
        cfg_path = os.path.join(base_path, "yolov3.cfg")
        names_path = os.path.join(base_path, "coco.names")

        # Файлууд байгаа эсэхийг шалгах
        if not all(os.path.exists(f) for f in [weights_path, cfg_path, names_path]):
            raise Exception("YOLO файлууд олдсонгүй")

        net = cv2.dnn.readNet(weights_path, cfg_path)
        with open(names_path, "r") as f:
            classes = [line.strip() for line in f.readlines()]
        
        layer_names = net.getLayerNames()
        try:
            output_layers = [layer_names[i - 1] for i in net.getUnconnectedOutLayers().flatten()]
        except:
            output_layers = [layer_names[i[0] - 1] for i in net.getUnconnectedOutLayers()]
        
        print("[OK] YOLO модел амжилттай ачааллалаа")
        return net, classes, output_layers
    except Exception as e:
        print(f"[ERROR] YOLO ачааллахад алдаа гарлаа: {str(e)}")
        raise

# Объект илрүүлэх
def detect_objects(frame, net, output_layers):
    height, width = frame.shape[:2]
    blob = cv2.dnn.blobFromImage(frame, 1/255.0, (416, 416), swapRB=True, crop=False)
    net.setInput(blob)
    outputs = net.forward(output_layers)

    class_ids = []
    confidences = []
    boxes = []

    for output in outputs:
        for detection in output:
            scores = detection[5:]
            class_id = np.argmax(scores)
            confidence = scores[class_id]
            if confidence > 0.5:
                center_x = int(detection[0] * width)
                center_y = int(detection[1] * height)
                w = int(detection[2] * width)
                h = int(detection[3] * height)
                x = int(center_x - w / 2)
                y = int(center_y - h / 2)

                boxes.append([x, y, w, h])
                confidences.append(float(confidence))
                class_ids.append(class_id)

    return class_ids, confidences, boxes

def get_available_cameras():
    """Боломжтой камеруудыг олох"""
    available_cameras = []
    
    # USB камерууд шалгах
    for i in range(10):  # 0-9 хүртэлх камер шалгах
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, _ = cap.read()
            if ret:
                available_cameras.append({
                    'id': i,
                    'type': 'USB',
                    'name': f'USB Camera {i}'
                })
            cap.release()
    
    return available_cameras

@app.route('/list-cameras', methods=['GET'])
def list_cameras():
    """Боломжтой камеруудын жагсаалт авах"""
    try:
        cameras = get_available_cameras()
        return jsonify({
            'success': True,
            'cameras': cameras
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/detect-cars-camera', methods=['POST'])
def detect_cars_camera():
    """Сонгосон камераас машин илрүүлэх"""
    try:
        # Request-с камерын мэдээлэл авах
        data = request.get_json()
        camera_id = data.get('camera_id', 0)
        camera_type = data.get('type', 'USB')
        
        # YOLO загварыг ачааллах
        net, classes, output_layers = load_yolo()
        
        # Камер нээх
        if camera_type == 'USB':
            cap = cv2.VideoCapture(camera_id)
        else:
            # IP камерын хаяг
            ip_address = data.get('ip_address')
            if not ip_address:
                raise Exception('IP хаяг заагаагүй байна')
            cap = cv2.VideoCapture(f'http://{ip_address}/video')
            
        if not cap.isOpened():
            raise Exception("Камер нээж чадсангүй")
            
        print(f"[OK] {camera_type} камер амжилттай нээгдлээ")
        
        # Тохиргоонууд
        frame_count = 0
        max_frames = 10  # 10 frame авах
        car_counts = []
        detected_frames = []
        
        while frame_count < max_frames:
            ret, frame = cap.read()
            if not ret:
                break
                
            # Frame боловсруулах
            class_ids, confidences, boxes = detect_objects(frame, net, output_layers)
            
            # Машин тоолох
            if "car" in classes:
                car_index = classes.index("car")
                cars_in_frame = class_ids.count(car_index)
                car_counts.append(cars_in_frame)
                
                # Илрүүлсэн машинуудыг тэмдэглэх
                for i in range(len(boxes)):
                    if class_ids[i] == car_index:
                        x, y, w, h = boxes[i]
                        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
                        
                detected_frames.append(frame)
            
            frame_count += 1
            
        cap.release()
        
        # Дундаж машины тоо
        if car_counts:
            avg_cars = sum(car_counts) / len(car_counts)
            final_count = round(avg_cars)
        else:
            final_count = 0
            
        # Хамгийн сүүлийн frame хадгалах
        if detected_frames:
            output_path = os.path.join(base_path, f"detected_cars_{int(time.time())}.jpg")
            cv2.imwrite(output_path, detected_frames[-1])
            
        print(f"[INFO] Нийт {final_count} машин илрүүллээ")
        
        return jsonify({
            'success': True,
            'car_count': final_count,
            'message': 'Машин тоолох үйл явц амжилттай',
            'image_path': output_path if detected_frames else None
        })

    except Exception as e:
        print(f"[ERROR] Алдаа гарлаа: {str(e)}")
        return jsonify({
            'success': False, 
            'error': str(e),
            'message': 'Машин тоолоход алдаа гарлаа'
        }), 500

if __name__ == '__main__':
    app.run(debug=True)
