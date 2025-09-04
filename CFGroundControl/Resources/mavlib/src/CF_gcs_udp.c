//
//  CF_gcs_udp.c
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/09/25.
//

#if defined(__APPLE__) || defined(__linux__) || defined(__unix__)

#include "CF_gcs_udp.h"
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>

#ifdef __linux__
#include <linux/types.h>
#include <linux/errqueue.h>

#ifndef SO_PRIORITY
#define SO_PRIORITY 12
#endif

#endif

#ifdef __APPLE__
#include <sys/socket.h>

#ifndef SO_TRAFFIC_CLASS
#define SO_TRAFFIC_CLASS 0x1086
#endif

#ifndef SO_TC_CTL
#define SO_TC_CTL 0x02
#endif

#endif

bool CF_gcs_udp_init(CF_GCSUDP_t* client)
{
    if (!client) return false;
    
    memset(client, 0, sizeof(CF_GCSUDP_t));
    client->socket_fd = -1;
    client->is_connected = false;
    
    return true;
}

bool CF_gcs_udp_discover_drone(int port, int timeout_ms, char* ip_out, size_t ip_size)
{
    if (!ip_out || ip_size < INET_ADDRSTRLEN) {
        return false;
    }
    
    int discovery_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (discovery_sock < 0) {
        return false;
    }
    
    int reuse = 1;
    setsockopt(discovery_sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    struct timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;
    setsockopt(discovery_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    struct sockaddr_in bind_addr;
    memset(&bind_addr, 0, sizeof(bind_addr));
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = INADDR_ANY;
    bind_addr.sin_port = htons(port);
    
    if (bind(discovery_sock, (struct sockaddr*)&bind_addr, sizeof(bind_addr)) < 0) {
        close(discovery_sock);
        return false;
    }
    
    uint8_t buffer[1024];
    struct sockaddr_in sender_addr;
    socklen_t sender_len = sizeof(sender_addr);
    
    ssize_t bytes = recvfrom(discovery_sock, buffer, sizeof(buffer), 0,
                            (struct sockaddr*)&sender_addr, &sender_len);
    
    close(discovery_sock);
    
    if (bytes > 0 && (buffer[0] == 0xFE || buffer[0] == 0xFD)) {
        inet_ntop(AF_INET, &sender_addr.sin_addr, ip_out, (socklen_t)ip_size);
        return true;
    }
    
    return false;
}

bool CF_gcs_udp_connect(CF_GCSUDP_t* client, const char* drone_ip, int port)
{
    if (!client || !drone_ip) return false;
    
    client->socket_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (client->socket_fd < 0) {
        return false;
    }
    
    int flags = fcntl(client->socket_fd, F_GETFL, 0);
    if (fcntl(client->socket_fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        close(client->socket_fd);
        return false;
    }
    
    int reuse = 1;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    int rcvbuf = 2 * 1024 * 1024;
    int sndbuf = 256 * 1024;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
    setsockopt(client->socket_fd, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
    
    int nodelay = 1;
    setsockopt(client->socket_fd, IPPROTO_IP, IP_TOS, &nodelay, sizeof(nodelay));
    
    int tos = 0xB8;
    setsockopt(client->socket_fd, IPPROTO_IP, IP_TOS, &tos, sizeof(tos));
    
    #ifdef __linux__
    int priority = 6;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_PRIORITY, &priority, sizeof(priority));
    #endif

    #ifdef __APPLE__
    int traffic_class = SO_TC_CTL;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_TRAFFIC_CLASS, &traffic_class, sizeof(traffic_class));
    
    int nosigpipe = 1;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, sizeof(nosigpipe));
    #endif
    
    struct sockaddr_in local_addr;
    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_addr.s_addr = INADDR_ANY;
    local_addr.sin_port = htons(port);
    
    if (bind(client->socket_fd, (struct sockaddr*)&local_addr, sizeof(local_addr)) < 0) {
        close(client->socket_fd);
        return false;
    }
    
    memset(&client->server_addr, 0, sizeof(client->server_addr));
    client->server_addr.sin_family = AF_INET;
    client->server_addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, drone_ip, &client->server_addr.sin_addr) <= 0) {
        close(client->socket_fd);
        return false;
    }
    
    client->is_connected = true;
    
    return true;
}

bool CF_gcs_udp_send(CF_GCSUDP_t* client, const uint8_t* data, size_t length)
{
    if (!client || !client->is_connected || !data || length == 0) {
        return false;
    }
    
    ssize_t sent = sendto(client->socket_fd, data, length, 0, (struct sockaddr*)&client->server_addr, sizeof(client->server_addr));
    
    return sent == (ssize_t)length;
}

int CF_gcs_udp_receive(CF_GCSUDP_t* client, uint8_t* buffer, size_t buffer_size)
{
    if (!client || !client->is_connected || !buffer || buffer_size == 0) {
        return -1;
    }
    
    struct sockaddr_in sender;
    socklen_t sender_len = sizeof(sender);
    
    ssize_t bytes = recvfrom(client->socket_fd, buffer, buffer_size, 0,
                            (struct sockaddr*)&sender, &sender_len);
    
    if (bytes > 0) {
        return sender.sin_addr.s_addr != client->server_addr.sin_addr.s_addr ? 0 : (int)bytes;
    } else if (bytes == 0) {
        return 0;
    } else {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        } else {
            return -1;
        }
    }
}

void CF_gcs_udp_disconnect(CF_GCSUDP_t* client)
{
    if (!client) return;
    
    if (client->socket_fd >= 0) {
        close(client->socket_fd);
        client->socket_fd = -1;
    }
    
    client->is_connected = false;
}

#endif
