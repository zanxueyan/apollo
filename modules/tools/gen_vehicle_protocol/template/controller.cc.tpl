/******************************************************************************
 * Copyright 2023 The Apollo Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#include "modules/canbus_vehicle/%(car_type_lower)s/%(car_type_lower)s_controller.h"

#include <string>

#include "modules/common_msgs/basic_msgs/vehicle_signal.pb.h"

#include "cyber/common/log.h"
#include "cyber/time/time.h"
#include "modules/canbus/vehicle/vehicle_controller.h"
#include "modules/canbus_vehicle/%(car_type_lower)s/%(car_type_lower)s_message_manager.h"
#include "modules/drivers/canbus/can_comm/can_sender.h"
#include "modules/drivers/canbus/can_comm/protocol_data.h"

namespace apollo {
namespace canbus {
namespace %(car_type_lower)s {
using ::apollo::common::ErrorCode;
using ::apollo::common::VehicleSignal;
using ::apollo::control::ControlCommand;
using ::apollo::drivers::canbus::ProtocolData;

namespace {
const int32_t kMaxFailAttempt = 10;
const int32_t CHECK_RESPONSE_STEER_UNIT_FLAG = 1;
const int32_t CHECK_RESPONSE_SPEED_UNIT_FLAG = 2;

}  // namespace

ErrorCode %(car_type_cap)sController::Init(
	const VehicleParameter& params,
	CanSender<::apollo::canbus::%(car_type_cap)s> *const can_sender,
    MessageManager<::apollo::canbus::%(car_type_cap)s> *const message_manager) {
  if (is_initialized_) {
    AINFO << "%(car_type_cap)sController has already been initiated.";
    return ErrorCode::CANBUS_ERROR;
  }

  vehicle_params_.CopyFrom(
      common::VehicleConfigHelper::Instance()->GetConfig().vehicle_param());
  params_.CopyFrom(params);
  if (!params_.has_driving_mode()) {
    AERROR << "Vehicle conf pb not set driving_mode.";
    return ErrorCode::CANBUS_ERROR;
  }

  if (can_sender == nullptr) {
    AERROR << "Canbus sender is null.";
    return ErrorCode::CANBUS_ERROR;
  }
  can_sender_ = can_sender;

  if (message_manager == nullptr) {
    AERROR << "protocol manager is null.";
    return ErrorCode::CANBUS_ERROR;
  }
  message_manager_ = message_manager;

  // sender part
%(protocol_ptr_get_list)s
%(protocol_add_list)s

  // need sleep to ensure all messages received
  AINFO << "%(car_type_cap)sController is initialized.";

  is_initialized_ = true;
  return ErrorCode::OK;
}

%(car_type_cap)sController::~%(car_type_cap)sController() {}

bool %(car_type_cap)sController::Start() {
  if (!is_initialized_) {
    AERROR << "%(car_type_cap)sController has NOT been initiated.";
    return false;
  }
  const auto& update_func = [this] { SecurityDogThreadFunc(); };
  thread_.reset(new std::thread(update_func));

  return true;
}

void %(car_type_cap)sController::Stop() {
  if (!is_initialized_) {
    AERROR << "%(car_type_cap)sController stops or starts improperly!";
    return;
  }

  if (thread_ != nullptr && thread_->joinable()) {
    thread_->join();
    thread_.reset();
    AINFO << "%(car_type_cap)sController stopped.";
  }
}

Chassis %(car_type_cap)sController::chassis() {
  chassis_.Clear();

  %(car_type_cap)s chassis_detail;
  message_manager_->GetSensorData(&chassis_detail);

  // 21, 22, previously 1, 2
  // if (driving_mode() == Chassis::EMERGENCY_MODE) {
  //   set_chassis_error_code(Chassis::NO_ERROR);
  // }

  chassis_.set_driving_mode(driving_mode());
  chassis_.set_error_code(chassis_error_code());
  // 3
  chassis_.set_engine_started(true);
  // 4 chassis spd
  if (chassis_detail.has_%(speed_protocol_name)s() &&
      chassis_detail.%(speed_protocol_name)s().has_%(speed_reoport_name)s()) {
    chassis_.set_speed_mps(
        static_cast<float>(chassis_detail.%(speed_protocol_name)s().%(speed_reoport_name)s()));
  } else {
    chassis_.set_speed_mps(0);
  }
  // 5 throttle
  if (chassis_detail.has_%(throttle_protocol_name)s() &&
      chassis_detail.%(throttle_protocol_name)s().has_%(throttle_report_name)s()) {
    chassis_.set_throttle_percentage(static_cast<float>(
        chassis_detail.%(throttle_protocol_name)s().%(throttle_report_name)s()));
  } else {
    chassis_.set_throttle_percentage(0);
  }
  // 6 brake
  if (chassis_detail.has_%(brake_protocol_name)s() &&
      chassis_detail.%(brake_protocol_name)s().has_%(brake_report_name)s()) {
    chassis_.set_brake_percentage(static_cast<float>(
        chassis_detail.%(brake_protocol_name)s().%(brake_report_name)s()));
  } else {
    chassis_.set_brake_percentage(0);
  }
  // 7 gear
  if (chassis_detail.has_%(gear_protocol_name)s() &&
      chassis_detail.%(gear_protocol_name)s().has_%(gear_report_name)s()) {
    Chassis::GearPosition gear_pos = Chassis::GEAR_INVALID;

    if (chassis_detail.%(gear_protocol_name)s().%(gear_report_name)s() ==
        %(gear_report_protocol_name_cap)s::%(gear_report_neutral_enum)s) {
      gear_pos = Chassis::GEAR_NEUTRAL;
    }
    if (chassis_detail.%(gear_protocol_name)s().gear_sts() ==
        %(gear_report_protocol_name_cap)s::%(gear_report_reverse_enum)s) {
      gear_pos = Chassis::GEAR_REVERSE;
    }
    if (chassis_detail.%(gear_protocol_name)s().gear_sts() ==
        %(gear_report_protocol_name_cap)s::%(gear_report_drive_enum)s) {
      gear_pos = Chassis::GEAR_DRIVE;
    }
    if (chassis_detail.%(gear_protocol_name)s().gear_sts() ==
        %(gear_report_protocol_name_cap)s::%(gear_report_park_enum)s) {
      gear_pos = Chassis::GEAR_PARKING;
    }

    chassis_.set_gear_location(gear_pos);
  } else {
    chassis_.set_gear_location(Chassis::GEAR_NONE);
  }
  // 8 steer
  if (chassis_detail.has_%(steer_protocol_name)s() &&
      chassis_detail.%(steer_protocol_name)s().has_%(steer_report_name)s()) {
    chassis_.set_steering_percentage(static_cast<float>(
        chassis_detail.%(steer_protocol_name)s().%(steer_report_name)s() * 100.0 /
        vehicle_params_.max_steer_angle()));
  } else {
    chassis_.set_steering_percentage(0);
  }
  // 9 checkresponse signal
  if (chassis_detail.has_%(brake_protocol_name)s() &&
      chassis_detail.%(brake_protocol_name)s().has_%(brake_report_enable_name)s()) {
    chassis_.mutable_check_response()->set_is_esp_online(
        chassis_detail.%(brake_protocol_name)s().%(brake_report_enable_name)s() == 1);
  }
  if (chassis_detail.has_%(steer_protocol_name)s() &&
      chassis_detail.%(steer_protocol_name)s().has_%(steer_report_enable_name)s()) {
    chassis_.mutable_check_response()->set_is_eps_online(
        chassis_detail.%(steer_protocol_name)s().%(steer_report_enable_name)s() == 1);
  }
  if (chassis_detail.has_%(throttle_protocol_name)s() &&
      chassis_detail.%(throttle_protocol_name)s().has_%(throttle_report_enable_name)s()) {
    chassis_.mutable_check_response()->set_is_vcu_online(
        chassis_detail.%(throttle_protocol_name)s().%(throttle_report_enable_name)s() == 1);
  }
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  // 10 battery soc
  // 11 vin
  // 12 bumper event
  */
  return chassis_;
}

