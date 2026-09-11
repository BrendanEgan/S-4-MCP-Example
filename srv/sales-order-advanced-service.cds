using { API_SALES_ORDER_SRV as S4 } from './external/API_SALES_ORDER_SRV';

/**
 * ADVANCED MCP server for SAP S/4HANA sales orders.
 *
 * Separate MCP endpoint at `/mcp/sales-orders-advanced`
 * (@mcp: 'sales-orders-advanced'), independent from the basic SalesOrderService.
 *
 * SUPERSET of the basic service: same read-only entities (so `describe` +
 * `query` work identically) PLUS purpose-built aggregation functions that
 * showcase what a tailored MCP server can do that the generic `query` tool
 * cannot — SERVER-SIDE GROUP-BY + SUM, which the remote S/4 OData service does
 * not support as pushdown, so it is performed in CAP (Node.js).
 */
@mcp: 'sales-orders-advanced'
@requires: 'authenticated-user'
service SalesOrderAdvancedService {

  /** Sales order headers (read-only, curated fields). */
  @readonly
  entity SalesOrders as projection on S4.A_SalesOrder {
    SalesOrder,
    SalesOrderType,
    SoldToParty,
    SalesOrganization,
    CreationDate,
    RequestedDeliveryDate,
    TotalNetAmount,
    TransactionCurrency,
    OverallDeliveryStatus,
    OverallSDProcessStatus,
    to_Item as Items
  };

  /** Sales order line items (read-only, curated fields). */
  @readonly
  entity SalesOrderItems as projection on S4.A_SalesOrderItem {
    SalesOrder,
    SalesOrderItem,
    Material,
    SalesOrderItemText,
    RequestedQuantity,
    RequestedQuantityUnit,
    NetAmount,
    TransactionCurrency,
    Plant
  };

  /**
   * Return the total net amount for a single sales order.
   * @param salesOrder the sales order number to look up
   */
  function getOrderTotal(salesOrder : String) returns {
    salesOrder : String;
    totalNetAmount : Decimal(15, 2);
    currency : String;
  };

  /**
   * ADVANCED: Total net sales amount and order count per customer
   * (SoldToParty), for sales orders whose CreationDate is within the given
   * range. The date filter is pushed to S/4 as an OData $filter, so only
   * matching rows are transferred, then grouped/summed in CAP.
   *
   * @param fromDate inclusive start date (YYYY-MM-DD)
   * @param toDate   inclusive end date (YYYY-MM-DD)
   */
  function salesByCustomerInRange(fromDate : Date, toDate : Date) returns {
    fromDate : Date;
    toDate : Date;
    ordersConsidered : Integer;
    customers : many {
      soldToParty : String;
      orderCount : Integer;
      totalNetAmount : Decimal(15, 2);
    };
  };

  /**
   * ADVANCED: Total net sales amount and order count per customer
   * (SoldToParty) across ALL sales orders. Pages through the full dataset from
   * S/4 (which cannot do group-by pushdown), then aggregates in CAP. A safety
   * cap limits the maximum number of rows fetched.
   */
  function salesByCustomerAll() returns {
    ordersConsidered : Integer;
    truncated : Boolean;
    customers : many {
      soldToParty : String;
      orderCount : Integer;
      totalNetAmount : Decimal(15, 2);
    };
  };

  /**
   * ADVANCED: Best-selling materials by volume. Pages through ALL sales order
   * ITEMS from S/4 (which cannot do group-by pushdown), sums RequestedQuantity
   * per Material in CAP, and returns the top-N by total quantity. Also reports
   * total net amount and line-item count per material.
   *
   * NOTE: quantities are summed per material but may span different units of
   * measure (e.g. PC, KG). The dominant unit seen for the material is reported.
   *
   * @param limit maximum number of top materials to return (default 10)
   */
  function topSellingItems(limit : Integer) returns {
    itemsConsidered : Integer;
    truncated : Boolean;
    materials : many {
      material : String;
      totalQuantity : Decimal(18, 3);
      unit : String;
      lineItemCount : Integer;
      totalNetAmount : Decimal(15, 2);
    };
  };

  /**
   * ADVANCED (FAST): Top-selling materials by ordered quantity, computed by the
   * S/4 ANALYTICAL query view C_SALESORDERITEMQRY (measure
   * IncomingSalesOrdersQuantity). The group-by/aggregation runs IN HANA and only
   * the aggregated top-N rows are returned — no full-table scan in the app.
   * This is the architecturally-correct "aggregate at the data" approach.
   *
   * @param limit maximum number of top products to return (default 10)
   */
  function topSellingItemsFast(limit : Integer) returns {
    source : String;
    products : many {
      product : String;
      incomingQuantity : Decimal(18, 3);
    };
  };


}
