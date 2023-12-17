#include "map.hpp"
#include "exceptions.hpp"
#include "validate.hpp"
#include <iterator>
#include <jwt-cpp/jwt.h>
#include <vector>

std::string jwt::decide(std::string const& token,
                        std::string const& preferred_group,
                        database::DataBase& db_connection,
                        YAML::Node const& configuration)
{
  if (jwt::validate(token, db_connection) == false) {
    throw except::InvalidToken();
  }

  auto const decoded_jwt = jwt::decode(token);
  auto const iss = decoded_jwt.get_issuer();

  if (!configuration["policies"]["allow_untrusted_issuer"].as<bool>()) {
    auto trusted_issuers = configuration["policies"]["trusted_issuers"]
                               .as<std::vector<std::string>>();

    if (std::find(trusted_issuers.begin(), trusted_issuers.end(), iss) ==
        trusted_issuers.end()) {
      throw except::UntrustedIssuer(iss);
    }
  }

  auto const sub = decoded_jwt.get_subject();
  auto const claims = decoded_jwt.get_payload_claims();

  auto extract_array_claim = [&claims](std::string const& key) {
    std::vector<std::string> v;

    auto const it = claims.find(key);
    if (it != claims.end()) {
      auto const array = it->second.as_array();
      for (auto&& elem : array) {
        v.push_back(elem.get<std::string>());
      }
    }

    return v;
  };

  auto const groups = extract_array_claim("groups");
  auto const wlcg_groups = extract_array_claim("wlcg.groups");

  if (groups.empty() && wlcg_groups.empty()) {
    throw except::MissingClaims("group and wlcg.group");
  }

  std::string group;

  do {
    if (!preferred_group.empty()) {
      auto const group_it =
          std::find(groups.begin(), groups.end(), preferred_group);

      if (group_it != groups.end()) {
        group = *group_it;
        break;
      }

      auto const wlcg_group_it = std::find(
          wlcg_groups.begin(), wlcg_groups.end(), preferred_group);

      if (wlcg_group_it != wlcg_groups.end()) {
        group = *wlcg_group_it;
        break;
      }

      throw except::InvalidRequestedGroup(preferred_group);
    }

    if (!groups.empty()) {
      group = groups.front();
      break;
    }

    if (!wlcg_groups.empty()) {
      group = wlcg_groups.front();
      break;
    }
  } while (0);

  if (group.empty()) {
    return group;
  }

  return db_connection.get_user(iss, sub, group);
}
