/******************************************************************************
 * Copyright 2017 The Apollo Authors. All Rights Reserved.
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
 * @file
 */

#pragma once

#include <memory>
#include <string>
#include <vector>

#include <boost/thread/locks.hpp>
#include <boost/thread/shared_mutex.hpp>

#include "absl/strings/str_cat.h"

#include "modules/common_msgs/task_manager_msgs/task_manager.pb.h"
#include "modules/common_msgs/external_command_msgs/lane_follow_command.pb.h"
#include "modules/common_msgs/external_command_msgs/valet_parking_command.pb.h"
#include "modules/common_msgs/external_command_msgs/action_command.pb.h"

#include "cyber/common/log.h"
#include "cyber/cyber.h"
#include "modules/dreamview/backend/handlers/websocket_handler.h"
#include "modules/dreamview/backend/map/map_service.h"
#include "modules/dreamview/backend/perception_camera_updater/perception_camera_updater.h"
#include "modules/dreamview/backend/plugins/plugin_manager.h"
#include "modules/common_msgs/localization_msgs/localization.pb.h"
#include "modules/dreamview/backend/sim_control_manager/sim_control_manager.h"
#include "modules/dreamview/backend/simulation_world/simulation_world_service.h"

/**
 * @namespace apollo::dreamview
 * @brief apollo::dreamview
 */
namespace apollo {
namespace dreamview {

/**
 * @class SimulationWorldUpdater
 * @brief A wrapper around SimulationWorldService and WebSocketHandler to keep
 * pushing SimulationWorld to frontend via websocket while handling the response
 * from frontend.
 */
class SimulationWorldUpdater {
 public:
  /**
   * @brief Constructor with the websocket handler.
   * @param websocket Pointer of the websocket handler that has been attached to
   * the server.
   * @param sim_control Pointer of sim control.
   * @param map_service Pointer of the map service to provide a high-level API
   * of hdmap.
   * @param routing_from_file whether to read initial routing from file.
   */
  SimulationWorldUpdater(WebSocketHandler *websocket, WebSocketHandler *map_ws,
                         WebSocketHandler *camera_ws,
                         SimControlManager *sim_control_manager,
                         WebSocketHandler *plugin_ws,
                         const MapService *map_service,
                         PerceptionCameraUpdater *perception_camera_updater,
                         PluginManager *plugin_manager,
                         bool routing_from_file = false);

  /**
   * @brief Starts to push simulation_world to frontend.
   */
  void Start();

  // Time interval, in milliseconds, between pushing SimulationWorld to
  // frontend.
  static constexpr double kSimWorldTimeIntervalMs = 100;

  double LastAdcTimestampSec() { return last_pushed_adc_timestamp_sec_; }

 private:
  /**
   * @brief The callback function to get updates from SimulationWorldService,
   * and update simulation_world_json_.
   */
  void OnTimer();

  /**
   * @brief The function to construct a LaneFollowCommand from the given json,
   * @param json that contains start, end, and waypoints
   * @param lane_follow_command
   * @return True if LaneFollowCommand is constructed successfully
   */
  bool ConstructLaneFollowCommand(
      const nlohmann::json &json,
      apollo::external_command::LaneFollowCommand *lane_follow_command);

  /**
   * @brief The function to construct a ValetParkingCommand from the given json,
   * @param json that contains parking info
   * @param valet_parking_command
   * @return True if ValetParkingCommand is constructed successfully
   */
  bool ConstructValetParkingCommand(
      const nlohmann::json &json,
      apollo::external_command::ValetParkingCommand *valet_parking_command);

  /**
   * @brief get json which construct routing request needs
   * @param json that contains start point,json that contains end point
   * @return json that contains start point,end point without waypoint
   */
  nlohmann::json GetConstructRoutingRequestJson(const nlohmann::json &start,
                                                const nlohmann::json &end);

  /**
   * @brief The function to construct a lane waypoint from the given json,
   * @param json that contains x, y, heading
   * @param lanewaypoint, description
   * @return True if lane waypoint is constructed successfully
   */
  bool ConstructLaneWayPoint(const nlohmann::json &point,
                             apollo::routing::LaneWaypoint *laneWayPoint,
                             std::string description);

  bool ValidateCoordinate(const nlohmann::json &json);

  /**
   * @brief Check if routing point is located on a lane that is CITY_DRIVING
   * @param json that contains point's coordinate x and y
   * @return True if the lane is CITY_DRIVING
   */
  nlohmann::json CheckRoutingPoint(const nlohmann::json &json);

  /**
   * @brief Tries to load the points of interest from the file if it has
   * not been.
   * @return False if failed to load from file,
   * true otherwise or if it's already loaded.
   */
  bool LoadPOI();
  /**
   * @brief get point from lanewaypoint in poi or default routings
   * @param lanewaypoint
   * @return json that contains point's coordinate x and y
   */
  nlohmann::json GetPointJsonFromLaneWaypoint(
      const apollo::routing::LaneWaypoint &waypoint);

  /**
   * @brief Tries to load the user-defined default routings from the txt file
   * @return False if failed to load from file,file doesn't exist
   * true otherwise or if it's already loaded.
   */
  bool LoadUserDefinedRoutings(const std::string &file_name,
                               google::protobuf::Message *message);

  /**
   * @brief Tries to save the points to a fixed location file
   * @param json that contains routing name and point's coordinate x and y
   * @return False if failed to save,
   * true otherwise or if it's already saved.
   */
  bool AddDefaultRouting(const nlohmann::json &json);

  void RegisterMessageHandlers();

  SimulationWorldService sim_world_service_;
  const MapService *map_service_ = nullptr;
  WebSocketHandler *websocket_ = nullptr;
  WebSocketHandler *map_ws_ = nullptr;
  WebSocketHandler *camera_ws_ = nullptr;
  WebSocketHandler *plugin_ws_ = nullptr;
  SimControlManager *sim_control_manager_ = nullptr;
  PerceptionCameraUpdater *perception_camera_updater_ = nullptr;

  // End point for requesting default route
  apollo::routing::POI poi_;

  // default routings
  apollo::routing::POI default_routings_;
  apollo::routing::Landmark *default_routing_;

  // park and go
  apollo::routing::POI park_go_routings_;

  // The simulation_world in wire format to be pushed to frontend, which is
  // updated by timer.
  std::string simulation_world_;
  std::string simulation_world_with_planning_data_;

  // Received relative map data in wire format.
  std::string relative_map_string_;

  // Mutex to protect concurrent access to simulation_world_json_.
  // NOTE: Use boost until we have std version of rwlock support.
  boost::shared_mutex mutex_;

  std::unique_ptr<cyber::Timer> timer_;

  volatile double last_pushed_adc_timestamp_sec_ = 0.0f;

  std::unique_ptr<PluginManager> plugin_manager_;

  uint64_t command_id_;
};

}  // namespace dreamview
}  // namespace apollo