void %(car_type_cap)sController::Emergency() {
  set_driving_mode(Chassis::EMERGENCY_MODE);
  ResetProtocol();
}

ErrorCode %(car_type_cap)sController::EnableAutoMode() {
  if (driving_mode() == Chassis::COMPLETE_AUTO_DRIVE) {
    AINFO << "already in COMPLETE_AUTO_DRIVE mode";
    return ErrorCode::OK;
  }
  // set enable
  %(brake_command_protocol_name)s_->set_%(brake_command_enable_name)s(
      %(brake_command_protocol_name_cap)s::%(brake_command_enable_enable_enum)s);
  %(throttle_command_protocol_name)s_->set_%(throttle_command_enable_name)s(
      %(throttle_command_protocol_name_cap)s::%(throttle_command_enable_enable_enum)s);
  %(steer_command_protocol_name)s_->set_%(steer_command_enable_name)s(
      %(steer_command_protocol_name_cap)s::%(steer_command_enable_enable_enum)s);

  can_sender_->Update();
  const int32_t flag =
      CHECK_RESPONSE_STEER_UNIT_FLAG | CHECK_RESPONSE_SPEED_UNIT_FLAG;
  if (!CheckResponse(flag, true)) {
    AERROR << "Failed to switch to COMPLETE_AUTO_DRIVE mode. Please check the "
              "emergency button or chassis.";
    Emergency();
    set_chassis_error_code(Chassis::CHASSIS_ERROR);
    return ErrorCode::CANBUS_ERROR;
  }
  set_driving_mode(Chassis::COMPLETE_AUTO_DRIVE);
  AINFO << "Switch to COMPLETE_AUTO_DRIVE mode ok.";
  return ErrorCode::OK;
}

