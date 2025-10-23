#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
    #include <winsock2.h>
    #include <windows.h>
    #pragma comment(lib, "ws2_32.lib")
#else
    #include <unistd.h>
    #include <sys/utsname.h>
#endif

int main(void){
    char hostname[256] = "unknown";
    char platform[32] = "unknown";

#ifdef _WIN32
    DWORD size = sizeof(hostname);
    if (!GetComputerNameA(hostname,&size)) strcpy(hostname, "unknown");
    strcpy(platform, "Windows");
#else 
    if (gethostname(hostname, sizeof(hostname)) != 0 ) strcpy(hostname, "unknown");
    struct utsname uts;
    if (uname(&uts) == 0)
    {
        if (strstr(uts.sysname, "Linux")) strcpy (hostname, "linux");
        else if (strstr(uts.sysname, "Darwin")) strcpy (platform, "macos");
        else strncpy(platform, uts.sysname, sizeof(platform)-1);
        platform[sizeof(platform) - 1] = '\0';
    };
#endif

 // Dummy data — replace with real telemetry capture later
    const char *src_ip  = "10.0.0.5";
    int src_port        = 54321;
    const char *dst_ip  = "8.8.8.8";
    int dst_port        = 53;
    const char *proto   = "udp";
    const char *dir     = "egress";
    long bytes_tx       = 120;
    long bytes_rx       = 340;

    printf(
      "{\"hostname\":\"%s\",\"platform\":\"%s\","
      "\"src_ip\":\"%s\",\"src_port\":%d,"
      "\"dst_ip\":\"%s\",\"dst_port\":%d,"
      "\"protocol\":\"%s\",\"direction\":\"%s\","
      "\"bytes_tx\":%ld,\"bytes_rx\":%ld}\n",
      hostname, platform,
      src_ip, src_port,
      dst_ip, dst_port,
      proto, dir,
      bytes_tx, bytes_rx
    );
return 0;
}