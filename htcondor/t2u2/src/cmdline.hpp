#ifndef T2U2_CMDLINE_HPP
#define T2U2_CMDLINE_HPP

#include <map>
#include <string>

namespace cmdline {

std::map<std::string, std::string> parse(int argc, char const* const argv[]);

} // namespace cmdline

#endif // T2U2_CMDLINE_HPP
