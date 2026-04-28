void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
}

void loop() {
  // put your main code here, to run repeatedly:
    Serial.print("Pin A0: ");   Serial.print(analogRead(A0));
  Serial.print("\tPin A1: "); Serial.println(analogRead(A1));
  delay(100);
}
