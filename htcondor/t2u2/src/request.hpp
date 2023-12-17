#ifndef T2U2_REQUEST_HPP
#define T2U2_REQUEST_HPP

#include <string>
#include <utility>

namespace request {
std::pair<std::string, long> request(std::string const& url);
} // namespace request

#endif // T2U2_REQUEST_HPP
