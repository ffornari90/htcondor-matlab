Token to pool account mapping helper
====================================

## Requirements
Build requirements are:
- git
- a compiler supporting C++17 or above
- CMake version 3.20 or above

## Build process
```shell
git clone --recurse-submodules https://baltig.infn.it/budda/t2u2.git
cmake -S t2u2 -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## Configuration
The configuration file is by default located in `/etc/t2u2/config.yml`.
You can specify an alternate `YAML` configuration file via the `-c/--config`
command line switch.

An example of a valid configuration file follows. Shown values are, apart
from the `policies` section, default.

```yaml
# database file path
db: /etc/t2u2/db

# log level
log:
  # possible values: debug, info, warning, error, critical
  level: info

# address and port number to bind
address: 0.0.0.0                       # any network interface
port: 9999

# SSL/TLS configuration
ssl:
  disable: false
  cert: /etc/t2u2/cert.pem
  key: /etc/t2u2/key.pem

# mapping policies
policies:
  allow_untrusted_issuer: false        # default

  trusted_issuers:
    - https://iam-t1-computing.cloud.cnaf.infn.it
    - https://wlcg.cloud.cnaf.infn.it/

  # each group is a IAM group
  groups:
    /wlcg:
      reuse_users: true                # default: false
      users:
        # each user must be a valid local Unix user
        - wlcg001
        - wlcg002
    dteam:
      users:
        # users can be defined via a common pattern and a numeric interval in a
        # concise way. E.g., users from dteam001 through dteam100:
        pattern: "dteam%03d"           # pattern like in `man 3 printf`
        range: [1, 100]                # interval begin and end, included
```
