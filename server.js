const cds = require('@sap/cds')

/**
 * Custom bootstrap:
 *  1. Serve a static "MCP Console" UI at /console (same-origin -> no CORS).
 *  2. Expose a tiny same-origin proxy at POST /mcp-proxy that forwards raw
 *     JSON-RPC bodies from the browser to the app's own MCP endpoint
 *     (/mcp/sales-orders), handling the Streamable-HTTP session + auth so the
 *     browser never needs a token.
 *
 * This lets you trigger the real MCP tools (describe/query/call) from a browser
 * and see how changes to your @mcp annotations / projections affect results.
 */

const path = require('path')

// --- helpers -------------------------------------------------------------

// Obtain an auth header for calling our own MCP endpoint.
// - In CF: mint a client-credentials token from the bound XSUAA (VCAP_SERVICES).
// - Locally (dev/hybrid, auth: mocked): use Basic alice:.
let _cachedToken = null
let _cachedExp = 0

async function getAuthHeader() {
  const xsuaa = cds.env.requires?.auth?.credentials || _readXsuaaFromVcap()
  if (!xsuaa || !xsuaa.clientid) {
    // local mocked auth
    return 'Basic ' + Buffer.from('alice:').toString('base64')
  }
  const now = Date.now()
  if (_cachedToken && now < _cachedExp - 60_000) return 'Bearer ' + _cachedToken

  const url = `${xsuaa.url}/oauth/token?grant_type=client_credentials`
  const basic = Buffer.from(`${xsuaa.clientid}:${xsuaa.clientsecret}`).toString('base64')
  const resp = await fetch(url, {
    method: 'POST',
    headers: { Authorization: 'Basic ' + basic, 'Content-Type': 'application/x-www-form-urlencoded' }
  })
  if (!resp.ok) throw new Error(`token request failed: ${resp.status}`)
  const json = await resp.json()
  _cachedToken = json.access_token
  _cachedExp = now + (json.expires_in || 3600) * 1000
  return 'Bearer ' + _cachedToken
}

function _readXsuaaFromVcap() {
  try {
    const vcap = JSON.parse(process.env.VCAP_SERVICES || '{}')
    const x = (vcap.xsuaa && vcap.xsuaa[0]) || null
    return x ? x.credentials : null
  } catch {
    return null
  }
}

// Parse an SSE ("event: message\ndata: {...}") or plain-JSON response body,
// returning the first JSON-RPC object found.
function parseMcpBody(text) {
  const trimmed = (text || '').trim()
  if (trimmed.startsWith('{')) {
    try { return JSON.parse(trimmed) } catch { /* fall through */ }
  }
  for (const line of trimmed.split('\n')) {
    const l = line.trim()
    if (l.startsWith('data:')) {
      const payload = l.slice(5).trim()
      if (payload && payload !== '[DONE]') {
        try { return JSON.parse(payload) } catch { /* ignore */ }
      }
    }
  }
  return { raw: text }
}

// --- bootstrap -----------------------------------------------------------