ErrorCode %(car_type_cap)sController::DisableAutoMode() {
  ResetProtocol();
  can_sender_->Update();
  set_driving_mode(Chassis::COMPLETE_MANUAL);
  set_chassis_error_code(Chassis::NO_ERROR);
  AINFO << "Switch to COMPLETE_MANUAL ok.";
  return ErrorCode::OK;
}

ErrorCode %(car_type_cap)sController::EnableSteeringOnlyMode() {
  if (driving_mode() == Chassis::COMPLETE_AUTO_DRIVE ||
      driving_mode() == Chassis::AUTO_STEER_ONLY) {
    set_driving_mode(Chassis::AUTO_STEER_ONLY);
    AINFO << "Already in AUTO_STEER_ONLY mode.";
    return ErrorCode::OK;
  }
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  // TODO(ALL): CHECK YOUR VEHICLE WHETHER SUPPORT THIS MODE OR NOT
  // set enable
  %(brake_command_protocol_name)s_->set_%(brake_command_enable_name)s(
      %(brake_command_protocol_name_cap)s::%(brake_command_enable_disable_enum)s);
  %(throttle_command_protocol_name)s_->set_%(throttle_command_enable_name)s(
      %(throttle_command_protocol_name_cap)s::%(throttle_command_enable_disable_enum)s);
  %(steer_command_protocol_name)s_->set_%(steer_command_enable_name)s(
      %(steer_command_protocol_name_cap)s::%(steer_command_enable_enable_enum)s);

  can_sender_->Update();
  if (!CheckResponse(CHECK_RESPONSE_STEER_UNIT_FLAG, true)) {
    AERROR << "Failed to switch to AUTO_STEER_ONLY mode.";
    Emergency();
    set_chassis_error_code(Chassis::CHASSIS_ERROR);
    return ErrorCode::CANBUS_ERROR;
  }
  set_driving_mode(Chassis::AUTO_STEER_ONLY);
  AINFO << "Switch to AUTO_STEER_ONLY mode ok.";
  return ErrorCode::OK;
  */
  return ErrorCode::OK;
}

ErrorCode %(car_type_cap)sController::EnableSpeedOnlyMode() {
  if (driving_mode() == Chassis::COMPLETE_AUTO_DRIVE ||
      driving_mode() == Chassis::AUTO_SPEED_ONLY) {
    set_driving_mode(Chassis::AUTO_SPEED_ONLY);
    AINFO << "Already in AUTO_SPEED_ONLY mode";
    return ErrorCode::OK;
  }
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  // TODO(ALL): CHECK YOUR VEHICLE WHETHER SUPPORT THIS MODE OR NOT
  // set enable
  %(brake_command_protocol_name)s_->set_%(brake_command_enable_name)s(
      %(brake_command_protocol_name_cap)s::%(brake_command_enable_enable_enum)s);
  %(throttle_command_protocol_name)s_->set_%(throttle_command_enable_name)s(
      %(throttle_command_protocol_name_cap)s::%(throttle_command_enable_enable_enum)s);
  %(steer_command_protocol_name)s_->set_%(steer_command_enable_name)s(
      %(steer_command_protocol_name_cap)s::%(steer_command_enable_disable_enum)s);

  can_sender_->Update();
  if (!CheckResponse(CHECK_RESPONSE_SPEED_UNIT_FLAG, true)) {
    AERROR << "Failed to switch to AUTO_SPEED_ONLY mode.";
    Emergency();
    set_chassis_error_code(Chassis::CHASSIS_ERROR);
    return ErrorCode::CANBUS_ERROR;
  }
  set_driving_mode(Chassis::AUTO_SPEED_ONLY);
  AINFO << "Switch to AUTO_SPEED_ONLY mode ok.";
  return ErrorCode::OK;
  */
  return ErrorCode::OK;
}

