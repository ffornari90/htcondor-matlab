find_package(OpenSSL REQUIRED)
find_package(CURL REQUIRED)
find_package(yaml-cpp REQUIRED)
find_package(Boost 1.69.0 COMPONENTS system date_time REQUIRED)
find_package(Threads REQUIRED)

list(APPEND T2U2_SRC main.cpp config.cpp db.cpp cmdline.cpp validate.cpp map.cpp request.cpp)

add_executable(t2u2 ${T2U2_SRC})
target_compile_features(t2u2 PUBLIC cxx_std_14)

target_compile_definitions(t2u2 PUBLIC CROW_ENABLE_SSL)

target_include_directories(t2u2 PUBLIC
  ${EXTERNAL_INCLUDE}
  ${YAML_CPP_INCLUDE_DIR}
  ${OPENSSL_INCLUDE_DIR}
  ${CURL_INCLUDE_DIRS}
  ${Boost_INCLUDE_DIRS})

target_link_libraries(t2u2
  ${OPENSSL_LIBRARIES}
  ${CURL_LIBRARIES}
  ${YAML_CPP_LIBRARIES}
  ${Boost_LIBRARIES}
  Threads::Threads)
