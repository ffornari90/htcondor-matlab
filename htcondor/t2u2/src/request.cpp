#include "request.hpp"
#include "exceptions.hpp"
#include <curl/curl.h>
#include <memory>

namespace {
size_t string_callback(char* ptr, size_t size, size_t nmemb, void* buffer)
{
  auto const read = size * nmemb;
  auto s_buffer = static_cast<std::string*>(buffer);
  s_buffer->append(ptr, read);
  return read;
}
} // namespace

std::pair<std::string, long> request::request(std::string const& url)
{
  auto curl = std::unique_ptr<CURL, decltype(&curl_easy_cleanup)>(
      curl_easy_init(), curl_easy_cleanup);

  char errbuf[CURL_ERROR_SIZE] {};

  std::string buffer;
  curl_easy_setopt(curl.get(), CURLOPT_URL, url.c_str());
  curl_easy_setopt(curl.get(), CURLOPT_FOLLOWLOCATION, 1L);
  curl_easy_setopt(curl.get(), CURLOPT_WRITEDATA, &buffer);
  curl_easy_setopt(curl.get(), CURLOPT_WRITEFUNCTION, string_callback);
  curl_easy_setopt(curl.get(), CURLOPT_ERRORBUFFER, errbuf);

  auto const res = curl_easy_perform(curl.get());

  if (res != CURLE_OK) {
    throw except::ConnectionToIssuer(errbuf);
  }

  long request_code = 0;
  curl_easy_getinfo(curl.get(), CURLINFO_RESPONSE_CODE, &request_code);

  return std::make_pair(buffer, request_code);
}
