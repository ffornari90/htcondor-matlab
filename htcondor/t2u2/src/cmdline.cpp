#include "cmdline.hpp"
#include "exceptions.hpp"
#include <cxxopts.hpp>
#include <iostream>

std::map<std::string, std::string>
cmdline::parse(int argc, char const* const argv[])
{
  try {
    std::map<std::string, std::string> parameters;
    cxxopts::Options options("t2u", "Token to Unix user");

    options.add_options()(
        "c,configfile", "Specify the YAML configuration file",
        cxxopts::value<std::string>()->default_value(
            "/etc/t2u2/config.yml"))("h,help", "Print usage");

    auto result = options.parse(argc, argv);

    if (result.count("help")) {
      std::cout << options.help() << std::endl;
      exit(0);
    }

    parameters["configfile"] = result["configfile"].as<std::string>();

    return parameters;
  } catch (cxxopts::OptionException const& e) {
    throw except::InvalidCmdline(e.what());
  }
}
