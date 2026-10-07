using { API_PRODUCT_SRV as S4P } from './external/API_PRODUCT_SRV';

/**
 * Product Master MCP server for SAP S/4HANA (API_PRODUCT_SRV / A_Product).
 * Served at /mcp/products. Mirrors the Retail Buying Agent's product-master
 * MCP surface: read products + CREATE a product master.
 *
 * NOTE: @cap-js/mcp has no native MCP create, so creation is exposed as the
 * unbound action `createProduct`, which POSTs to S/4 A_Product (deep insert
 * of the EN description), matching the agent's create_product_master payload.
 */
@mcp: 'products'
@mcp.instructions: 'Product master (A_Product) for AI agents. Use describe to explore, query to read/search products, and call createProduct to create a new product master in S/4HANA.'
@requires: 'authenticated-user'
service ProductMasterService {

  /** Product master records (read-only, curated fields). */
  @readonly
  entity Products as projection on S4P.A_Product {
    Product,
    ProductType,
    ProductGroup,
    BaseUnit,
    IndustrySector,
    Division,
    NetWeight,
    WeightUnit,
    to_Description as Descriptions
  };

  /**
   * Create a product master record in S/4HANA (A_Product), with an English
   * description (deep insert). Returns the generated product number.
   *
   * @param productType material/product type, e.g. FASH or FERT (default FASH)
   * @param baseUnit    base unit of measure, e.g. EA, PC, KG (default EA)
   * @param division    division (default '00')
   * @param productGroup material/product group (optional)
   * @param industrySector industry sector, e.g. 'R' retail (optional)
   * @param netWeight   net weight (optional)
   * @param weightUnit  weight unit, e.g. KG (optional)
   * @param description English product description (max 40 chars)
   * @param product     optional external product number (leave empty for internal numbering)
   */
  action createProduct(
    productType    : String,
    baseUnit       : String,
    division       : String,
    productGroup   : String,
    industrySector : String,
    netWeight      : Decimal(13, 3),
    weightUnit     : String,
    description    : String,
    product        : String
  ) returns {
    product : String;
    message : String;
  };
}