// NEUTRAL, REVERSE, DRIVE
void %(car_type_cap)sController::Gear(Chassis::GearPosition gear_position) {
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE &&
      driving_mode() != Chassis::AUTO_SPEED_ONLY) {
    AINFO << "This drive mode no need to set gear.";
    return;
  }
  switch (gear_position) {
    case Chassis::GEAR_NEUTRAL: {
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_neutral_enum)s);
      break;
    }
    case Chassis::GEAR_REVERSE: {
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_reverse_enum)s);
      break;
    }
    case Chassis::GEAR_DRIVE: {
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_drive_enum)s);
      break;
    }
    case Chassis::GEAR_PARKING: {
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_park_enum)s);
      break;
    }
    case Chassis::GEAR_INVALID: {
      // AERROR << "Gear command is invalid!";
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_neutral_enum)s);
      break;
    }
    default: {
      %(gear_command_protocol_name)s_->set_%(gear_command_name)s(%(gear_command_protocol_name_cap)s::%(gear_command_neutral_enum)s);
      break;
    }
  }
}

// brake with pedal
// pedal:0.00~99.99, unit:percentage
void %(car_type_cap)sController::Brake(double pedal) {
  // double real_value = vehicle_params_.max_acceleration() * acceleration / 100;
  // TODO(All) :  Update brake value based on mode
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE &&
      driving_mode() != Chassis::AUTO_SPEED_ONLY) {
    AINFO << "The current drive mode does not need to set brake pedal.";
    return;
  }
  %(brake_command_protocol_name)s_->set_%(brake_command_name)s(pedal);
}

// drive with pedal
// pedal:0.0~99.9 unit:percentage
void %(car_type_cap)sController::Throttle(double pedal) {
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE &&
      driving_mode() != Chassis::AUTO_SPEED_ONLY) {
    AINFO << "The current drive mode does not need to set throttle pedal.";
    return;
  }
  %(throttle_command_protocol_name)s_->set_%(throttle_command_name)s(pedal);
}

// confirm the car is driven by acceleration command instead of
// throttle/brake pedal drive with acceleration/deceleration acc:-7.0 ~ 5.0,
// unit:m/s^2
void %(car_type_cap)sController::Acceleration(double acc) {
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE ||
      driving_mode() != Chassis::AUTO_SPEED_ONLY) {
    AINFO << "The current drive mode does not need to set acceleration.";
    return;
  }
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  // TODO(ALL): CHECK YOUR VEHICLE WHETHER SUPPORT THIS DRIVE MODE
  */
}

// %(car_type_lower)s default, +470 ~ -470 or other, left:+, right:-
// need to be compatible with control module, so reverse
// steering with steering angle
// angle:99.99~0.00~-99.99, unit:deg, left:+, right:-
void %(car_type_cap)sController::Steer(double angle) {
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE &&
      driving_mode() != Chassis::AUTO_STEER_ONLY) {
    AINFO << "The current driving mode does not need to set steer.";
    return;
  }
  const double real_angle =
      vehicle_params_.max_steer_angle() / M_PI * 180 * angle / 100.0;
  %(steer_command_protocol_name)s_->set_%(steer_command_name)s(real_angle);
  // reverse sign
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  steering_64_->set_steering_angle(real_angle)->set_steering_angle_speed(200);
  */
}

// %(car_type_lower)s default, steering with new angle speed
// angle:99.99~0.00~-99.99, unit:deg, left:+, right:-
// angle_spd:0.00~99.99, unit:deg/s
void %(car_type_cap)sController::Steer(double angle, double angle_spd) {
  if (driving_mode() != Chassis::COMPLETE_AUTO_DRIVE &&
      driving_mode() != Chassis::AUTO_STEER_ONLY) {
    AINFO << "The current driving mode does not need to set steer.";
    return;
  }
  const double real_angle =
      vehicle_params_.max_steer_angle() / M_PI * 180 * angle / 100.0;
  %(steer_command_protocol_name)s_->set_%(steer_command_name)s(real_angle);
}

