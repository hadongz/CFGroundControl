//
//  CF_gcs_parser.h
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/09/25.
//

#ifndef CF_gcs_parser_h
#define CF_gcs_parser_h

#include <stdio.h>

#include "mavlink/common/mavlink.h"

typedef void (*heartbeat_callback_t)(bool is_armed, uint8_t vehicle_type, uint8_t autopilot,
                                     uint32_t custom_mode, uint8_t system_status);
typedef void (*attitude_callback_t)(float roll_deg, float pitch_deg, float yaw_deg,
                                    float roll_rate, float pitch_rate, float yaw_rate);
typedef void (*position_callback_t)(double lat, double lon, float alt_m, float relative_alt_m);
typedef void (*status_text_callback_t)(const char* text, uint8_t severity);
typedef void (*param_value_callback_t)(const char* param_id, float param_value);

typedef struct {
    heartbeat_callback_t on_heartbeat;
    attitude_callback_t on_attitude;
    position_callback_t on_position;
    status_text_callback_t on_status_text;
    param_value_callback_t on_param_value;
} CF_GCSCallback_t;

void CF_gcs_parser_init(CF_GCSCallback_t *callbacks);
void CF_gcs_parser_process(const uint8_t *buffer, size_t length);

#endif /* CF_gcs_parser */
