//
//  CF_mav_parser.c
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/09/25.
//

#include "CF_gcs_parser.h"

static CF_GCSCallback_t g_callbacks;

static void handle_message(const mavlink_message_t *msg);

void CF_gcs_parser_init(CF_GCSCallback_t *callbacks)
{
    g_callbacks = *callbacks;
}

void CF_gcs_parser_process(const uint8_t *buffer, size_t length)
{
    mavlink_message_t msg;
    mavlink_status_t status;
    
    for (size_t i = 0; i < length; i++)
    {
        if (mavlink_parse_char(MAVLINK_COMM_0, buffer[i], &msg, &status))
        {
            handle_message(&msg);
        }
    }
}

/* ============ PRIVATE IMPLEMENTATION ============ */

static void handle_message(const mavlink_message_t* msg) {
    switch (msg->msgid) {
        case MAVLINK_MSG_ID_HEARTBEAT:
        {
            mavlink_heartbeat_t heartbeat;
            mavlink_msg_heartbeat_decode(msg, &heartbeat);
            
            bool is_armed = (heartbeat.base_mode & MAV_MODE_FLAG_SAFETY_ARMED) != 0;
            
            if (g_callbacks.on_heartbeat)
            {
                g_callbacks.on_heartbeat(is_armed, heartbeat.type, heartbeat.autopilot,
                                         heartbeat.custom_mode, heartbeat.system_status);
            }
            break;
        }
        
        case MAVLINK_MSG_ID_ATTITUDE:
        {
            mavlink_attitude_t attitude;
            mavlink_msg_attitude_decode(msg, &attitude);
            
            float roll_deg = attitude.roll * 180.0f / M_PI;
            float pitch_deg = attitude.pitch * 180.0f / M_PI;
            float yaw_deg = attitude.yaw * 180.0f / M_PI;
            
            if (g_callbacks.on_attitude)
            {
                g_callbacks.on_attitude(roll_deg, pitch_deg, yaw_deg,
                                        attitude.rollspeed, attitude.pitchspeed, attitude.yawspeed);
            }
            
            break;
        }
        
        case MAVLINK_MSG_ID_STATUSTEXT:
        {
            mavlink_statustext_t status_text;
            mavlink_msg_statustext_decode(msg, &status_text);
            
            if (g_callbacks.on_status_text)
            {
                g_callbacks.on_status_text(status_text.text, status_text.severity);
            }
            
            break;
        }
        
        case MAVLINK_MSG_ID_GLOBAL_POSITION_INT:
        {
            mavlink_global_position_int_t position;
            mavlink_msg_global_position_int_decode(msg, &position);
            
            double lat = position.lat / 1e7;
            double lon = position.lon / 1e7;
            float alt_m = position.alt / 1000.0f;
            float rel_alt_m = position.relative_alt / 1000.0f;
            
            if (g_callbacks.on_position)
            {
                g_callbacks.on_position(lat, lon, alt_m, rel_alt_m);
            }
            
            break;
        }
            
        case MAVLINK_MSG_ID_PARAM_VALUE:
        {
            mavlink_param_value_t param;
            mavlink_msg_param_value_decode(msg, &param);
            if (param.param_type != MAV_PARAM_TYPE_REAL32) break;
            
            if (g_callbacks.on_param_value)
            {
                g_callbacks.on_param_value(param.param_id, param.param_value);
            }
            break;
        }
        default:
            break;
    }
}