void %(car_type_cap)sController::SetEpbBreak(const ControlCommand& command) {
  if (command.parking_brake()) {
    // None
  } else {
    // None
  }
}

void %(car_type_cap)sController::SetBeam(const VehicleSignal& vehicle_signal) {
  if (vehicle_signal.high_beam()) {
    // None
  } else if (vehicle_signal.low_beam()) {
    // None
  } else {
    // None
  }
}

void %(car_type_cap)sController::SetHorn(const VehicleSignal& vehicle_signal) {
  if (vehicle_signal.horn()) {
    // None
  } else {
    // None
  }
}

void %(car_type_cap)sController::SetTurningSignal(const VehicleSignal& vehicle_signal) {
  // Set Turn Signal
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  auto signal = vehicle_signal.turn_signal();
  if (signal == common::VehicleSignal::TURN_LEFT) {
    turnsignal_68_->set_turn_left();
  } else if (signal == common::VehicleSignal::TURN_RIGHT) {
    turnsignal_68_->set_turn_right();
  } else {
    turnsignal_68_->set_turn_none();
  }
  */
}

ErrorCode ChController::HandleCustomOperation(
    const external_command::ChassisCommand& command) {
  return ErrorCode::OK;
}

bool %(car_type_cap)sController::VerifyID() {
  if (!CheckVin()) {
    AERROR << "Failed to get the vin. Get vin again.";
    GetVin();
    return false;
  } else {
    ResetVin();
    return true;
  }
}

bool %(car_type_cap)sController::CheckVin() {
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  if (chassis_.vehicle_id().vin().size() >= 7) {
    AINFO << "Vin check success! Vehicel vin is "
          << chassis_.vehicle_id().vin();
    return true;
  } else {
    AINFO << "Vin check failed! Current vin size is "
          << chassis_.vehicle_id().vin().size();
    return false;
  }
  */
  return false;
}

void %(car_type_cap)sController::GetVin() {
  // Get vin from vehicle if exist
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  vehicle_mode_command_116_->set_vin_req_cmd(
      Vehicle_mode_command_116::VIN_REQ_CMD_VIN_REQ_ENABLE);
  AINFO << "Get vin";
  can_sender_->Update();
  */
}

void ChController::ResetVin() {
  // Reset vin from vehicle if exist
  /* ADD YOUR OWN CAR CHASSIS OPERATION
  vehicle_mode_command_116_->set_vin_req_cmd(
      Vehicle_mode_command_116::VIN_REQ_CMD_VIN_REQ_DISABLE);
  AINFO << "Reset vin";
  can_sender_->Update();
  */
}

void %(car_type_cap)sController::ResetProtocol() {
  message_manager_->ResetSendMessages();
}

bool %(car_type_cap)sController::CheckChassisError() {
  if (!chassis_.has_check_response()) {
    AERROR_EVERY(100) << "ChassisDetail has no %(car_type_lower)s vehicle info."
                      << chassis_.DebugString();
    return false;
  }

  /* ADD YOUR OWN CAR CHASSIS OPERATION
  // steer fault
  // drive fault
  // brake fault
  */
  return false;
}

