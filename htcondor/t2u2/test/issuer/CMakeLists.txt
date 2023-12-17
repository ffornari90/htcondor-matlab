project(test_issuer CXX)
cmake_minimum_required(VERSION 3.20)

find_package(OpenSSL REQUIRED)
find_package(Boost 1.69.0 REQUIRED)
find_package(Threads REQUIRED)

add_executable(issuer main.cpp keys.cpp)
target_compile_features(issuer PUBLIC cxx_std_14)

target_include_directories(issuer PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../../external/Crow/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../../external/jwt-cpp/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../../external/cxxopts/include
  ${OPENSSL_INCLUDE_DIR}
  ${Boost_INCLUDE_DIRS})

target_link_libraries(issuer
  ${OPENSSL_LIBRARIES}
  ${Boost_LIBRARIES}
  Threads::Threads)
