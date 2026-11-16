#include "../firmware/robot/Robot.h"
#include <cassert>
#include <cstdint>
#include <iostream>
using namespace robot;
void frame(Robot& r, char c, uint32_t t) { r.receive(c,t); r.receive('\n',t); }
int main() {
  Robot r;
  assert(r.motion() == Motion::stop);
  r.receive('F',0); assert(r.motion()==Motion::stop);
  assert(r.receive('\n',1)==Event::accepted);
  assert(r.motion()==Motion::forward);
  assert(r.tick(500)==Event::none);
  assert(r.tick(501)==Event::timeout);
  assert(r.motion()==Motion::stop);
  assert(r.tick(502)==Event::none);
  const char commands[]={'F','B','L','R','S'};
  const Wheels expected[]={{160,160},{-160,-160},{-160,160},{160,-160},{0,0}};
  for(int i=0;i<5;++i) { frame(r,commands[i],1000); auto w=r.wheels(); assert(w.left==expected[i].left && w.right==expected[i].right); }
  frame(r,'F',1100);
  assert(r.receive('?',1101)==Event::invalid); assert(r.motion()==Motion::stop);
  r.receive('F',1102); r.receive('\n',1103); assert(r.motion()==Motion::stop);
  frame(r,'B',1104); assert(r.motion()==Motion::backward);
  r.receive('F',1105); assert(r.receive('F',1105)==Event::invalid);
  r.receive('\n',1105); assert(r.motion()==Motion::stop);
  assert(r.receive('\n',1200)==Event::invalid);
  r.receive('F',1300); assert(r.tick(1400)==Event::invalid);
  assert(r.receive('\n',1401)==Event::none); assert(r.motion()==Motion::stop);
  frame(r,'F',1500); r.receive('\r',1501); assert(r.motion()==Motion::stop);
  r.receive('\n',1501);
  // Unsigned arithmetic must keep the watchdog safe over millis() rollover.
  frame(r,'F',UINT32_MAX-100); assert(r.tick(398)==Event::none);
  assert(r.tick(399)==Event::timeout);
  std::cout << "robot: parser, movement, timeout and rollover passed\n";
}
