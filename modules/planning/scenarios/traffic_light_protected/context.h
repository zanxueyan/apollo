/******************************************************************************
 * Copyright 2019 The Apollo Authors. All Rights Reserved.
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
/**
 * @file context.h
 */
#pragma once

#include <string>
#include <vector>

#include "modules/planning/scenarios/traffic_light_protected/proto/traffic_light_protected.pb.h"
#include "modules/planning/planning_base/scenario_base/scenario.h"

namespace apollo {
namespace planning {

struct TrafficLightProtectedContext : public ScenarioContext {
  ScenarioTrafficLightProtectedConfig scenario_config;
  std::vector<std::string> current_traffic_light_overlap_ids;
};

}  // namespace planning
}  // namespace apollo
