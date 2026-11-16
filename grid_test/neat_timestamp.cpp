#include <ctime>
#include <iostream>

int main() {
    time_t timestamp;
    time(&timestamp);

    struct tm *t = localtime(&timestamp);
    char buf[64];
    strftime(buf, sizeof(buf), "%Y_%m_%d_%H_%M_%S", t);
    std::cout << buf << std::endl;
    return 0;
}   