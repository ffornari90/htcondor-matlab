#include "validate.hpp"
#include "exceptions.hpp"
#include "request.hpp"
#include <jwt-cpp/jwt.h>
#include <memory>

namespace {
using BN_up = std::unique_ptr<BIGNUM, decltype(&BN_free)>;
using EVP_PKEY_up = std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)>;
using BIO_up = std::unique_ptr<BIO, decltype(&BIO_free_all)>;

BN_up base64DecodeBigNum(std::string const& base64bignum)
{
  auto const decode = jwt::base::decode<jwt::alphabet::base64url>(
      jwt::base::pad<jwt::alphabet::base64url>(base64bignum));

  return jwt::helper::raw2bn(decode);
}

EVP_PKEY_up RsaPubKeyFromModExp(std::string const& modulus_b64,
                                std::string const& exp_b64)
{
  auto n = base64DecodeBigNum(modulus_b64);
  auto e = base64DecodeBigNum(exp_b64);

  if (e && n) {
    EVP_PKEY* pRsaKey = EVP_PKEY_new();
    RSA* rsa = RSA_new();
    RSA_set0_key(rsa, n.release(), e.release(), nullptr);
    EVP_PKEY_assign_RSA(pRsaKey, rsa);
    return EVP_PKEY_up(pRsaKey, EVP_PKEY_free);
  }

  return EVP_PKEY_up(nullptr, EVP_PKEY_free);
}

std::string to_string(EVP_PKEY_up const& pkey)
{
  auto bio = BIO_up(BIO_new(BIO_s_mem()), BIO_free_all);
  PEM_write_bio_PUBKEY(bio.get(), pkey.get());
  auto const len = BIO_pending(bio.get());
  char buffer[len] {};
  BIO_read(bio.get(), buffer, len);
  return std::string(buffer, len);
}

} // namespace

namespace jwt {
bool validate(std::string const& token, database::DataBase& db)
{
  auto const decoded_jwt = jwt::decode(token);
  auto const issuer = decoded_jwt.get_issuer();
  auto const kid = decoded_jwt.get_key_id();

  auto rsa_pub = db.get_pub_key(issuer, kid);
  if (rsa_pub == database::DataBase::NOT_FOUND) {
    auto const oid_conf_req =
        request::request(issuer + "/.well-known/openid-configuration");

    if (oid_conf_req.second != 200) {
      throw except::ConnectionToIssuer("openid-configuration");
    }

    picojson::value oid_conf;
    std::string err = picojson::parse(oid_conf, oid_conf_req.first);

    if (!err.empty()) {
      throw except::ConnectionToIssuer("Unable to validate token");
    }

    auto const jwk_endpoint =
        oid_conf.get<picojson::object>()["jwks_uri"].to_str();
    auto const req = request::request(jwk_endpoint);

    if (req.second != 200) {
      throw except::ConnectionToIssuer("jwks");
    }

    auto jwks = jwt::parse_jwks(req.first);
    auto jwk = jwks.get_jwk(kid);

    auto const n = jwk.get_jwk_claim("n").as_string();
    auto const e = jwk.get_jwk_claim("e").as_string();
    rsa_pub = to_string(RsaPubKeyFromModExp(n, e));
    db.put_pub_key(issuer, kid, rsa_pub);
  }

  auto verifier =
      jwt::verify()
          .allow_algorithm(jwt::algorithm::rs256(rsa_pub, "", "", ""))
          .with_issuer(issuer)
          .leeway(60UL);

  try {
    verifier.verify(decoded_jwt);
    return true;
  } catch (...) {
    return false;
  }
}
} // namespace jwt
