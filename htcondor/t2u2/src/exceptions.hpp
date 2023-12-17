#ifndef T2U2_EXCEPTIONS_HPP
#define T2U2_EXCEPTIONS_HPP

#include <stdexcept>

namespace except {

class UntrustedIssuer : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class ConnectionToIssuer : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class InvalidToken : public std::exception
{};

class InvalidRequestedGroup : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class Unauthenticated : public std::exception
{};

class MissingClaims : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class InvalidConfig : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class InvalidCmdline : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class InvalidDbFile : public std::runtime_error
{
  using std::runtime_error::runtime_error;
};

class NoPolicyMatch : public std::exception
{};

class UsersExhausted : public std::exception
{};

} // namespace except

#endif // T2U2_EXCEPTIONS_HPP
