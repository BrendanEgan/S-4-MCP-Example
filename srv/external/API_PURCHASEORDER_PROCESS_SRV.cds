/**
 * Trimmed, hand-written external model for the SAP S/4HANA OData service
 * `API_PURCHASEORDER_PROCESS_SRV` (OData V2) — purchase order processing.
 *
 * Minimal, compilable subset covering the header (A_PurchaseOrder) + item
 * (A_PurchaseOrderItem) entity sets so the Purchase Manager MCP can CREATE a
 * purchase order via a deep insert. Field names match the live $metadata on QJ6.
 *
 * For the FULL, authoritative model, replace this file by importing the EDMX:
 *   cds import API_PURCHASEORDER_PROCESS_SRV.edmx --as cds
 *
 * `@cds.external` marks this as a remote (imported) API — never deployed locally.
 */
@cds.external
service API_PURCHASEORDER_PROCESS_SRV {

  /** Purchase order header (S/4HANA A_PurchaseOrder). */
  entity A_PurchaseOrder {
    /** Purchase order number (document ID, internally assigned on create). */
    key PurchaseOrder            : String(10);
    /** Purchase order type, e.g. NB (standard PO). */
    PurchaseOrderType            : String(4);
    /** Company code. */
    CompanyCode                  : String(4);
    /** Purchasing organization. */
    PurchasingOrganization       : String(4);
    /** Purchasing group. */
    PurchasingGroup              : String(3);
    /** Supplier (vendor) number. */
    Supplier                     : String(10);
    /** Document (order) currency, e.g. EUR. */
    DocumentCurrency             : String(5);
    /** Purchase order date. */
    PurchaseOrderDate            : Date;
    /** Creation date of the PO. */
    CreationDate                 : Date;
    /** Items of this purchase order. */
    to_PurchaseOrderItem         : Association to many A_PurchaseOrderItem
                                     on to_PurchaseOrderItem.PurchaseOrder = PurchaseOrder;
  }

  /** Purchase order item (S/4HANA A_PurchaseOrderItem). */
  entity A_PurchaseOrderItem {
    /** Purchase order number. */
    key PurchaseOrder             : String(10);
    /** Purchase order item number, e.g. '00010'. */
    key PurchaseOrderItem         : String(5);
    /** Material number. */
    Material                      : String(40);
    /** Short text / description of the item. */
    PurchaseOrderItemText         : String(40);
    /** Plant. */
    Plant                         : String(4);
    /** Ordered quantity. */
    OrderQuantity                 : Decimal(13, 3);
    /** Purchase order quantity unit of measure. */
    PurchaseOrderQuantityUnit     : String(3);
    /** Net price amount. */
    NetPriceAmount                : Decimal(11, 2);
    /** Document currency of the item. */
    DocumentCurrency              : String(5);
  }
}
