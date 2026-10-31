#include <iostream>
#include <sys/neutrino.h>
#include <sys/syspage.h>

int main()
{
    std::cout << "Hello from QNX " << _NTO_VERSION / 100 << "." << (_NTO_VERSION / 10) % 10
              << "." << _NTO_VERSION % 10 << ", " << _syspage_ptr->num_cpu << " CPU(s)" << std::endl;
    return 0;
}
