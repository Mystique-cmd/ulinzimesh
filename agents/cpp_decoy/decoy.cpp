#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main (int arg, char * argv[]){
    int port = (arg > 1) ? std :: atoi(argv[1]): 2222;

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socker");
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

std :: cout << "Decoy listening on port" << port << std :: endl;

while (true) {
    sockaddr_in client {};
    socklen_t len = sizeof(client);
    int client_fd = accept(server_fd, (sockaddr*)&client, &len);
    if (client_fd < 0) continue;

    char ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client.sin_addr, ip, sizeof(ip));

    std :: string json = "{"
    "\"decoy_type\":\"ssh\","
    "\"port\":" + std :: to_string(port) + ","
    "\"actor_ip\":" + std :: string(ip) + "\","
    "\"timestamp\":\"" + std :: to_string(time(nullptr)) + "\""
 + "}";

 std :: cout << json << std :: endl;

 const char * banner = "SSH-2.0-OpenSSH_8.2p1\r\n";
 send(client_fd, banner, strlen(banner), 0);
 close(client_fd);
}
return 0;
}
