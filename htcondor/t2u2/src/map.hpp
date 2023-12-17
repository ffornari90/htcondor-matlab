#ifndef T2U2_MAP_HPP
#define T2U2_MAP_HPP

#include "config.hpp"
#include "db.hpp"
#include <string>

namespace jwt {

std::string decide(std::string const& token,
                   std::string const& preferred_group,
                   database::DataBase& db_connection,
                   YAML::Node const& configuration);

} // namespace jwt

#endif // T2U2_MAP_HPP
