/**
 * Trimmed, hand-written external model for the SAP S/4HANA OData service
 * `API_INBOUND_DELIVERY_SRV` (OData V2) — inbound deliveries.
 *
 * Minimal, compilable subset covering the header (A_InbDeliveryHeader) + item
 * (A_InbDeliveryItem) entity sets so the Purchase Manager MCP can CREATE an
 * inbound delivery via a deep insert. Field names match the live $metadata on QJ6.
 *
 * For the FULL, authoritative model, replace this file by importing the EDMX:
 *   cds import API_INBOUND_DELIVERY_SRV.edmx --as cds
 *
 * `@cds.external` marks this as a remote (imported) API — never deployed locally.
 */
@cds.external
service API_INBOUND_DELIVERY_SRV {

  /** Inbound delivery header (S/4HANA A_InbDeliveryHeader). */
  entity A_InbDeliveryHeader {
    /** Inbound delivery document number (internally assigned on create). */
    key DeliveryDocument              : String(10);
    /** Delivery document type, e.g. EL (inbound delivery). */
    DeliveryDocumentType              : String(4);
    /** Supplier (vendor) number. */
    Supplier                          : String(10);
    /** Ship-to party. */
    ShipToParty                       : String(10);
    /** Document date. */
    DocumentDate                      : Date;
    /** Planned goods-receipt / delivery date. */
    DeliveryDate                      : DateTime;
    /** Items of this inbound delivery. */
    to_DeliveryDocumentItem           : Association to many A_InbDeliveryItem
                                          on to_DeliveryDocumentItem.DeliveryDocument = DeliveryDocument;
  }

  /** Inbound delivery item (S/4HANA A_InbDeliveryItem). */
  entity A_InbDeliveryItem {
    /** Inbound delivery document number. */
    key DeliveryDocument              : String(10);
    /** Delivery item number, e.g. '000010'. */
    key DeliveryDocumentItem          : String(6);
    /** Material number. */
    Material                          : String(40);
    /** Item short text / description. */
    DeliveryDocumentItemText          : String(40);
    /** Plant. */
    Plant                             : String(4);
    /** Actual delivery quantity. */
    ActualDeliveryQuantity            : Decimal(13, 3);
    /** Base unit of measure for the delivery quantity. */
    DeliveryQuantityUnit              : String(3);
    /** Reference purchase order (if the delivery is created against a PO). */
    ReferenceSDDocument               : String(10);
    /** Reference purchase order item. */
    ReferenceSDDocumentItem           : String(6);
  }
}
