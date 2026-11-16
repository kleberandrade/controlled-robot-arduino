#include <SoftwareSerial.h>
#include "Robot.h"
// Uno RX, TX; TX passes through a 1k/2k divider to HC-05 RX.
SoftwareSerial bluetooth(10, 11);
robot::Robot controller;
const uint8_t standbyPin=4;
void motor(uint8_t in1, uint8_t in2, uint8_t pwm, int16_t speed) {
  analogWrite(pwm, 0);
  digitalWrite(in1, speed > 0 ? HIGH : LOW);
  digitalWrite(in2, speed < 0 ? HIGH : LOW);
  analogWrite(pwm, speed < 0 ? -speed : speed);
}
void applyMotors() {
  const robot::Wheels wheels=controller.wheels();
  digitalWrite(standbyPin, LOW);
  motor(7,8,5,wheels.left);
  motor(9,12,6,wheels.right);
  if (controller.motion()!=robot::Motion::stop) digitalWrite(standbyPin,HIGH);
}
void report(robot::Event event) {
  if (event==robot::Event::none) return;
  applyMotors();
  if (event==robot::Event::accepted) {
    bluetooth.print(F("OK ")); bluetooth.println(controller.command());
  } else if (event==robot::Event::invalid) bluetooth.println(F("ERR"));
  else bluetooth.println(F("TIMEOUT"));
}
void setup() {
  const uint8_t pins[]={4,5,6,7,8,9,12};
  for (uint8_t pin:pins) { digitalWrite(pin,LOW); pinMode(pin,OUTPUT); }
  applyMotors();
  bluetooth.begin(9600);
  bluetooth.println(F("READY S"));
}
void loop() {
  report(controller.tick(millis()));
  if (bluetooth.available()) report(controller.receive(bluetooth.read(),millis()));
}
