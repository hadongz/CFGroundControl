//
//  CF_gcs_mav_builder.h
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/09/25.
//

#ifndef CF_gcs_mav_builder_h
#define CF_gcs_mav_builder_h

#include "mavlink/common/mavlink.h"

#define GCS_SYSTEM_ID 255
#define GCS_COMP_ID 25
#define TARGET_SYSTEM_ID 1
#define TARGET_COMP_ID 1

size_t CF_gcs_build_heartbeat(uint8_t *buffer, size_t buffer_size);
size_t CF_gcs_build_arm_disarm(uint8_t *buffer, size_t buffer_size, bool is_armed);
size_t CF_gcs_build_calibrate_imu(uint8_t *buffer, size_t buffer_size);
size_t CF_gcs_build_calibrate_baro(uint8_t *buffer, size_t buffer_size);
size_t CF_gcs_build_manual_control(uint8_t *buffer, size_t buffer_size,
                                   int16_t roll, int16_t pitch,
                                   int16_t yaw, int16_t throttle);
size_t CF_gcs_build_takeoff(uint8_t *buffer, size_t buffer_size);
size_t CF_gcs_build_param_list(uint8_t *buffer, size_t buffer_size);
size_t CF_gcs_build_set_param(uint8_t *buffer, size_t buffer_size, const char *param_id, float param_value);

#endif /* CF_gcs_mav_builder_h */
