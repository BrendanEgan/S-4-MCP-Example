# CLAUDE.md

Guidance for AI coding agents working in this repo.

## What this project is

`s4-sales-order-mcp` — a **SAP CAP (Node.js) application** that exposes SAP S/4HANA
OData APIs to AI agents (Joule, Claude, Cline) over the **Model Context Protocol (MCP)**,
using the `@cap-js/mcp` adapter (**v1.4.3, beta**). CAP is both the **MCP adapter** and
the **auth broker** — agents never see S/4 credentials.

```
AI Agent / LLM  (Joule, Claude, Cline)
     │  MCP (Streamable HTTP, JSON-RPC)
     ▼
CAP app ──► @cap-js/mcp adapter exposes /mcp/<name>
     │       (XSUAA auth + @requires: 'authenticated-user')
     │
     └── cds.RemoteService (odata-v2) ──► BTP Destination "QJ6"
              │
              ▼
         connectivity service → Cloud Connector → S/4HANA (on-prem, Basic auth)
```

Stack: `@sap/cds` v10, `@cap-js/mcp` v1.4.3, Node 20+. Dev: `@sap/cds-dk`, `@cap-js/sqlite`.

## How MCP is wired (the core mechanism)

- Any service annotated **`@mcp: '<name>'`** is published by the adapter at `/mcp/<name>`.
- `package.json` sets `cds.mcp.per_action_tool: true` → each action/function becomes its own tool.
- Auto-generated per service: **`describe`** (entity/element metadata, uses `/** ... */` doc
  comments as LLM context), **`query`** (CQN reads → `service.run()`), and per-action
  **`call_action`** tools.
- **`@requires: 'authenticated-user'`** guards every endpoint.
- **`@mcp.instructions: '...'`** supplies system-prompt guidance to the agent.


## The four MCP servers

| File (`.cds` + `.js`)          | Endpoint                      | S/4 API               | Exposes |
|--------------------------------|-------------------------------|-----------------------|---------|
| `srv/sales-order-service`      | `/mcp/sales-orders`           | `API_SALES_ORDER_SRV` | Read SalesOrders/Items + `getOrderTotal`. Stamps a `virtual mcpNote` field in CAP to prove the MCP layer is active. |
| `srv/sales-order-advanced-service` | `/mcp/sales-orders-advanced` | `API_SALES_ORDER_SRV` | Same reads **plus** analytics: `salesByCustomerInRange`, `salesByCustomerAll`, `topSellingItems` (group-by/SUM in Node by paging OData), `topSellingItemsFast` (aggregation pushed into HANA via `C_SALESORDERITEMQRY_CDS` analytical view, Cloud SDK direct call). |
| `srv/purchase-manager-service`   | `/mcp/purchase-manager`       | `API_PRODUCT_SRV`, `API_PURCHASEORDER_PROCESS_SRV`, `API_INBOUND_DELIVERY_SRV` (all CSRF) | Read Products / PurchaseOrders(+Items) / InboundDeliveries(+Items) + **`createProduct`**, **`createPurchaseOrder`** (header+items deep insert), **`createInboundDelivery`** (header+items deep insert). Writes exposed as unbound actions since MCP has no native create. |

All services forward entity READs to the remote service via `cds.connect.to('<API>')` then
`s4.run(req.query)`.

## Custom bootstrap (`server.js`)

Extends `cds.server` via `cds.on('bootstrap', app => ...)` to add what the adapter doesn't:
1. **`/console`** — static browser UI (`srv/public/mcp-console.html`) to trigger MCP tools.
2. **Console proxies** (`/mcp-proxy`, `-advanced`, `-purchase-manager`) — browser POSTs a
   JSON-RPC body; proxy runs the full `initialize → notifications/initialized → <method>`
   handshake server-side and injects auth, so the browser needs no token. Parses SSE
   (`event: message / data: {...}`) and plain JSON.
3. **Joule passthroughs** (`/joule/mcp`, `/joule-advanced/mcp`,
   `/joule-purchase-manager/mcp`) — transparent relays forwarding verbatim to internal `/mcp/<name>`
   while injecting the XSUAA token. Exists because external clients (Joule Studio) assume the
   conventional `<base>/mcp` endpoint, but the adapter serves at `/mcp/<name>`.

`getAuthHeader()`: in CF mints a **client-credentials token** from bound XSUAA
(`VCAP_SERVICES`, cached until ~1 min before expiry); locally (mocked auth) falls back to
`Basic alice:`.

## Config & environment

- **`package.json` → `cds.requires`**: three odata-v2 remote services all bound to destination
  `QJ6`; prod uses `auth: xsuaa` + `destinations` + `connectivity`; `[development]` uses
  `auth: mocked`.
- **`.cdsrc-private.json`**: `[hybrid]` profile binds local dev to CF `DestService` +
  `BTP-Onboarding-connectivity` so you can hit real on-prem S/4 through the Cloud Connector
  without a VPN. (Contains CF org/space binding info — do not leak.)
- **`srv/external/*.cds`**: hand-written, trimmed, `@cds.external` stub models of the S/4
  OData V2 APIs. Meant to be replaced by a real `cds import <EDMX> --as cds`.
- **Deploy**: `mta.yaml` (recommended — creates its own xsuaa/destination/connectivity) or
  `manifest.yml` (plain `cf push` reusing existing instances). `xs-security.json` = XSUAA app config.

## Run / test

```bash
npm install

# Mocked auth (no S/4):
npx cds watch                 # MCP at http://localhost:4004/mcp/sales-orders
# smoke test (mocked user alice):
curl -s -u 'alice:' -X POST http://localhost:4004/mcp/sales-orders \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}'

# Hybrid (real S/4 via CF bindings):
cds bind --to DestService --to BTP-Onboarding-connectivity --for hybrid
cds watch --profile hybrid
```

Deployed endpoints authenticate with an XSUAA OAuth2 token (client-credentials for machine
agents, auth-code/PKCE interactive).

## Conventions when extending

- Add a new MCP server = new `srv/<name>-service.cds` with `@mcp`, `@mcp.instructions`,
  `@requires: 'authenticated-user'`, `@readonly` curated projections, and a matching
  `srv/<name>-service.js` that `cds.connect.to`s the remote API and forwards reads.
- Use `/** ... */` doc comments on services/entities/elements/params — they become the LLM's
  context via `describe`.
- Expose writes as **unbound actions** (MCP has no native create/update/delete).
- Register the new endpoint's console proxy + Joule passthrough in `server.js` to match the pattern.

## Caveats / known issues

- `@cap-js/mcp` is **beta**: performs **no** prompt-injection input/output validation. Never
  expose to untrusted agents; front with a trusted agent + XSUAA scopes.
- **`getOrderTotal` in `srv/sales-order-service.js` is currently stubbed** (lines ~43–50):
  the real return is commented out and it returns `{ message: "Hey you ran a MCP function!" }`.
  The *advanced* service's `getOrderTotal` returns real values. Likely leftover debugging —
  restore if you want the basic tool functional.
- Writes are exposed via `purchase-manager-service` only: `createProduct`, `createPurchaseOrder`, `createInboundDelivery` (unbound actions, deep-insert POST to S/4). The sales MCPs are read-only.

## References

- CAP MCP adapter: https://cap.cloud.sap/docs/guides/protocols/mcp
- `API_SALES_ORDER_SRV`: https://api.sap.com/api/API_SALES_ORDER_SRV/overview

