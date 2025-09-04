//
//  CF_gcs_udp.h
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/09/25.
//

#ifndef CF_gcs_udp_h
#define CF_gcs_udp_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if defined(__APPLE__) || defined(__linux__) || defined(__unix__)

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

typedef struct {
    int socket_fd;
    struct sockaddr_in server_addr;
    bool is_connected;
} CF_GCSUDP_t;

typedef void (*discovery_callback_t)(const char* ip_address);
typedef void (*data_received_callback_t)(const uint8_t* data, size_t length);

bool CF_gcs_udp_init(CF_GCSUDP_t* client);
bool CF_gcs_udp_discover_drone(int port, int timeout_ms, char* ip_out, size_t ip_size);
bool CF_gcs_udp_connect(CF_GCSUDP_t* client, const char* drone_ip, int port);
bool CF_gcs_udp_send(CF_GCSUDP_t* client, const uint8_t* data, size_t length);
int CF_gcs_udp_receive(CF_GCSUDP_t* client, uint8_t* buffer, size_t buffer_size);
void CF_gcs_udp_disconnect(CF_GCSUDP_t* client);

#else
#error "CF_gcs_udp only supports POSIX systems (iOS, macOS, Linux, Raspberry Pi)"
#endif

#endif /* CF_gcs_udp_h */
