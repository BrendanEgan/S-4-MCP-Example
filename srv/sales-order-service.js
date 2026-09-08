const cds = require('@sap/cds')

/**
 * Custom logic for SalesOrderService.
 *
 * - Delegates the READ of SalesOrders / SalesOrderItems to the remote S/4HANA
 *   service (API_SALES_ORDER_SRV) via the BTP Destination Service.
 * - Implements the unbound `getOrderTotal` function.
 */
module.exports = class SalesOrderService extends cds.ApplicationService {
  async init() {
    // Connect to the remote S/4HANA OData service (destination-backed in prod,
    // mock-backed locally — see package.json `requires`).
    const s4 = await cds.connect.to('API_SALES_ORDER_SRV')

    const { SalesOrders, SalesOrderItems } = this.entities

    // Forward reads to S/4HANA, then stamp each row with an MCP marker so you
    // can see the CAP layer added a field that is not present in S/4.
    this.on('READ', SalesOrders, async (req) => {
      const rows = await s4.run(req.query)
      const stamp = (r) => { if (r) r.mcpNote = 'this came from an MCP' }
      if (Array.isArray(rows)) rows.forEach(stamp)
      else stamp(rows)
      return rows
    })

    this.on('READ', SalesOrderItems, (req) => {
      return s4.run(req.query)
    })

    // Unbound function: compute the order total from S/4.
    this.on('getOrderTotal', async (req) => {
      const { salesOrder } = req.data
      const { A_SalesOrder } = s4.entities
      const order = await s4.run(
        SELECT.one
          .from(A_SalesOrder)
          .columns('SalesOrder', 'TotalNetAmount', 'TransactionCurrency')
          .where({ SalesOrder: salesOrder })
      )
      if (!order) return req.error(404, `Sales order ${salesOrder} not found`)
      // return {
      //   salesOrder: order.SalesOrder,
      //   totalNetAmount: order.TotalNetAmount,
      //   currency: order.TransactionCurrency
      // }
      return {
        message: "Hey you ran a MCP function!"
      }
    })

    await super.init()
  }
}
