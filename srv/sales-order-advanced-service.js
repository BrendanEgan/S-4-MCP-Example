const cds = require('@sap/cds')

/**
 * Custom logic for SalesOrderAdvancedService.
 *
 * - Entity reads (SalesOrders / SalesOrderItems) and getOrderTotal are
 *   forwarded to S/4 exactly like the basic service.
 * - The salesByCustomer* functions perform GROUP-BY + SUM in Node.js, because
 *   the remote S/4 OData service cannot do aggregation pushdown.
 */
const PAGE_SIZE = 5000       // OData page size per request (fewer round-trips)
const SAFETY_CAP = 500000    // never fetch more than this many rows

module.exports = class SalesOrderAdvancedService extends cds.ApplicationService {
  async init() {
    const s4 = await cds.connect.to('API_SALES_ORDER_SRV')
    const { A_SalesOrder } = s4.entities
    const { SalesOrders, SalesOrderItems } = this.entities
    const log = cds.log('advanced-mcp')

    // --- pass-through reads (same as basic service) ---
    this.on('READ', SalesOrders, (req) => s4.run(req.query))
    this.on('READ', SalesOrderItems, (req) => s4.run(req.query))

    this.on('getOrderTotal', async (req) => {
      const { salesOrder } = req.data
      const order = await s4.run(
        SELECT.one.from(A_SalesOrder)
          .columns('SalesOrder', 'TotalNetAmount', 'TransactionCurrency')
          .where({ SalesOrder: salesOrder })
      )
      if (!order) return req.error(404, `Sales order ${salesOrder} not found`)
      return { salesOrder: order.SalesOrder, totalNetAmount: order.TotalNetAmount, currency: order.TransactionCurrency }
    })

    // --- helper: page through S/4 and aggregate by SoldToParty in Node ---
    // `rowFilter` (optional) is a JS predicate applied per row AFTER fetching,
    // used for the date range (V2 date-filter pushdown is unreliable, so we
    // filter client-side while paging).
    const aggregateByCustomer = async (rowFilter) => {
      const byCustomer = new Map()
      let fetched = 0
      let considered = 0
      let truncated = false

      for (let skip = 0; skip < SAFETY_CAP; skip += PAGE_SIZE) {
        const page = await s4.run(
          SELECT.from(A_SalesOrder)
            .columns('SalesOrder', 'SoldToParty', 'TotalNetAmount', 'TransactionCurrency', 'CreationDate')
            .limit(PAGE_SIZE, skip)
        )
        if (!page || page.length === 0) break

        for (const row of page) {
          if (rowFilter && !rowFilter(row)) continue
          const key = row.SoldToParty || '(none)'
          const cur = byCustomer.get(key) || { soldToParty: key, orderCount: 0, totalNetAmount: 0 }
          cur.orderCount += 1
          cur.totalNetAmount += Number(row.TotalNetAmount || 0)
          byCustomer.set(key, cur)
          considered += 1
        }
        fetched += page.length
        if (page.length < PAGE_SIZE) break
        if (fetched >= SAFETY_CAP) { truncated = true; break }
      }

      const customers = [...byCustomer.values()]
        .map(c => ({ ...c, totalNetAmount: Math.round(c.totalNetAmount * 100) / 100 }))
        .sort((a, b) => b.totalNetAmount - a.totalNetAmount)

      log.info(`scanned ${fetched} orders, considered ${considered}, ${customers.length} customers (truncated=${truncated})`)
      return { ordersConsidered: considered, truncated, customers }
    }

    // --- ADVANCED: aggregation by date range (filtered client-side) ---
    this.on('salesByCustomerInRange', async (req) => {
      const { fromDate, toDate } = req.data
      if (!fromDate || !toDate) return req.error(400, 'fromDate and toDate are required (YYYY-MM-DD)')
      const from = String(fromDate).slice(0, 10)
      const to = String(toDate).slice(0, 10)
      const inRange = (row) => {
        const d = row.CreationDate ? String(row.CreationDate).slice(0, 10) : null
        return d && d >= from && d <= to
      }
      const { ordersConsidered, customers } = await aggregateByCustomer(inRange)
      return { fromDate: from, toDate: to, ordersConsidered, customers }
    })

    // --- ADVANCED: aggregation across ALL orders (paged) ---
    this.on('salesByCustomerAll', async () => {
      return await aggregateByCustomer(null)
    })

    // --- ADVANCED: best-selling materials by volume (paged over ITEMS) ---
    const { A_SalesOrderItem } = s4.entities
    this.on('topSellingItems', async (req) => {
      const limit = Number(req.data.limit) > 0 ? Number(req.data.limit) : 10
      const byMaterial = new Map()
      let fetched = 0
      let truncated = false

      for (let skip = 0; skip < SAFETY_CAP; skip += PAGE_SIZE) {
        const page = await s4.run(
          SELECT.from(A_SalesOrderItem)
            .columns('Material', 'RequestedQuantity', 'RequestedQuantityUnit', 'NetAmount')
            .limit(PAGE_SIZE, skip)
        )
        if (!page || page.length === 0) break

        for (const row of page) {
          const key = row.Material || '(none)'
          const cur = byMaterial.get(key) || {
            material: key, totalQuantity: 0, lineItemCount: 0, totalNetAmount: 0, units: {}
          }
          cur.totalQuantity += Number(row.RequestedQuantity || 0)
          cur.totalNetAmount += Number(row.NetAmount || 0)
          cur.lineItemCount += 1
          const u = row.RequestedQuantityUnit || '?'
          cur.units[u] = (cur.units[u] || 0) + 1
          byMaterial.set(key, cur)
        }
        fetched += page.length
        if (page.length < PAGE_SIZE) break
        if (fetched >= SAFETY_CAP) { truncated = true; break }
      }

      const materials = [...byMaterial.values()]
        .map(m => ({
          material: m.material,
          totalQuantity: Math.round(m.totalQuantity * 1000) / 1000,
          unit: Object.entries(m.units).sort((a, b) => b[1] - a[1])[0]?.[0] || '?',
          lineItemCount: m.lineItemCount,
          totalNetAmount: Math.round(m.totalNetAmount * 100) / 100
        }))
        .sort((a, b) => b.totalQuantity - a.totalQuantity)
        .slice(0, limit)

      log.info(`topSellingItems: scanned ${fetched} items, ${byMaterial.size} materials, top ${materials.length}`)
      return { itemsConsidered: fetched, truncated, materials }
    })

    await super.init()
  }
}
