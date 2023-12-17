#ifndef T2U2_DB_HPP
#define T2U2_DB_HPP

#include <chrono>
#include <filesystem>
#include <istream>
#include <mutex>
#include <ostream>
#include <string>
#include <vector>

namespace database {

struct Account
{
  std::string iss;
  std::string sub;
  std::string group;
  std::string user;
};

struct Key
{
  std::string iss;
  std::string kid;
  std::string pem;
  std::chrono::time_point<std::chrono::system_clock> exp;
};

struct Policy
{
  std::string group;
  std::vector<std::string> users;
  bool reuse_users;
};

class DataBase
{
  std::filesystem::path m_dbfile;
  std::vector<Policy> m_policies;
  std::vector<Account> m_users;
  std::vector<Key> m_keys;
  std::recursive_mutex m_users_mx;
  std::mutex m_keys_mx;

  void load();
  void save();

 public:
  explicit DataBase(std::vector<Policy> const& policies);
  DataBase(std::vector<Policy> const& policies,
           std::filesystem::path const& file);

  std::string get_user(std::string const& iss, std::string const& sub,
                       std::string const& group);

  void put_pub_key(std::string const& iss, std::string const& kid,
                   std::string const& pub);

  std::string get_pub_key(std::string const& iss, std::string const& kid);
  ~DataBase();

  std::string static const NOT_FOUND;
};

} // namespace database

#endif // T2U2_DB_HPP
