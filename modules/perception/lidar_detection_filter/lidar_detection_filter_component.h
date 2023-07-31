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

#pragma once

#include <memory>
#include <string>

#include "modules/perception/lidar_detection_filter/proto/lidar_detection_filter_component_config.pb.h"

#include "cyber/component/component.h"
#include "modules/perception/common/onboard/inner_component_messages/lidar_inner_component_messages.h"
#include "modules/perception/lidar_detection_filter/object_filter_bank/object_filter_bank.h"

namespace apollo {
namespace perception {
namespace lidar {

using onboard::LidarFrameMessage;

class LidarDetectionFilterComponent final
    : public cyber::Component<LidarFrameMessage> {
 public:
  /**
   * @brief Construct a new Lidar Detection Filter Component object
   * 
   */
  LidarDetectionFilterComponent() = default;

  /**
   * @brief Destroy the Lidar Detection Filter Component object
   * 
   */
  virtual ~LidarDetectionFilterComponent() = default;

  /**
   * @brief Init of Lidar Detection Filter Component object
   * 
   * @return true 
   * @return false 
   */
  bool Init() override;

  /**
   * @brief Process of Lidar Detection Filter Component object
   * 
   * @param message lidar frame message
   * @return true 
   * @return false 
   */
  bool Proc(const std::shared_ptr<LidarFrameMessage>& message) override;

 private:
  bool InternalProc(const std::shared_ptr<LidarFrameMessage>& in_message);

 private:
  std::shared_ptr<cyber::Writer<LidarFrameMessage>> writer_;
  std::string output_channel_name_;
  bool use_object_filter_bank_;
  ObjectFilterBank filter_bank_;
};

CYBER_REGISTER_COMPONENT(LidarDetectionFilterComponent);

}  // namespace lidar
}  // namespace perception
}  // namespace apollo
