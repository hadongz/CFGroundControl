//
//  CF_gcs_mav_builder.c
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/09/25.
//

#include "CF_gcs_mav_builder.h"

size_t CF_gcs_build_heartbeat(uint8_t *buffer, size_t buffer_size)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_heartbeat_pack(GCS_SYSTEM_ID,
                               GCS_COMP_ID,
                               &msg,
                               MAV_TYPE_GCS,
                               MAV_AUTOPILOT_INVALID,
                               MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
                               0,
                               MAV_STATE_ACTIVE);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_arm_disarm(uint8_t *buffer, size_t buffer_size, bool is_armed)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_command_long_pack(GCS_SYSTEM_ID,
                                  GCS_COMP_ID,
                                  &msg,
                                  TARGET_SYSTEM_ID,
                                  TARGET_COMP_ID,
                                  MAV_CMD_COMPONENT_ARM_DISARM,
                                  0,
                                  is_armed ? 1.0f : 0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_calibrate_imu(uint8_t *buffer, size_t buffer_size)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_command_long_pack(GCS_SYSTEM_ID,
                                  GCS_COMP_ID,
                                  &msg,
                                  TARGET_SYSTEM_ID,
                                  TARGET_COMP_ID,
                                  MAV_CMD_PREFLIGHT_CALIBRATION,
                                  0,
                                  1.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_calibrate_baro(uint8_t *buffer, size_t buffer_size)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_command_long_pack(GCS_SYSTEM_ID,
                                  GCS_COMP_ID,
                                  &msg,
                                  TARGET_SYSTEM_ID,
                                  TARGET_COMP_ID,
                                  MAV_CMD_PREFLIGHT_CALIBRATION,
                                  0,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  1.0f,
                                  0.0f,
                                  0.0f);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_manual_control(uint8_t *buffer, size_t buffer_size,
                                   int16_t roll, int16_t pitch,
                                   int16_t yaw, int16_t throttle)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_manual_control_pack(GCS_SYSTEM_ID,
                                    GCS_COMP_ID,
                                    &msg,
                                    TARGET_SYSTEM_ID,
                                    roll,
                                    pitch,
                                    yaw,
                                    throttle,
                                    0,0,0,0,0,0,0,0,0,0,0);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_takeoff(uint8_t *buffer, size_t buffer_size)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_command_long_pack(GCS_SYSTEM_ID,
                                  GCS_COMP_ID,
                                  &msg,
                                  TARGET_SYSTEM_ID,
                                  TARGET_COMP_ID,
                                  MAV_CMD_NAV_TAKEOFF,
                                  0,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f,
                                  0.0f);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_param_list(uint8_t *buffer, size_t buffer_size)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    mavlink_message_t msg;
    mavlink_msg_param_request_list_pack(GCS_SYSTEM_ID,
                                        GCS_COMP_ID,
                                        &msg,
                                        TARGET_SYSTEM_ID,
                                        TARGET_COMP_ID);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}

size_t CF_gcs_build_set_param(uint8_t *buffer, size_t buffer_size, const char *param_id, float param_value)
{
    if (!buffer || buffer_size < MAVLINK_MAX_PACKET_LEN)
    {
        return 0;
    }
    
    char param_id_16[16] = {0};
    size_t len = strlen(param_id);
    if (len >= 16) {
        memcpy(param_id_16, param_id, 16);
    } else {
        strcpy(param_id_16, param_id);
    }

    mavlink_message_t msg;
    mavlink_msg_param_set_pack(GCS_SYSTEM_ID,
                               GCS_COMP_ID,
                               &msg,
                               TARGET_SYSTEM_ID,
                               TARGET_COMP_ID,
                               param_id_16,
                               param_value,
                               MAV_PARAM_TYPE_REAL32);
    
    size_t length = mavlink_msg_to_send_buffer(buffer, &msg);
    return length;
}
