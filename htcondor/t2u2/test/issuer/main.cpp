#include "keys.hpp"
#include <crow.h>
#include <cxxopts.hpp>
#include <iostream>
#include <jwt-cpp/jwt.h>
#include <memory>
#include <openssl/rsa.h>
#include <string>
#include <utility>

void disclaimer()
{
  std::cerr << "================================================\n"
            << "= This program is solely for TESTING PURPOSES! =\n"
            << "=   Do NOT use in production environments!!!   =\n"
            << "================================================\n";
}

int main(int argc, char* argv[])
{
  cxxopts::Options options("test-issuer",
                           "Issue JWT for testing purposes");
  // clang-format off
  options.add_options()
  ("p,port", "Port to bind", cxxopts::value<unsigned short int>()->default_value("8080"))
  ("sub", "Subject", cxxopts::value<std::string>()->default_value("ba2dfb62-26c9-4019-add7-7a135de74b70"))
  ("g,group", "member of the group claim", cxxopts::value<std::vector<std::string>>())
  ("w,wlcggroup", "member of the wlcg.group claim", cxxopts::value<std::vector<std::string>>())
  ("h,help", "Print usage");
  // clang-format on

  auto result = options.parse(argc, argv);

  if (result["help"].count()) {
    std::cout << options.help() << std::endl;
    return EXIT_SUCCESS;
  }

  auto const empty = std::vector<std::string>();
  auto const sub = result["sub"].as<std::string>();
  auto const groups = result.count("group")
                          ? result["group"].as<std::vector<std::string>>()
                          : empty;
  auto const wlcg_groups =
      result.count("wlcggroup")
          ? result["wlcggroup"].as<std::vector<std::string>>()
          : empty;
  auto const port = result["port"].as<unsigned short int>();
  auto const iss = "localhost:" + std::to_string(port);

  disclaimer();

  crow::SimpleApp app;
  app.loglevel(crow::LogLevel::Debug);

  CROW_ROUTE(app, "/")
  ([&]() {
    using namespace std::string_literals;
    using namespace std::chrono_literals;

    auto const now = std::chrono::system_clock::now();

    auto const exp = now + 3600s;

    auto const token =
        jwt::create()
            .set_issuer(iss)
            .set_key_id("key")
            .set_payload_claim(
                "wlcg.groups",
                jwt::claim(wlcg_groups.begin(), wlcg_groups.end()))
            .set_payload_claim("groups",
                               jwt::claim(groups.begin(), groups.end()))
            .set_payload_claim("sub", jwt::claim(sub))
            .set_payload_claim("iat", jwt::claim(now))
            .set_payload_claim("exp", jwt::claim(exp))
            .set_payload_claim("name", jwt::claim("test"s))
            .sign(jwt::algorithm::rs256(PUBLIC_KEY, PRIVATE_KEY, "", ""));
    return token;
  });

  CROW_ROUTE(app, "/jwk")
  ([]() { return JWK; });

  CROW_ROUTE(app, "/.well-known/openid-configuration")
  ([&port]() {
    return "{\"jwks_uri\": \"localhost:" + std::to_string(port) +
           "/jwk\"}";
  });

  app.bindaddr("127.0.0.1").port(port).multithreaded().run();
}
