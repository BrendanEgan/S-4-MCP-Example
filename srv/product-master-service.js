const cds = require('@sap/cds')

/**
 * Custom logic for ProductMasterService.
 * - Reads forwarded to remote API_PRODUCT_SRV (destination QJ6).
 * - createProduct: deep-insert POST to A_Product (header + EN description),
 *   mirroring the Retail Buying Agent's create_product_master payload.
 */
module.exports = class ProductMasterService extends cds.ApplicationService {
  async init() {
    const s4 = await cds.connect.to('API_PRODUCT_SRV')
    const { Products } = this.entities
    const { A_Product } = s4.entities
    const log = cds.log('product-mcp')

    this.on('READ', Products, (req) => s4.run(req.query))

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
        const created = await s4.run(INSERT.into(A_Product).entries(entry))
        const productNo = (created && (created.Product || (Array.isArray(created) && created[0] && created[0].Product))) || d.product
        log.info(`createProduct: created ${productNo}`)
        return { product: productNo || '(unknown)', message: 'Product master created' }
      } catch (e) {
        log.error('createProduct failed', e && e.message)
        return req.error(502, `Product creation failed: ${(e && e.message) || e}`)
      }
    })

    await super.init()
  }
}
