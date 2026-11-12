# NetBox MCP server behind nginx (HTTPS)

Exposes [netbox-mcp-server](https://github.com/netboxlabs/netbox-mcp-server) over HTTPS. nginx terminates TLS and proxies to the MCP container over an internal Docker network; the MCP container itself is never published.

```
client --HTTPS :9999--> nginx --HTTP--> netbox-mcp-server --> remote NetBox
```

## Quick start

1. Create your config:

   ```sh
   cp .env.example .env
   ```

   Set `NETBOX_URL`, `NETBOX_TOKEN` (a read-only NetBox API token) and `MCP_AUTH_TOKEN` (generate one with `openssl rand -hex 32`).

2. Provide a TLS certificate (pick one, see [Certificates](#certificates)).

3. Start:

   ```sh
   docker compose up -d
   ```

4. Test:

   ```sh
   curl -k -i https://localhost:9999/mcp -H "Authorization: Bearer $MCP_AUTH_TOKEN"
   ```

   `401` without the header and a response with it means everything is wired up.

Clients connect to `https://<host>:9999/mcp` and send `Authorization: Bearer <MCP_AUTH_TOKEN>`.

## Certificates

nginx reads `certs/server.crt` and `certs/server.key`. These files are git-ignored; the `certs/` directory is kept.

### Option A: self-signed (testing)

List every IP and hostname clients will use; they go into the certificate's subject alternative names (`localhost` and `127.0.0.1` are always included):

```sh
scripts/gen-cert.sh 203.0.113.10 mcp.example.com
```

Re-run with `FORCE=1` to regenerate. Clients must trust `certs/server.crt` or skip verification. For Node-based clients, `NODE_EXTRA_CA_CERTS=/path/to/certs/server.crt` is better than disabling verification.

### Option B: your own certificate (CA-signed)

Copy the files from your CA, or from Let's Encrypt or an internal PKI:

```sh
cp /path/to/fullchain.pem certs/server.crt   # server cert followed by any intermediates
cp /path/to/privkey.pem   certs/server.key
docker compose restart nginx
```

The certificate must cover the hostname clients connect to. Clients then need no extra trust setup if the CA is publicly trusted.

### Inspect a certificate

```sh
openssl x509 -in certs/server.crt -noout -subject -issuer -dates -ext subjectAltName
```

## Configuration

Set these in `.env`:

| Variable | Default | Purpose |
|---|---|---|
| `NETBOX_URL` | required | Remote NetBox base URL |
| `NETBOX_TOKEN` | required | NetBox API token |
| `MCP_AUTH_TOKEN` | required | Bearer token clients must send |
| `HTTPS_PORT` | `9999` | Port nginx listens on and publishes |
| `MCP_IMAGE_TAG` | `latest` | Pin the MCP server image version |
| `VERIFY_SSL` | `true` | Verify NetBox's TLS certificate (set `false` if it is self-signed) |
| `LOG_LEVEL` | `INFO` | MCP server log level |
| `NGINX_LOG_LEVEL` | `info` | nginx error log level (`debug` is very verbose) |

## Troubleshooting

```sh
docker compose logs -f nginx
```

- `SSL_do_handshake() failed ... unknown ca`: the client does not trust the certificate.
- Client works with `curl -k` but not otherwise: the certificate lacks the hostname or IP the client uses.
- `401` in the access log: the Bearer header is missing or wrong.
- `404`: only `/mcp` is proxied.
- Nothing in the logs: the request is not reaching the host (firewall or DNS).
