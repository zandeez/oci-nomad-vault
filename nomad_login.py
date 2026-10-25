#!/usr/bin/env python3
from urllib import request
import json
import os

if __name__ == "__main__":
    auth_request = json.dumps({
        "role": "gitlab",
        "jwt": os.environ["VAULT_TOKEN"]
    }).encode()

    login_result = request.urlopen(f"{os.environ['VAULT_ADDR']}/v1/auth/jwt/login", auth_request)
    vault_token = json.loads(login_result.read().decode())["auth"]["client_token"]

    # Issue a vault token with the nomad policy for checking purposes
    token_request = request.Request(f"{os.environ['VAULT_ADDR']}/v1/auth/token/create/nomad", method="POST", headers={
        "X-Vault-Token": vault_token
    })

    token_response = request.urlopen(token_request)
    print(f"VAULT_TOKEN={json.loads(token_response.read().decode())['auth']['client_token']}")

    nomad_request = request.Request(f"{os.environ['VAULT_ADDR']}/v1/nomad/creds/gitlab", headers={
        "X-Vault-Token": vault_token
    })

    nomad_result = request.urlopen(nomad_request)
    print(f"NOMAD_TOKEN={json.loads(nomad_result.read().decode())['data']['secret_id']}")
