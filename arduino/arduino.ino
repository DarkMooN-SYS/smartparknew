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

// Define symbolic names for magic numbers
#define REFRESH_RATE 100    // Sensor refresh rate in ms
#define DEBOUNCE_DELAY 50   // Debounce delay in ms
#define GATE_DELAY 217      // Servo motor delay
#define GATE_OPEN 135       // Servo open position
#define GATE_CLOSE 52       // Servo close position
#define GATE_NEUTRAL 92     // Servo neutral position

// Системийг дахин эхлүүлэх функц
void(* resetFunc) (void) = 0; 

// Global variables
String UID = "1C 01 45 FF"; // Your RFID card UID
MFRC522 rfid(SS_PIN, RST_PIN);
Servo myservo;
LiquidCrystal_I2C lcd(0x27, 16, 2);

int S1 = 0, S2 = 0, S3 = 0;
const int MaxSlots = 3; // Change to 3 since we have 3 slots

// Function declarations
void showFullMessage();
void showSlotMessage(int slotNum);
void handleCarEntering();
void handleCarExiting();
void Read_Sensor();
bool sendStatusToSerial();
bool rfunc();
void smoothOpenGate();
void smoothCloseGate();
void waitForCarToPass(int sensorPin);
int findEmptySlot();

void setup() {
  Serial.begin(9600);
  // Serial port хүлээх хугацааг 2 секунд болгох
  unsigned long startTime = millis();
  while (!Serial && (millis() - startTime < 2000)) {
    ; // Хүлээх
  }
  lcd.init();
  lcd.backlight();
  
  // Configure sensors with internal pullup resistors
  pinMode(IR1, INPUT_PULLUP);
  pinMode(IR2, INPUT_PULLUP);
  pinMode(ir_car1, INPUT_PULLUP);
  pinMode(ir_car2, INPUT_PULLUP);
  pinMode(ir_car3, INPUT_PULLUP);

  myservo.attach(SERVO_PIN);
  SPI.begin();
  rfid.PCD_Init();

  lcd.setCursor(0, 0); lcd.print("System Starting");
  lcd.setCursor(0, 1); lcd.print("Checking slots...");
  delay(2000);
  
  // Эхний удаа зогсоолуудын төлөвийг шалгаж тохируулах
  initializeParkingStatus();
  
  lcd.clear();
}

void initializeParkingStatus() {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Checking slots...");
  lcd.setCursor(0, 1); lcd.print("Please wait...");
  
  // Хэд хэдэн удаа шалгаж баталгаажуулах
  for(int i = 0; i < 5; i++) {
    bool s1_check = (digitalRead(ir_car1) == LOW);
    bool s2_check = (digitalRead(ir_car2) == LOW);
    bool s3_check = (digitalRead(ir_car3) == LOW);
    
    delay(100);
    
    // Давхар шалгалт
    if(s1_check == (digitalRead(ir_car1) == LOW)) S1 = s1_check;
    if(s2_check == (digitalRead(ir_car2) == LOW)) S2 = s2_check;
    if(s3_check == (digitalRead(ir_car3) == LOW)) S3 = s3_check;
    
    delay(200);
  }
  
  // Эцсийн үр дүнг харуулах
  lcd.clear();
  lcd.setCursor(0, 0); 
  lcd.print("S1:"); lcd.print(S1 ? "Full" : "Empty");
  lcd.setCursor(0, 1);
  lcd.print("S2:"); lcd.print(S2 ? "F" : "E");
  lcd.print(" S3:"); lcd.print(S3 ? "F" : "E");
  delay(2000);
}

void loop() {
  checkForReset();
  Read_Sensor();

  // Машин орох хэсгийг сайжруулах
  static unsigned long lastEntryCheck = 0;
  if (millis() - lastEntryCheck >= 50) {  // Илүү олон удаа шалгах
    lastEntryCheck = millis();
    
    if (digitalRead(IR1) == LOW) {
      Read_Sensor();  // Зогсоолын төлөвийг шинэчлэх
      
      if (S1 && S2 && S3) {
        showFullMessage();
      } else {
        // RFID уншуулахыг хүлээх
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("Card to enter");
        
        unsigned long waitStart = millis();
        while (millis() - waitStart < 5000) {  // 5 секунд хүлээх
          if (rfunc()) {  // RFID карт уншуулсан бол
            handleCarEntering();
            break;
          }
          delay(100);
        }
      }
    }
  }

  // Машин гарах үед
  if (digitalRead(IR2) == LOW) {
    handleCarExiting();
  }

  int total = S1 + S2 + S3;

  lcd.setCursor(0, 0);
  lcd.print("Total: ");
  lcd.print(total);
  lcd.print(" cars   ");

  lcd.setCursor(0, 1);
  lcd.print("S1:"); lcd.print(S1 ? "1 " : "0 ");
  lcd.print("S2:"); lcd.print(S2 ? "1 " : "0 ");
  lcd.print("S3:"); lcd.print(S3 ? "1 " : "0 ");

  delay(1000);
}

