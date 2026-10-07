const cds = require('@sap/cds')

/**
 * Custom logic for MaintenanceOrderService.
 * Forwards reads to the remote S/4 API_MAINTENANCEORDER via destination QJ6,
 * and implements the getOrderDetails function.
 */
module.exports = class MaintenanceOrderService extends cds.ApplicationService {
  async init() {
    const s4 = await cds.connect.to('API_MAINTENANCEORDER')
    const { MaintenanceOrders, MaintenanceOrderOperations } = this.entities
    const { MaintenanceOrder } = s4.entities

    this.on('READ', MaintenanceOrders, (req) => s4.run(req.query))
    this.on('READ', MaintenanceOrderOperations, (req) => s4.run(req.query))

    this.on('getOrderDetails', async (req) => {
      const { maintenanceOrder } = req.data
      const o = await s4.run(
        SELECT.one.from(MaintenanceOrder)
          .columns('MaintenanceOrder', 'MaintenanceOrderDesc', 'MaintPriority',
                   'Equipment', 'FunctionalLocation', 'SystemStatusText')
          .where({ MaintenanceOrder: maintenanceOrder })
      )
      if (!o) return req.error(404, `Maintenance order ${maintenanceOrder} not found`)
      return {
        maintenanceOrder: o.MaintenanceOrder,
        description: o.MaintenanceOrderDesc,
        priority: o.MaintPriority,
        equipment: o.Equipment,
        functionalLocation: o.FunctionalLocation,
        status: o.SystemStatusText
      }
    })

    await super.init()
  }
}
