#include "db.hpp"
#include "exceptions.hpp"
#include <algorithm>
#include <cerrno>
#include <cstring>
#include <fstream>
#include <stdexcept>

std::string const database::DataBase::NOT_FOUND;

std::ostream& operator<<(std::ostream& out, database::Account const& a)
{
  auto constexpr sep = ' ';
  return out << a.iss << sep << a.sub << sep << a.group << sep << a.user
             << '\n';
}

std::istream& operator>>(std::istream& in, database::Account& a)
{
  return in >> a.iss >> a.sub >> a.group >> a.user;
}

void database::DataBase::load()
{
  if (!exists(m_dbfile)) {
    return;
  }

  std::ifstream file(m_dbfile);

  if (!file) {
    auto const e = errno;
    throw except::InvalidDbFile("Error opening file \"" +
                                m_dbfile.string() +
                                "\" for reading: " + std::strerror(e));
  }

  std::string line;
  std::vector<Account> db;

  while (file && file.peek() != EOF) {
    Account entry;
    file >> entry;
    db.push_back(entry);
  }

  std::lock_guard<std::recursive_mutex> guard(m_users_mx);
  m_users.swap(db);
}

void database::DataBase::save()
{
  if (!m_dbfile.empty()) {
    auto const tmpfname =
        std::filesystem::path(m_dbfile.string() + ".tmp");

    std::ofstream file(tmpfname);

    if (!file) {
      auto const e = errno;
      throw except::InvalidDbFile("Error opening file \"" +
                                  tmpfname.string() +
                                  "\" for writing: " + std::strerror(e));
    }

    {
      std::lock_guard<std::recursive_mutex> guard(m_users_mx);

      for (auto&& entry : m_users) {
        file << entry;
      }
    }

    std::error_code ec;
    std::filesystem::rename(tmpfname, m_dbfile, ec);

    if (ec) {
      throw except::InvalidDbFile("Error opening file \"" +
                                  m_dbfile.string() +
                                  "\" for writing: " + ec.message());
    }
  }
}

database::DataBase::DataBase(std::vector<Policy> const& policies)
    : m_policies(policies)
{}

database::DataBase::DataBase(std::vector<Policy> const& policies,
                             std::filesystem::path const& file)
    : m_dbfile(file)
    , m_policies(policies)
{
  load();
  save();
}

database::DataBase::~DataBase()
{
  save();
}

std::string database::DataBase::get_user(std::string const& iss,
                                         std::string const& sub,
                                         std::string const& group)
{
  std::lock_guard<std::recursive_mutex> guard(m_users_mx);

  // search an already mapped user in the DB matching the request
  auto const it = std::find_if(
      m_users.begin(), m_users.end(), [&](Account const& acc) {
        return acc.iss == iss && acc.sub == sub && acc.group == group;
      });

  if (it != m_users.end()) {
    return it->user;
  }

  // search a matching policy
  auto const policy_it = std::find_if(
      m_policies.begin(), m_policies.end(),
      [&group](Policy const& p) { return p.group == group; });

  if (policy_it != m_policies.end()) {
    // search a free user
    for (auto&& user : policy_it->users) {
      auto const acc_it = std::find_if(
          m_users.begin(), m_users.end(),
          [&user](Account const& acc) { return acc.user == user; });

      if (acc_it == m_users.end()) {
        m_users.push_back(Account {iss, sub, group, user});
        save();
        return user;
      }
    }

    // if is possible to reuse users take the first in the policy
    if (policy_it->reuse_users) {
      auto const& user = policy_it->users.front();
      m_users.push_back(Account {iss, sub, group, user});
      save();
      return user;
    }
  } else {
    throw except::NoPolicyMatch();
  }

  throw except::UsersExhausted();
}

void database::DataBase::put_pub_key(std::string const& iss,
                                     std::string const& kid,
                                     std::string const& pub)
{
  std::lock_guard<std::mutex> guard(m_keys_mx);

  auto const it =
      std::find_if(m_keys.begin(), m_keys.end(), [&](Key const& key) {
        return key.iss == iss && key.kid == kid;
      });

  if (it != m_keys.end()) {
    m_keys.erase(it);
  }

  using namespace std::chrono_literals;
  auto const exp = std::chrono::system_clock::now() + 600s;

  m_keys.push_back(Key {iss, kid, pub, exp});
}

std::string database::DataBase::get_pub_key(std::string const& iss,
                                            std::string const& kid)
{
  std::lock_guard<std::mutex> guard(m_keys_mx);
  auto const it =
      std::find_if(m_keys.begin(), m_keys.end(), [&](Key const& key) {
        return key.iss == iss && key.kid == kid;
      });

  if (it != m_keys.end()) {
    auto const now = std::chrono::system_clock::now();
    if (now > it->exp) {
      m_keys.erase(it);
      return NOT_FOUND;
    }
    return it->pem;
  }

  return NOT_FOUND;
}