cds.on('bootstrap', (app) => {
  const express = require('express')

  // 1) Serve the console UI (static) from ./srv/public
  app.use('/console', express.static(path.join(__dirname, 'srv', 'public')))

  // 2) Same-origin MCP proxies for the browser console. The browser POSTs a
  //    JSON-RPC body; we do the full initialize -> notifications/initialized ->
  //    <method> handshake against the chosen server and return the parsed result.
  const makeConsoleProxy = (targetPath) => async (req, res) => {
    try {
      const auth = await getAuthHeader()
      const origin = `http://localhost:${process.env.PORT || 4004}`
      const target = origin + targetPath
      const baseHeaders = {
        Authorization: auth,
        'Content-Type': 'application/json',
        Accept: 'application/json, text/event-stream'
      }

      const initResp = await fetch(target, {
        method: 'POST',
        headers: baseHeaders,
        body: JSON.stringify({
          jsonrpc: '2.0', id: 1, method: 'initialize',
          params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'mcp-console', version: '1' } }
        })
      })
      const sid = initResp.headers.get('mcp-session-id')
      const sessionHeaders = sid ? { ...baseHeaders, 'mcp-session-id': sid } : baseHeaders

      await fetch(target, {
        method: 'POST',
        headers: sessionHeaders,
        body: JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })
      })

      const callResp = await fetch(target, {
        method: 'POST',
        headers: sessionHeaders,
        body: JSON.stringify(req.body)
      })
      const text = await callResp.text()
      res.status(callResp.status).json(parseMcpBody(text))
    } catch (e) {
      res.status(500).json({ error: String(e && e.message || e) })
    }
  }

  app.use('/mcp-proxy', express.json())
  app.post('/mcp-proxy', makeConsoleProxy('/mcp/sales-orders'))
  app.use('/mcp-proxy-advanced', express.json())
  app.post('/mcp-proxy-advanced', makeConsoleProxy('/mcp/sales-orders-advanced'))

  cds.log('mcp-console').info("MCP console at '/console' (proxies: /mcp-proxy [basic], /mcp-proxy-advanced)")

  // 3) Transparent MCP passthroughs for Joule Studio / external MCP clients.
  //
  //    WHY: @cap-js/mcp serves at /mcp/<name>, but MCP clients like Joule assume
  //    the conventional endpoint <base>/mcp and append "/mcp" to the destination
  //    URL. We expose standard-looking endpoints and forward verbatim to the
  //    real internal endpoints, injecting the XSUAA token server-side.
  //
  //    Destinations:
  //      QJ6_MCP           URL = https://<app>/joule            -> basic server
  //      QJ6_MCP_Advanced  URL = https://<app>/joule-advanced   -> advanced server
  //      Authentication = NoAuthentication (token injected here)
  const makeRelay = (targetPath) => async (req, res) => {
    try {
      const auth = await getAuthHeader()
      const origin = `http://localhost:${process.env.PORT || 4004}`
      const target = origin + targetPath

      const fwdHeaders = {
        Authorization: auth,
        'Content-Type': req.headers['content-type'] || 'application/json',
        Accept: req.headers['accept'] || 'application/json, text/event-stream'
      }
      if (req.headers['mcp-session-id']) fwdHeaders['mcp-session-id'] = req.headers['mcp-session-id']
      if (req.headers['mcp-protocol-version']) fwdHeaders['mcp-protocol-version'] = req.headers['mcp-protocol-version']
      if (req.headers['last-event-id']) fwdHeaders['last-event-id'] = req.headers['last-event-id']

      const init = { method: req.method, headers: fwdHeaders }
      if (req.method === 'POST') init.body = JSON.stringify(req.body)

      const upstream = await fetch(target, init)

      const sid = upstream.headers.get('mcp-session-id')
      if (sid) res.set('mcp-session-id', sid)
      const ct = upstream.headers.get('content-type')
      if (ct) res.set('content-type', ct)
      res.status(upstream.status)

      const text = await upstream.text()
      res.send(text)
    } catch (e) {
      res.status(500).json({ jsonrpc: '2.0', error: { code: -32000, message: String((e && e.message) || e) } })
    }
  }

  const basicRelay = makeRelay('/mcp/sales-orders')
  const advancedRelay = makeRelay('/mcp/sales-orders-advanced')

  app.use('/joule/mcp', express.json({ type: () => true }))
  app.post('/joule/mcp', basicRelay)
  app.get('/joule/mcp', basicRelay)
  app.delete('/joule/mcp', basicRelay)

  app.use('/joule-advanced/mcp', express.json({ type: () => true }))
  app.post('/joule-advanced/mcp', advancedRelay)
  app.get('/joule-advanced/mcp', advancedRelay)
  app.delete('/joule-advanced/mcp', advancedRelay)

  cds.log('mcp-console').info("Joule passthroughs: '/joule/mcp' -> basic, '/joule-advanced/mcp' -> advanced")
})

module.exports = cds.server
