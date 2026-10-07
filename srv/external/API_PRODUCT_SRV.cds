/**
 * Trimmed external model for SAP S/4HANA `API_PRODUCT_SRV` (OData V2) —
 * verified active + creatable on QJ6. Covers A_Product (header) + description.
 * Mirrors the fields used by the Retail Buying Agent's create_product_master.
 */
@cds.external
service API_PRODUCT_SRV {

  /** Product master (S/4HANA A_Product). */
  entity A_Product {
    key Product              : String(40);
    ProductType              : String(4);
    ProductGroup             : String(9);
    BaseUnit                 : String(3);
    IndustrySector           : String(1);
    Division                 : String(2);
    NetWeight                : Decimal(13, 3);
    WeightUnit               : String(3);
    GrossWeight              : Decimal(13, 3);
    ProductGroup_Text        : String(20);
    CreationDate             : DateTime;
    to_Description           : Association to many A_ProductDescription
                                 on to_Description.Product = Product;
  }

  /** Product description (S/4HANA A_ProductDescription). */
  entity A_ProductDescription {
    key Product              : String(40);
    key Language             : String(2);
    ProductDescription       : String(40);
  }
}