void handleCarEntering() {
  static bool carEntering = false;
  if (!carEntering) {
    carEntering = true;
    
    Read_Sensor();
    int emptySlot = findEmptySlot();
    
    if (emptySlot > 0) {
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(emptySlot); lcd.print("- slot is free");
      lcd.setCursor(0, 1);
      lcd.print("Gate Opening...");
      
      smoothOpenGate();
      
      // Машин орох хүртэл хүлээх
      unsigned long waitStart = millis();
      bool carPassed = false;
      
      while (millis() - waitStart < 10000) {  // 10 секунд хүлээх
        if (digitalRead(IR2) == LOW) {  // Машин орж эхэлсэн
          while (digitalRead(IR2) == LOW) {  // Бүрэн өнгөртөл хүлээх
            delay(100);
          }
          carPassed = true;
          break;
        }
        delay(100);
      }
      
      smoothCloseGate();
      
      if (carPassed) {
        lcd.clear();
        lcd.print("successfully Entry");
      } else {
        lcd.clear();
        lcd.print("Time out!");
      }
      delay(2000);
    }
    
    carEntering = false;
  }
}

// Шинээр нэмэх функц
int findEmptySlot() {
  if (!S1) return 1;
  if (!S2) return 2;
  if (!S3) return 3;
  return 0;
}

void handleCarExiting() {
  static bool carExiting = false;
  if (!carExiting) {
    carExiting = true;
    Read_Sensor();
    
    smoothOpenGate();
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Car Exiting...");
    delay(2000);

    waitForCarToPass(IR1);
    smoothCloseGate();

    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Gate Closed!");
    delay(2000);
    carExiting = false;
  }
}

void Read_Sensor() {
  static unsigned long lastRead = 0;
  if (millis() - lastRead >= REFRESH_RATE) {
    // Бүх сенсорыг нэг дор уншиж авах
    bool s1_current = (digitalRead(ir_car1) == LOW);
    bool s2_current = (digitalRead(ir_car2) == LOW);
    bool s3_current = (digitalRead(ir_car3) == LOW);
    
    delay(DEBOUNCE_DELAY);
    
    // Давхар шалгалт
    if (s1_current == (digitalRead(ir_car1) == LOW)) {
      if (s1_current != S1) {  // Төлөв өөрчлөгдсөн үед л шинэчлэх
        S1 = s1_current;
        sendStatusToSerial();  // Шинэчлэлтийг мэдээлэх
      }
    }
    
    if (s2_current == (digitalRead(ir_car2) == LOW)) {
      if (s2_current != S2) {
        S2 = s2_current;
        sendStatusToSerial();
      }
    }
    
    if (s3_current == (digitalRead(ir_car3) == LOW)) {
      if (s3_current != S3) {
        S3 = s3_current;
        sendStatusToSerial();
      }
    }
    
    lastRead = millis();
  }
}

void waitForCarToPass(int sensorPin) {
  while (digitalRead(sensorPin) == HIGH) delay(100);
  while (digitalRead(sensorPin) == LOW) delay(100);
}

void smoothOpenGate() {
  for (int pos = GATE_NEUTRAL; pos <= GATE_OPEN; pos++) {
    myservo.write(pos);
    delay(15);
  }
  myservo.write(GATE_NEUTRAL);
}

void smoothCloseGate() {
  for (int pos = GATE_NEUTRAL; pos >= GATE_CLOSE; pos--) {
    myservo.write(pos);
    delay(15);
  }
  myservo.write(GATE_NEUTRAL);
}

// Serial мэдээлэл илгээх функцийг сайжруулах
bool sendStatusToSerial() {
  if (!Serial) return false;
  
  Serial.print(S1);
  Serial.print(",");
  Serial.print(S2);
  Serial.print(",");
  Serial.print(S3);
  Serial.print(",");
  Serial.println("UPDATE");  // Статус шинэчлэгдсэн тэмдэг
  return true;
}

// Хуучин rfunc() функцийг өөрчлөх
bool rfunc() {
  if (!rfid.PICC_IsNewCardPresent()) return false;
  if (!rfid.PICC_ReadCardSerial()) return false;

  String content = "";
  byte *buffer = rfid.uid.uidByte;
  byte bufferSize = rfid.uid.size;
  
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) {
      content += "0";
    }
    content += String(buffer[i], HEX);
    if (i < bufferSize - 1) {
      content += " ";
    }
  }
  
  content.toUpperCase();
  rfid.PICC_HaltA();  // RFID картыг унтраах
  rfid.PCD_StopCrypto1();  // Криптографийг зогсоох

  if (content == UID) {
    sendStatusToSerial();
    return true;
  }
  return false;
}

// Serial port-оос reset команд хүлээн авах
void checkForReset() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    if (command == "RESET") {
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("System Reset...");
      delay(1000);
      // Системийг програмын түвшинд дахин эхлүүлэх
      asm volatile ("jmp 0");  // Alternative reset method
    }
  }
}

void showFullMessage() {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Sorry T-T ");
  lcd.setCursor(0, 1); lcd.print("slots full");
  delay(2000);
}

void showSlotMessage(int slotNum) {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Gate Opened");
  lcd.setCursor(0, 1); 
  lcd.print(slotNum); lcd.print("- slot is free");
}
