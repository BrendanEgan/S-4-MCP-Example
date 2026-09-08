using { API_SALES_ORDER_SRV as S4 } from './external/API_SALES_ORDER_SRV';

/**
 * MCP-facing CAP service for SAP S/4HANA sales orders.
 *
 * The `@mcp` annotation exposes this service as an MCP (Model Context Protocol)
 * server at `/mcp/SalesOrderService`, giving AI agents three auto-generated
 * tools: `describe`, `query`, and `call_action`.
 *
 * The projections below shape / restrict what the LLM can see (a curated,
 * read-only subset of the underlying S/4HANA API). CAP resolves the actual
 * S/4 calls through the BTP Destination Service (destination `QJ6` in this
 * subaccount) — the agent never sees S/4 credentials.
 *
 * @requires 'authenticated-user' — only authenticated callers may use the MCP
 * endpoint. Never expose this service to untrusted agents (the MCP adapter
 * performs no prompt-injection input/output validation).
 */
@mcp: 'sales-orders'
@requires: 'authenticated-user'
service SalesOrderService {

  /** Sales order headers exposed to AI agents (read-only, curated fields). */
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
    to_Item as Items,
    /** Marker added by the CAP service on every read (not from S/4). */
    virtual null as mcpNote : String
  };

  /** Sales order line items exposed to AI agents (read-only, curated fields). */
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
   * Exposed as an unbound action so it is available as an MCP `call_action` tool
   * (the MCP adapter surfaces unbound actions/functions to agents).
   *
   * @param salesOrder the sales order number to look up
   */
  function getOrderTotal(salesOrder : String) returns {
    salesOrder : String;
    totalNetAmount : Decimal(15, 2);
    currency : String;
  };
}
