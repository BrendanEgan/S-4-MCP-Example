const cds = require('@sap/cds')

/**
 * Custom logic for PurchaseManagerService.
 *
 * Reads are forwarded to the remote S/4 OData services (destination QJ6):
 *   - Products                               -> API_PRODUCT_SRV
 *   - PurchaseOrders / PurchaseOrderItems    -> API_PURCHASEORDER_PROCESS_SRV
 *   - InboundDeliveries / *Items             -> API_INBOUND_DELIVERY_SRV
 *
 * Creates are exposed as unbound actions (MCP has no native create) and POST a
 * deep insert (header + items) to the respective S/4 entity set.
 */
module.exports = class PurchaseManagerService extends cds.ApplicationService {
  async init() {
    const prod = await cds.connect.to('API_PRODUCT_SRV')
    const po = await cds.connect.to('API_PURCHASEORDER_PROCESS_SRV')
    const inb = await cds.connect.to('API_INBOUND_DELIVERY_SRV')

    const { Products, PurchaseOrders, PurchaseOrderItems, InboundDeliveries, InboundDeliveryItems } = this.entities
    const { A_Product } = prod.entities
    const { A_PurchaseOrder } = po.entities
    const { A_InbDeliveryHeader } = inb.entities
    const log = cds.log('purchase-manager-mcp')

    // --- pass-through reads ---
    this.on('READ', Products, (req) => prod.run(req.query))
    this.on('READ', PurchaseOrders, (req) => po.run(req.query))
    this.on('READ', PurchaseOrderItems, (req) => po.run(req.query))
    this.on('READ', InboundDeliveries, (req) => inb.run(req.query))
    this.on('READ', InboundDeliveryItems, (req) => inb.run(req.query))

    // --- createProduct (deep insert: header + EN description) ---
    this.on('createProduct', async (req) => {
      const d = req.data
      const desc = (d.description || '').slice(0, 40)
      const entry = {
        ProductType: d.productType || 'FASH',
        BaseUnit: d.baseUnit || 'EA',
        Division: d.division || '00',
        to_Description: [{ Language: 'EN', ProductDescription: desc }]
      }
      if (d.product) entry.Product = d.product
      if (d.productGroup) entry.ProductGroup = d.productGroup
      if (d.industrySector) entry.IndustrySector = d.industrySector
      if (d.netWeight != null) entry.NetWeight = d.netWeight
      if (d.weightUnit) entry.WeightUnit = d.weightUnit

      try {
        const created = await prod.run(INSERT.into(A_Product).entries(entry))
        const productNo = (created && (created.Product || (Array.isArray(created) && created[0] && created[0].Product))) || d.product
        log.info(`createProduct: created ${productNo}`)
        return { product: productNo || '(unknown)', message: 'Product master created' }
      } catch (e) {
        log.error('createProduct failed', e && e.message)
        return req.error(502, `Product creation failed: ${(e && e.message) || e}`)
      }
    })

    // --- createPurchaseOrder (deep insert: header + items) ---
    this.on('createPurchaseOrder', async (req) => {
      const d = req.data
      const items = Array.isArray(d.items) ? d.items : []
      if (items.length === 0) return req.error(400, 'At least one item is required')

      const entry = {
        PurchaseOrderType: d.purchaseOrderType || 'NB',
        DocumentCurrency: d.documentCurrency || 'EUR',
        to_PurchaseOrderItem: items.map((it, i) => {
          const item = {
            PurchaseOrderItem: String((i + 1) * 10).padStart(5, '0'),
            Material: it.material,
            Plant: it.plant,
            OrderQuantity: it.orderQuantity,
            PurchaseOrderQuantityUnit: it.quantityUnit
          }
          if (it.netPriceAmount != null) item.NetPriceAmount = it.netPriceAmount
          if (it.itemText) item.PurchaseOrderItemText = String(it.itemText).slice(0, 40)
          return item
        })
      }
      if (d.companyCode) entry.CompanyCode = d.companyCode
      if (d.purchasingOrganization) entry.PurchasingOrganization = d.purchasingOrganization
      if (d.purchasingGroup) entry.PurchasingGroup = d.purchasingGroup
      if (d.supplier) entry.Supplier = d.supplier

      try {
        const created = await po.run(INSERT.into(A_PurchaseOrder).entries(entry))
        const poNo = (created && (created.PurchaseOrder || (Array.isArray(created) && created[0] && created[0].PurchaseOrder))) || null
        log.info(`createPurchaseOrder: created ${poNo}`)
        return { purchaseOrder: poNo || '(unknown)', message: 'Purchase order created' }
      } catch (e) {
        log.error('createPurchaseOrder failed', e && e.message)
        return req.error(502, `Purchase order creation failed: ${(e && e.message) || e}`)
      }
    })

    // --- createInboundDelivery (deep insert: header + items) ---
    this.on('createInboundDelivery', async (req) => {
      const d = req.data
      const items = Array.isArray(d.items) ? d.items : []
      if (items.length === 0) return req.error(400, 'At least one item is required')

      const entry = {
        DeliveryDocumentType: d.deliveryDocumentType || 'EL',
        to_DeliveryDocumentItem: items.map((it, i) => {
          const item = {
            DeliveryDocumentItem: String((i + 1) * 10).padStart(6, '0'),
            Material: it.material,
            Plant: it.plant,
            ActualDeliveryQuantity: it.deliveryQuantity,
            DeliveryQuantityUnit: it.quantityUnit
          }
          if (it.referencePurchaseOrder) item.ReferenceSDDocument = it.referencePurchaseOrder
          if (it.referencePurchaseOrderItem) item.ReferenceSDDocumentItem = it.referencePurchaseOrderItem
          if (it.itemText) item.DeliveryDocumentItemText = String(it.itemText).slice(0, 40)
          return item
        })
      }
      if (d.supplier) entry.Supplier = d.supplier
      if (d.shipToParty) entry.ShipToParty = d.shipToParty

      try {
        const created = await inb.run(INSERT.into(A_InbDeliveryHeader).entries(entry))
        const delivNo = (created && (created.DeliveryDocument || (Array.isArray(created) && created[0] && created[0].DeliveryDocument))) || null
        log.info(`createInboundDelivery: created ${delivNo}`)
        return { deliveryDocument: delivNo || '(unknown)', message: 'Inbound delivery created' }
      } catch (e) {
        log.error('createInboundDelivery failed', e && e.message)
        return req.error(502, `Inbound delivery creation failed: ${(e && e.message) || e}`)
      }
    })

    await super.init()

  }
}
