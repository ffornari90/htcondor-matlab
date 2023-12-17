#ifndef T2U2_CONFIG_HPP
#define T2U2_CONFIG_HPP

#include <filesystem>
#include <yaml-cpp/yaml.h>

namespace config {
using config = YAML::Node;

config read(std::filesystem::path const& config_file);

} // namespace config

#endif // T2U2_CONFIG_HPP
