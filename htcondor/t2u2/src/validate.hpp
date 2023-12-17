#ifndef T2U2_VALIDATE_HPP
#define T2U2_VALIDATE_HPP

#include "db.hpp"
#include <string>

namespace jwt {

bool validate(std::string const& token, database::DataBase& db);

} // namespace jwt

#endif // T2U2_VALIDATE_HPP
