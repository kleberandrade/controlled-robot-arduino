#pragma once
#include <stdint.h>
namespace robot {
enum class Motion { stop, forward, backward, left, right };
enum class Event { none, accepted, invalid, timeout };
struct Wheels { int16_t left; int16_t right; };
class Robot {
 public:
  static const uint32_t timeoutMs = 500;
  static const uint32_t frameMs = 100;
  Motion motion() const { return motion_; }
  char command() const { return command_; }
  Wheels wheels() const {
    switch (motion_) {
      case Motion::forward: return {160,160};
      case Motion::backward: return {-160,-160};
      case Motion::left: return {-160,160};
      case Motion::right: return {160,-160};
      default: return {0,0};
    }
  }
  Event tick(uint32_t now) {
    if (pending_ && uint32_t(now-started_) >= frameMs) return reject();
    if (motion_ != Motion::stop && uint32_t(now-last_) >= timeoutMs) {
      stop(); return Event::timeout;
    }
    return Event::none;
  }
  Event receive(char byte, uint32_t now) {
    if (discard_) {
      if (byte=='\n') discard_=false;
      return Event::none;
    }
    if (byte=='\n') {
      if (!pending_) { stop(); return Event::invalid; }
      pending_=false;
      if (uint32_t(now-started_) >= frameMs) { stop(); return Event::invalid; }
      command_=buffer_; motion_=decode(buffer_); last_=now;
      return Event::accepted;
    }
    if (pending_ || !valid(byte)) return reject();
    buffer_=byte; pending_=true; started_=now;
    return Event::none;
  }
 private:
  static bool valid(char c) { return c=='F'||c=='B'||c=='L'||c=='R'||c=='S'; }
  static Motion decode(char c) {
    switch(c) {
      case 'F': return Motion::forward;
      case 'B': return Motion::backward;
      case 'L': return Motion::left;
      case 'R': return Motion::right;
      default: return Motion::stop;
    }
  }
  void stop() { motion_=Motion::stop; command_='S'; }
  Event reject() { stop(); pending_=false; discard_=true; return Event::invalid; }
  Motion motion_=Motion::stop;
  char command_='S', buffer_=0;
  bool pending_=false, discard_=false;
  uint32_t started_=0, last_=0;
};
}
