# S/4HANA Sales Order → MCP demo (CAP)

Expose the SAP S/4HANA **`API_SALES_ORDER_SRV`** OData service to AI agents over the
**Model Context Protocol (MCP)**, using SAP CAP as the auth broker + MCP adapter.

```
AI Agent / LLM  (e.g. Joule, Claude, Cline)
     │  MCP (Streamable HTTP, JSON-RPC)
     ▼
CAP app  ──► @cap-js/mcp adapter exposes  /mcp/sales-orders
     │  (XSUAA auth + @requires: 'authenticated-user')
     │
     └── cds.RemoteService "API_SALES_ORDER_SRV" (odata-v2)
              │  BTP Destination Service  →  destination "QJ6"
              ▼
         connectivity service → Cloud Connector → S/4HANA (ldcsqj6:50001)
```

The agent only ever speaks MCP to CAP. It never sees S/4 credentials — CAP resolves
those through the BTP Destination Service (destination **`QJ6`**, Basic auth, on-prem
via Cloud Connector) in this subaccount.

## Project layout

| File | Purpose |
|------|---------|
| `srv/external/API_SALES_ORDER_SRV.cds` | Trimmed hand-written model of the S/4 OData V2 API (`A_SalesOrder`, `A_SalesOrderItem`). Replace with a real `cds import` — see below. |
| `srv/sales-order-service.cds` | `SalesOrderService`, annotated `@mcp: 'sales-orders'` + `@requires: 'authenticated-user'`. Curated read-only projections + `getOrderTotal` function. |
| `srv/sales-order-service.js` | Forwards reads to the remote S/4 service; implements `getOrderTotal`. |
| `package.json` → `cds.requires` | Remote service bound to destination `QJ6`; XSUAA + destinations + connectivity in prod; mocked auth in dev. |
| `mta.yaml` / `manifest.yml` | Deployment (MTA or plain `cf push`). |
| `xs-security.json` | XSUAA app config. |

## Auto-generated MCP tools

The `@cap-js/mcp` adapter (v1.x, **beta**) creates three tools per annotated service:
- `describe` — entity/element metadata (uses CDS doc comments as context)
- `query` — CQN queries → `service.run()`  (read)
- `call` / `call_action` — unbound actions/functions (here: `getOrderTotal`)

Writes (CREATE/UPDATE/DELETE) are **not** exposed via MCP — expose them as unbound
actions if needed.

## Prerequisites

```bash
npm install    # @sap/cds, @cap-js/mcp; dev: @sap/cds-dk, @cap-js/sqlite
```

Uses `@sap/cds` v10, `@cap-js/mcp` v1.4.3, Node 20+.

## Run locally — mocked auth (no S/4)

```bash
npx cds watch      # serves MCP at http://localhost:4004/mcp/sales-orders
```

Verify (mocked user `alice`, Basic auth):

```bash
curl -s -u 'alice:' -X POST http://localhost:4004/mcp/sales-orders \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"probe","version":"1"}}}'
```

Expect an `initialize` result with `capabilities.tools`. Without credentials you get
`401 Not authorized` — that's the `@requires` guard working.


## Run locally — HYBRID (real S/4 via `cds bind`)

`QJ6` is an **on-premise** destination reached through the Cloud Connector, so local dev
must borrow the CF `destination` + `connectivity` bindings ("hybrid" testing).

```bash
# 1. Target the space that owns the QJ6 destination
cf login -a https://api.cf.eu20.hana.ondemand.com
cf target -o "CoE Ireland_coe-sap-build-blz6w21l" -s "SAP Build"

# 2. Bind local app to the existing CF service instances
cds bind --to DestService --to BTP-Onboarding-connectivity --for hybrid

# 3. Run in hybrid profile → real destination + connectivity → real S/4 data
cds watch --profile hybrid
```

Caveats:
- The connectivity proxy tunnels to the Cloud Connector, so on-prem `QJ6` is reachable
  without a VPN — but your machine needs outbound access to BTP.
- `QJ6` uses **BasicAuthentication** (technical user). For end-user principal
  propagation switch the destination in `package.json` to `QJ6PP`
  (`OnPremise` / `PrincipalPropagation`).

## Deploy to Cloud Foundry (real S/4)

### Option A — MTA (recommended)

```bash
npm i -g mbt            # once
mbt build              # -> mta_archives/*.mtar
cf deploy mta_archives/s4-sales-order-mcp_1.0.0.mtar
```

Creates and binds its own `xsuaa`, `destination`, `connectivity` instances.

### Option B — plain `cf push` (reuse existing instances)

```bash
cds build --production
cf create-service xsuaa application s4-sales-order-mcp-auth -c xs-security.json
cf push                # manifest.yml binds BTP-Onboarding-destination + -connectivity
```

Deployed endpoint: `https://<app-route>/mcp/sales-orders` — authenticate with an XSUAA
OAuth2 token (client-credentials for machine agents, or auth-code/PKCE interactive).

## Replace the stub model with the real S/4 API

The committed `srv/external/API_SALES_ORDER_SRV.cds` is a **minimal hand-written subset**
so the demo compiles and runs. For the full model:

```bash
# 1. Download EDMX: https://api.sap.com/api/API_SALES_ORDER_SRV/overview
# 2. cds import ~/Downloads/API_SALES_ORDER_SRV.edmx --as cds
# 3. Delete the hand-written .cds; adjust projections in sales-order-service.cds
```

## Security caveats (CAP MCP docs — beta)

- `@cap-js/mcp` is **beta**; do **not** expose the endpoint to untrusted agents.
- The adapter performs **no** prompt-injection input/output validation — front it with a
  trusted agent (e.g. Joule) + XSUAA scopes.
- This demo is read-only + one function; no write path is exposed.

## References
- CAP MCP Adapter: https://cap.cloud.sap/docs/guides/protocols/mcp
- `API_SALES_ORDER_SRV`: https://api.sap.com/api/API_SALES_ORDER_SRV/overview
