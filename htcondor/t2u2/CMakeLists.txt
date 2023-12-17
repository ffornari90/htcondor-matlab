project(t2u2 CXX)
cmake_minimum_required(VERSION 3.20)

list(APPEND EXTERNAL_INCLUDE
  ${CMAKE_CURRENT_SOURCE_DIR}/external/Crow/include
  ${CMAKE_CURRENT_SOURCE_DIR}/external/jwt-cpp/include
  ${CMAKE_CURRENT_SOURCE_DIR}/external/cxxopts/include
)

add_subdirectory(src)
