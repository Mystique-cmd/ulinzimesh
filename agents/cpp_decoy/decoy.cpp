#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>

static std::string env(const std::string &key, const std::string &def) {
    const char *v = getenv(key.c_str());
    return v ? std::string(v) : def;
}

/* Simple HTTP POST using BSD sockets */
static bool http_post(const std::string &url, const std::string &json_body) {
    /* Parse URL: http://host:port/path */
    std::string host, path;
    int port = 9090;

    std::string u = url;
    if (u.find("http://") == 0) u = u.substr(7);

    auto slash = u.find('/');
    if (slash == std::string::npos) {
        host = u;
        path = "/";
    } else {
        host = u.substr(0, slash);
        path = u.substr(slash);
    }

    auto colon = host.find(':');
    if (colon != std::string::npos) {
        port = std::stoi(host.substr(colon + 1));
        host = host.substr(0, colon);
    }

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return false;

    struct hostent *server = gethostbyname(host.c_str());
    if (!server) { close(sock); return false; }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    memcpy(&addr.sin_addr.s_addr, server->h_addr, server->h_length);
    addr.sin_port = htons(port);

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return false;
    }

    std::string req =
        "POST " + path + " HTTP/1.1\r\n"
        "Host: " + host + ":" + std::to_string(port) + "\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: " + std::to_string(json_body.size()) + "\r\n"
        "Connection: close\r\n"
        "\r\n" +
        json_body;

    send(sock, req.c_str(), req.size(), 0);

    /* Read response (just drain it) */
    char buf[1024];
    while (recv(sock, buf, sizeof(buf), 0) > 0);
    close(sock);
    return true;
}

int main(int argc, char *argv[]) {
    int port = (argc > 1) ? std::atoi(argv[1]) : 2222;
    std::string collector_url = env("COLLECTOR_URL", "http://127.0.0.1:9090/ingest/flow");
    std::string hostname = env("HOSTNAME", "unknown");

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return 1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if (bind(server_fd, (sockaddr*)&address, sizeof(address)) < 0) {
        perror("bind");
        return 1;
    }

    if (listen(server_fd, 10) < 0) {
        perror("listen");
        return 1;
    }

    std::cout << "Decoy listening on port " << port
              << ", posting to " << collector_url << std::endl;

    while (true) {
        sockaddr_in client{};
        socklen_t len = sizeof(client);
        int client_fd = accept(server_fd, (sockaddr*)&client, &len);
        if (client_fd < 0) continue;

        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client.sin_addr, ip, sizeof(ip));

        std::string json =
            "{"
            "\"hostname\":\"" + hostname + "\","
            "\"platform\":\"linux\","
            "\"decoy_type\":\"ssh\","
            "\"port\":" + std::to_string(port) + ","
            "\"actor_ip\":\"" + std::string(ip) + "\","
            "\"timestamp\":\"" + std::to_string(time(nullptr)) + "\""
            "}";

        std::cout << json << std::endl;

        /* POST the interaction to the collector */
        http_post(collector_url, json);

        /* Send SSH-like banner to keep the interaction realistic */
        const char *banner = "SSH-2.0-OpenSSH_8.2p1\r\n";
        send(client_fd, banner, strlen(banner), 0);
        close(client_fd);
    }

    return 0;
}

