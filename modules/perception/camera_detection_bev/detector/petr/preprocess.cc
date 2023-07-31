/******************************************************************************
 * Copyright 2020 The Apollo Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the License);
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/
#include "modules/perception/camera_detection_bev/detector/petr/preprocess.h"

#include "cyber/common/log.h"

namespace apollo {
namespace perception {
namespace camera {

void Resize(cv::Mat *img, int width, int height) {
  cv::resize(*img, *img, cv::Size(width, height));
}

void Crop(cv::Mat *img, int x, int y, int width, int height) {
  cv::Rect roi(x, y, width, height);
  *img = (*img)(roi);
}

void Normalize(const std::vector<float> &mean, const std::vector<float> &std,
               float scale, cv::Mat *im) {
  ACHECK(std.size() == 3);
  for (const auto std_value : std) {
    ACHECK(std_value != 0.0);
  }
  ACHECK(scale != 0.0);
  im->convertTo(*im, CV_32FC3, scale);
  for (int h = 0; h < im->rows; h++) {
    for (int w = 0; w < im->cols; w++) {
      im->at<cv::Vec3f>(h, w)[0] =
          (im->at<cv::Vec3f>(h, w)[0] - mean[0]) / std[0];
      im->at<cv::Vec3f>(h, w)[1] =
          (im->at<cv::Vec3f>(h, w)[1] - mean[1]) / std[1];
      im->at<cv::Vec3f>(h, w)[2] =
          (im->at<cv::Vec3f>(h, w)[2] - mean[2]) / std[2];
    }
  }
}

}  // namespace camera
}  // namespace perception
}  // namespace apollo
