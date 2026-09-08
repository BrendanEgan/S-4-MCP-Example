/**
 * Trimmed, hand-written external model for the SAP S/4HANA OData service
 * `API_SALES_ORDER_SRV` (OData V2).
 *
 * This is a minimal, compilable subset covering the two core entity sets so the
 * MCP demo works end-to-end. For the FULL, authoritative model, replace this file
 * by importing the real EDMX from SAP Business Accelerator Hub:
 *
 *   1. Download API_SALES_ORDER_SRV.edmx from
 *      https://api.sap.com/api/API_SALES_ORDER_SRV/overview
 *   2. Run:  cds import ~/Downloads/API_SALES_ORDER_SRV.edmx --as cds
 *      -> generates srv/external/API_SALES_ORDER_SRV.(csn|cds) + .edmx
 *   3. Delete this hand-written file and keep the generated one.
 *
 * The `@cds.external` marker tells CAP this is a remote (imported) API and must
 * not be deployed to the local database.
 */
@cds.external
service API_SALES_ORDER_SRV {

  /** Sales order header (S/4HANA A_SalesOrder). */
  entity A_SalesOrder {
    /** Sales order number (document ID). */
    key SalesOrder                : String(10);
    /** Sales order type, e.g. OR (standard order). */
    SalesOrderType                : String(4);
    /** Sales organization. */
    SalesOrganization             : String(4);
    /** Distribution channel. */
    DistributionChannel           : String(2);
    /** Division. */
    OrganizationDivision          : String(2);
    /** Sold-to party (customer number). */
    SoldToParty                   : String(10);
    /** Creation date of the sales order. */
    CreationDate                  : Date;
    /** Requested delivery date. */
    RequestedDeliveryDate         : Date;
    /** Total net amount of the order. */
    TotalNetAmount                : Decimal(15, 2);
    /** Currency of the net amount (ISO code). */
    TransactionCurrency           : String(5);
    /** Overall delivery status. */
    OverallDeliveryStatus         : String(1);
    /** Overall status of all order-related billing documents. */
    OverallSDProcessStatus        : String(1);
    /** Associated line items. */
    to_Item                       : Association to many A_SalesOrderItem
                                      on to_Item.SalesOrder = SalesOrder;
  }

  /** Sales order line item (S/4HANA A_SalesOrderItem). */
  entity A_SalesOrderItem {
    /** Sales order number (document ID). */
    key SalesOrder                : String(10);
    /** Sales order item number. */
    key SalesOrderItem            : String(6);
    /** Material number ordered. */
    Material                      : String(40);
    /** Item description / text. */
    SalesOrderItemText            : String(40);
    /** Ordered quantity. */
    RequestedQuantity             : Decimal(15, 3);
    /** Unit of the requested quantity. */
    RequestedQuantityUnit         : String(3);
    /** Net amount of the item. */
    NetAmount                     : Decimal(15, 2);
    /** Currency of the net amount (ISO code). */
    TransactionCurrency           : String(5);
    /** Plant supplying the item. */
    Plant                         : String(4);
    /** Back-association to the header. */
    to_SalesOrder                 : Association to A_SalesOrder
                                      on to_SalesOrder.SalesOrder = SalesOrder;
  }
}
