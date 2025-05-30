#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Servo.h>
#include <SPI.h>
#include <MFRC522.h>

// Pin definitions
#define SS_PIN 10
#define RST_PIN 9
#define SERVO_PIN 2
#define ir_car1 5
#define ir_car2 6
#define ir_car3 7
#define IR1 4 // Entry sensor
#define IR2 3 // Exit sensor

// Global variables
String UID = "1C 01 45 FF"; // Your RFID card UID
MFRC522 rfid(SS_PIN, RST_PIN);
Servo myservo;
LiquidCrystal_I2C lcd(0x27, 16, 2);

int S1 = 0, S2 = 0, S3 = 0;
int Slot = 4;
const int MaxSlots = 4;

void setup() {
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  
  pinMode(IR1, INPUT);
  pinMode(IR2, INPUT);
  pinMode(ir_car1, INPUT);
  pinMode(ir_car2, INPUT);
  pinMode(ir_car3, INPUT);

  myservo.attach(SERVO_PIN);
  SPI.begin();
  rfid.PCD_Init();

  lcd.setCursor(0, 0); lcd.print("    ARDUINO    ");
  lcd.setCursor(0, 1); lcd.print(" PARKING SYSTEM ");
  delay(3000);
  lcd.clear();
}

void loop() {
  if (digitalRead(IR1) == LOW) handleCarEntering();
  if (digitalRead(IR2) == LOW) handleCarExiting();

  Read_Sensor();
  int total = S1 + S2 + S3;

  lcd.setCursor(0, 0);
  lcd.print("Total: ");
  lcd.print(total);
  lcd.print(" cars   ");

  lcd.setCursor(0, 1);
  lcd.print("S1:"); lcd.print(S1 ? "F " : "E ");
  lcd.print("S2:"); lcd.print(S2 ? "F " : "E ");
  lcd.print("S3:"); lcd.print(S3 ? "F " : "E ");

  delay(1000);
}

void handleCarEntering() {
  static bool carEntering = false;
  if (!carEntering) {
    carEntering = true;
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Car Detected!");
    delay(1000);

    if (Slot > 0) {
      if (rfunc()) {
        smoothOpenGate();
        Slot--;
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print("Gate Opened!");
        delay(2000);

        waitForCarToPass(IR2);
        smoothCloseGate();

        lcd.clear();
        lcd.setCursor(0, 0); lcd.print("Gate Closed!");
        delay(2000);
      }
    } else {
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print("    SORRY :(    ");
      lcd.setCursor(0, 1); lcd.print("  Parking Full  ");
      delay(3000);
    }
    carEntering = false;
  }
}

void handleCarExiting() {
  static bool carExiting = false;
  if (!carExiting && Slot < MaxSlots) {
    carExiting = true;

    smoothOpenGate();
    Slot++;
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Car Exiting...");
    delay(2000);

    waitForCarToPass(IR1);
    smoothCloseGate();

    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Gate Closed!");
    delay(2000);
    carExiting = false;
  } else if (Slot == MaxSlots) {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(" No Cars Left! ");
    delay(3000);
  }
}

void Read_Sensor() {
  S1 = digitalRead(ir_car1) == LOW ? 1 : 0;
  S2 = digitalRead(ir_car2) == LOW ? 1 : 0;
  S3 = digitalRead(ir_car3) == LOW ? 1 : 0;
}

void waitForCarToPass(int sensorPin) {
  while (digitalRead(sensorPin) == HIGH) delay(100);
  while (digitalRead(sensorPin) == LOW) delay(100);
}

void smoothOpenGate() {
  myservo.write(135);
  delay(217);         
  myservo.write(92); 
}

void smoothCloseGate() {
  myservo.write(52);  
  delay(217);
  myservo.write(92);
}

// Dummy RFID checker
bool rfunc() {
  if (!rfid.PICC_IsNewCardPresent()) return false;
  if (!rfid.PICC_ReadCardSerial()) return false;

  String content = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    content += String(rfid.uid.uidByte[i] < 0x10 ? " 0" : " ");
    content += String(rfid.uid.uidByte[i], HEX);
  }
  content.trim();
  content.toUpperCase();

  if (content == UID) {
    // Send slot status and user ID to Python
    Serial.print(S1);
    Serial.print(",");
    Serial.print(S2);
    Serial.print(",");
    Serial.print(S3);
    Serial.print(",");
    Serial.println("user1"); // Adding user ID to serial data
    return true;
  }
  return false;
}