void %(car_type_cap)sController::SecurityDogThreadFunc() {
  int32_t vertical_ctrl_fail = 0;
  int32_t horizontal_ctrl_fail = 0;

  if (can_sender_ == nullptr) {
    AERROR << "Failed to run SecurityDogThreadFunc() because can_sender_ is "
              "nullptr.";
    return;
  }
  while (!can_sender_->IsRunning()) {
    std::this_thread::yield();
  }

  std::chrono::duration<double, std::micro> default_period{50000};
  int64_t start = 0;
  int64_t end = 0;
  while (can_sender_->IsRunning()) {
    start = ::apollo::cyber::Time::Now().ToMicrosecond();
    const Chassis::DrivingMode mode = driving_mode();
    bool emergency_mode = false;

    // 1. horizontal control check
    if ((mode == Chassis::COMPLETE_AUTO_DRIVE ||
         mode == Chassis::AUTO_STEER_ONLY) &&
        !CheckResponse(CHECK_RESPONSE_STEER_UNIT_FLAG, false)) {
      ++horizontal_ctrl_fail;
      if (horizontal_ctrl_fail >= kMaxFailAttempt) {
        emergency_mode = true;
        AERROR << "Driving_mode is into emergency by steer manual intervention";
        set_chassis_error_code(Chassis::MANUAL_INTERVENTION);
      }
    } else {
      horizontal_ctrl_fail = 0;
    }

    // 2. vertical control check
    if ((mode == Chassis::COMPLETE_AUTO_DRIVE ||
         mode == Chassis::AUTO_SPEED_ONLY) &&
        !CheckResponse(CHECK_RESPONSE_SPEED_UNIT_FLAG, false)) {
      ++vertical_ctrl_fail;
      if (vertical_ctrl_fail >= kMaxFailAttempt) {
        emergency_mode = true;
        AERROR << "Driving_mode is into emergency by speed manual intervention";
        set_chassis_error_code(Chassis::MANUAL_INTERVENTION);
      }
    } else {
      vertical_ctrl_fail = 0;
    }
    if (CheckChassisError()) {
      set_chassis_error_code(Chassis::CHASSIS_ERROR);
      emergency_mode = true;
    }

    if (emergency_mode && mode != Chassis::EMERGENCY_MODE) {
      set_driving_mode(Chassis::EMERGENCY_MODE);
      message_manager_->ResetSendMessages();
      can_sender_->Update();
    }
    end = ::apollo::cyber::Time::Now().ToMicrosecond();
    std::chrono::duration<double, std::micro> elapsed{end - start};
    if (elapsed < default_period) {
      std::this_thread::sleep_for(default_period - elapsed);
    } else {
      AERROR << "Too much time consumption in %(car_type_cap)sController looping process:"
             << elapsed.count();
    }
  }
}

bool %(car_type_cap)sController::CheckResponse(const int32_t flags, bool need_wait) {
  int32_t retry_num = 20;
  bool is_eps_online = false;
  bool is_vcu_online = false;
  bool is_esp_online = false;

  do {
    bool check_ok = true;
    if (flags & CHECK_RESPONSE_STEER_UNIT_FLAG) {
      is_eps_online = chassis_.has_check_response() &&
                      chassis_.check_response().has_is_eps_online() &&
                      chassis_.check_response().is_eps_online();
      check_ok = check_ok && is_eps_online;
    }

    if (flags & CHECK_RESPONSE_SPEED_UNIT_FLAG) {
      is_vcu_online = chassis_.has_check_response() &&
                      chassis_.check_response().has_is_vcu_online() &&
                      chassis_.check_response().is_vcu_online();
      is_esp_online = chassis_.has_check_response() &&
                      chassis_.check_response().has_is_esp_online() &&
                      chassis_.check_response().is_esp_online();
      check_ok = check_ok && is_vcu_online && is_esp_online;
    }
    if (check_ok) {
      return true;
    } else {
      AINFO << "Need to check response again.";
    }
    if (need_wait) {
      --retry_num;
      std::this_thread::sleep_for(
          std::chrono::duration<double, std::milli>(20));
    }
  } while (need_wait && retry_num);

  AERROR << "check_response fail: is_eps_online:" << is_eps_online
        << ", is_vcu_online:" << is_vcu_online
        << ", is_esp_online:" << is_esp_online;

  return false;
}

void %(car_type_cap)sController::set_chassis_error_mask(const int32_t mask) {
  std::lock_guard<std::mutex> lock(chassis_mask_mutex_);
  chassis_error_mask_ = mask;
}

int32_t %(car_type_cap)sController::chassis_error_mask() {
  std::lock_guard<std::mutex> lock(chassis_mask_mutex_);
  return chassis_error_mask_;
}

Chassis::ErrorCode %(car_type_cap)sController::chassis_error_code() {
  std::lock_guard<std::mutex> lock(chassis_error_code_mutex_);
  return chassis_error_code_;
}

void %(car_type_cap)sController::set_chassis_error_code(
    const Chassis::ErrorCode& error_code) {
  std::lock_guard<std::mutex> lock(chassis_error_code_mutex_);
  chassis_error_code_ = error_code;
}

}  // namespace %(car_type_lower)s
}  // namespace canbus
}  // namespace apollo
