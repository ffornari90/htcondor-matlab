#include "config.hpp"
#include "exceptions.hpp"

config::config config::read(std::filesystem::path const& config_file)
{
  auto config = YAML::LoadFile(config_file.string());

  if (not config["ssl"]["disable"].IsDefined()) {
    config["ssl"]["disable"] = false;
  }

  if (not config["ssl"]["key"].IsDefined()) {
    config["ssl"]["key"] = "/etc/t2u2/key.pem";
  }

  if (not config["ssl"]["cert"].IsDefined()) {
    config["ssl"]["cert"] = "/etc/t2u2/cert.pem";
  }

  if (not config["db"].IsDefined()) {
    config["db"] = "/etc/t2u2/db";
  }

  if (not config["log"]["level"].IsDefined()) {
    config["log"]["level"] = "info";
  }

  if (not config["address"].IsDefined()) {
    config["address"] = "0.0.0.0";
  }

  if (not config["port"].IsDefined()) {
    config["port"] = static_cast<unsigned short>(9999);
  }

  if (not config["policies"].IsDefined()) {
    throw except::InvalidConfig("no policies found");
  }

  if (not config["policies"]["groups"].IsDefined()) {
    throw except::InvalidConfig("no groups found");
  }

  return config;
}
