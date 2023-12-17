#include "cmdline.hpp"
#include "config.hpp"
#include "db.hpp"
#include "exceptions.hpp"
#include "map.hpp"
#include "validate.hpp"
#include <crow.h>
#include <curl/curl.h>
#include <iostream>

crow::LogLevel to_log_level(std::string const& level)
{
  if (level == "debug") {
    return crow::LogLevel::Debug;
  }

  if (level == "info") {
    return crow::LogLevel::Info;
  }
  if (level == "warning") {
    return crow::LogLevel::Warning;
  }

  if (level == "error") {
    return crow::LogLevel::Error;
  }

  if (level == "critical") {
    return crow::LogLevel::Critical;
  }

  throw except::InvalidConfig(
      "invalid log level: " + level +
      "\nallowed values are: debug, info, warning, error, critical");
}

std::string token_from_header(std::string const& authorization_header)
{
  auto constexpr bearer = "Bearer ";
  auto constexpr len = strlen(bearer);

  if (strncmp(authorization_header.c_str(), bearer, len) == 0) {
    return authorization_header.substr(len);
  }

  throw except::Unauthenticated();
}

std::vector<database::Policy>
extract_policies(config::config const& config)
{
  std::vector<database::Policy> v;

  auto const& groups = config["policies"]["groups"];

  for (auto&& group : groups) {
    auto const group_name = group.first.as<std::string>();
    std::vector<std::string> usernames;
    auto const reuse_users = group.second["reuse_users"].IsDefined()
                                 ? group.second["reuse_users"].as<bool>()
                                 : false;

    auto const& users = group.second["users"];

    if (users.IsMap()) {
      auto pattern = users["pattern"].as<std::string>();
      auto range = users["range"].as<std::vector<int>>();

      for (auto i = range[0]; i <= range[1]; ++i) {
        auto constexpr max_linux_username = 256;
        char username[max_linux_username + 1] {};
        auto const len = std::snprintf(username, max_linux_username,
                                       pattern.c_str(), i);

        usernames.push_back(std::string(username, len));
      }
    } else if (group.second["users"].IsSequence()) {
      for (auto&& username : users) {
        usernames.push_back(username.as<std::string>());
      }
    }

    v.push_back(database::Policy {group_name, usernames, reuse_users});
  }

  if (v.empty()) {
    throw except::InvalidConfig("Empty policies");
  }

  return v;
}

int main(int argc, char* argv[])
{
  try {
    auto arguments = cmdline::parse(argc, argv);
    auto const configuration = config::read(arguments["configfile"]);
    auto const policies = extract_policies(configuration);

    auto db_connection =
        configuration["db"].IsDefined()
            ? database::DataBase(policies,
                                 configuration["db"].as<std::string>())
            : database::DataBase(policies);

    crow::SimpleApp app;
    app.loglevel(
        to_log_level(configuration["log"]["level"].as<std::string>()));

    CROW_ROUTE(app, "/map")
    ([&db_connection, &configuration](crow::request const& req) {
      try {
        auto const token =
            token_from_header(req.get_header_value("Authorization"));

        auto const preferred_group =
            req.get_header_value("X-Preferred-Group");

        auto const user = jwt::decide(token, preferred_group,
                                      db_connection, configuration);

        return crow::response(user);
      } catch (except::InvalidRequestedGroup const& e) {
        return crow::response(400, e.what());
      } catch (except::Unauthenticated const&) {
        return crow::response(401);
      } catch (except::InvalidToken const&) {
        return crow::response(403);
      } catch (except::UntrustedIssuer const&) {
        return crow::response(403);
      } catch (except::NoPolicyMatch const&) {
        return crow::response(403);
      } catch (except::MissingClaims const& e) {
        return crow::response(403, e.what());
      } catch (except::UsersExhausted const&) {
        return crow::response(503);
      } catch (std::exception const& e) {
        CROW_LOG_WARNING << "Generic exception " << e.what();
        throw;
      }
    });

    CROW_ROUTE(app, "/validate")
    ([&db_connection](crow::request const& req) {
      try {
        auto const token =
            token_from_header(req.get_header_value("Authorization"));

        if (jwt::validate(token, db_connection)) {
          return crow::response("valid");
        }

        return crow::response(403, "invalid");
      } catch (std::runtime_error const& re) {
        CROW_LOG_WARNING << re.what();
        return crow::response(403, "invalid");
      } catch (...) {
        throw;
      }
    });

    curl_global_init(CURL_GLOBAL_SSL);

    if (!configuration["ssl"]["disable"].as<bool>()) {
      app.ssl_file(configuration["ssl"]["cert"].as<std::string>(),
                   configuration["ssl"]["key"].as<std::string>());
    } else {
      CROW_LOG_WARNING << "\n===================================="
                          "\n== Running in plain-HTTP (no SSL) =="
                          "\n====================================";
    }

    app.bindaddr(configuration["address"].as<std::string>())
        .port(configuration["port"].as<unsigned short>())
        .multithreaded()
        .run();

    curl_global_cleanup();
  } catch (YAML::Exception const& e) {
    std::cerr << "Configuration error: " << e.what() << '\n';
    return EXIT_FAILURE;
  } catch (except::InvalidConfig const& e) {
    std::cerr << "Configuration error: " << e.what() << '\n';
    return EXIT_FAILURE;
  } catch (except::InvalidCmdline const& e) {
    std::cerr << "Command line error: " << e.what() << '\n';
    return EXIT_FAILURE;
  } catch (except::InvalidDbFile const& e) {
    std::cerr << "DataBase error: " << e.what() << '\n';
    return EXIT_FAILURE;
  } catch (std::exception const& e) {
    std::cerr << "Generic error: " << e.what() << '\n';
    return EXIT_FAILURE;
  } catch (...) {
    std::cerr << "Unknown error\n";
    return EXIT_FAILURE;
  }
}
