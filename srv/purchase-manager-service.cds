using { API_PRODUCT_SRV as S4P } from './external/API_PRODUCT_SRV';
using { API_PURCHASEORDER_PROCESS_SRV as S4PO } from './external/API_PURCHASEORDER_PROCESS_SRV';
using { API_INBOUND_DELIVERY_SRV as S4ID } from './external/API_INBOUND_DELIVERY_SRV';

/**
 * Purchase Manager MCP server for SAP S/4HANA.
 * Served at /mcp/purchase-manager. One MCP surface covering the data a purchase
 * manager works with, backed by three S/4 OData V2 APIs via destination QJ6:
 *   - API_PRODUCT_SRV               (product master: read + createProduct)
 *   - API_PURCHASEORDER_PROCESS_SRV (purchase orders: read + createPurchaseOrder)
 *   - API_INBOUND_DELIVERY_SRV      (inbound deliveries: read + createInboundDelivery)
 *
 * NOTE: @cap-js/mcp has no native MCP create, so creation is exposed as unbound
 * actions that POST (deep insert) to the respective S/4 entity sets.
 */
@mcp: 'purchase-manager'
@mcp.instructions: 'Purchase Manager data for AI agents: product master, purchase orders and inbound deliveries. Use describe to explore entities and tools, query to read/search. Use createProduct to create a product master, createPurchaseOrder to create a purchase order (header + items), and createInboundDelivery to create an inbound delivery (header + items), all in S/4HANA.'
@requires: 'authenticated-user'
service PurchaseManagerService {

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

  /** Purchase order headers (read-only, curated fields). */
  @readonly
  entity PurchaseOrders as projection on S4PO.A_PurchaseOrder {
    PurchaseOrder,
    PurchaseOrderType,
    CompanyCode,
    PurchasingOrganization,
    PurchasingGroup,
    Supplier,
    DocumentCurrency,
    PurchaseOrderDate,
    CreationDate,
    to_PurchaseOrderItem as Items
  };

  /** Purchase order line items (read-only, curated fields). */
  @readonly
  entity PurchaseOrderItems as projection on S4PO.A_PurchaseOrderItem {
    PurchaseOrder,
    PurchaseOrderItem,
    Material,
    PurchaseOrderItemText,
    Plant,
    OrderQuantity,
    PurchaseOrderQuantityUnit,
    NetPriceAmount,
    DocumentCurrency
  };

  /** Inbound delivery headers (read-only, curated fields). */
  @readonly
  entity InboundDeliveries as projection on S4ID.A_InbDeliveryHeader {
    DeliveryDocument,
    DeliveryDocumentType,
    Supplier,
    ShipToParty,
    DocumentDate,
    DeliveryDate,
    to_DeliveryDocumentItem as Items
  };

  /** Inbound delivery line items (read-only, curated fields). */
  @readonly
  entity InboundDeliveryItems as projection on S4ID.A_InbDeliveryItem {
    DeliveryDocument,
    DeliveryDocumentItem,
    Material,
    DeliveryDocumentItemText,
    Plant,
    ActualDeliveryQuantity,
    DeliveryQuantityUnit,
    ReferenceSDDocument,
    ReferenceSDDocumentItem
  };

  /**
   * Create a product master record in S/4HANA (A_Product), with an English
   * description (deep insert). Returns the generated product number.
   *
   * @param productType    material/product type, e.g. FASH or FERT (default FASH)
   * @param baseUnit       base unit of measure, e.g. EA, PC, KG (default EA)
   * @param division       division (default '00')
   * @param productGroup   material/product group (optional)
   * @param industrySector industry sector, e.g. 'R' retail (optional)
   * @param netWeight      net weight (optional)
   * @param weightUnit     weight unit, e.g. KG (optional)
   * @param description    English product description (max 40 chars)
   * @param product        optional external product number (empty = internal numbering)
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

  /** A single purchase order item to create. */
  type PurchaseOrderItemInput {
    /** Material number. */
    material       : String;
    /** Plant. */
    plant          : String;
    /** Ordered quantity. */
    orderQuantity  : Decimal(13, 3);
    /** Order quantity unit of measure, e.g. PC, EA, KG. */
    quantityUnit   : String;
    /** Net price amount (optional). */
    netPriceAmount : Decimal(11, 2);
    /** Item short text (optional, max 40 chars). */
    itemText       : String;
  }

  /**
   * Create a purchase order in S/4HANA (A_PurchaseOrder) with one or more items
   * (deep insert into to_PurchaseOrderItem). Returns the generated PO number.
   *
   * @param purchaseOrderType      PO type, e.g. NB (default NB)
   * @param companyCode            company code
   * @param purchasingOrganization purchasing organization
   * @param purchasingGroup        purchasing group
   * @param supplier               supplier (vendor) number
   * @param documentCurrency       document currency, e.g. EUR (default EUR)
   * @param items                  one or more purchase order items
   */
  action createPurchaseOrder(
    purchaseOrderType      : String,
    companyCode            : String,
    purchasingOrganization : String,
    purchasingGroup        : String,
    supplier               : String,
    documentCurrency       : String,
    items                  : many PurchaseOrderItemInput
  ) returns {
    purchaseOrder : String;
    message       : String;
  };

  /** A single inbound delivery item to create. */
  type InboundDeliveryItemInput {
    /** Material number. */
    material                   : String;
    /** Plant. */
    plant                      : String;
    /** Actual delivery quantity. */
    deliveryQuantity           : Decimal(13, 3);
    /** Delivery quantity unit of measure, e.g. PC, EA, KG. */
    quantityUnit               : String;
    /** Reference purchase order (optional). */
    referencePurchaseOrder     : String;
    /** Reference purchase order item (optional). */
    referencePurchaseOrderItem : String;
    /** Item short text (optional, max 40 chars). */
    itemText                   : String;
  }

  /**
   * Create an inbound delivery in S/4HANA (A_InbDeliveryHeader) with one or more
   * items (deep insert into to_DeliveryDocumentItem). Returns the generated
   * delivery document number.
   *
   * @param deliveryDocumentType delivery type, e.g. EL (default EL)
   * @param supplier             supplier (vendor) number
   * @param shipToParty          ship-to party (optional)
   * @param items                one or more inbound delivery items
   */
  action createInboundDelivery(
    deliveryDocumentType : String,
    supplier             : String,
    shipToParty          : String,
    items                : many InboundDeliveryItemInput
  ) returns {
    deliveryDocument : String;
    message          : String;
  };
}

