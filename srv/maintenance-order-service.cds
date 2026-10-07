using { API_MAINTENANCEORDER as S4M } from './external/API_MAINTENANCEORDER';

/**
 * MCP server for SAP S/4HANA maintenance orders (EAM / Plant Maintenance).
 * Served at /mcp/maintenance-orders. Curated read-only projections over the
 * S/4 API_MAINTENANCEORDER service, resolved via destination QJ6.
 */
@mcp: 'maintenance-orders'
@mcp.instructions: 'Maintenance order (EAM/PM) data for AI agents. Use describe to explore entities and tools, then query for reads. MaintenanceOrders = order headers; MaintenanceOrderOperations = tasks within an order.'
@requires: 'authenticated-user'
service MaintenanceOrderService {

  /** Maintenance order headers (read-only, curated fields). */
  @readonly
  entity MaintenanceOrders as projection on S4M.MaintenanceOrder {
    MaintenanceOrder,
    MaintenanceOrderType,
    MaintenanceOrderDesc,
    MaintPriority,
    MaintenancePlant,
    MainWorkCenter,
    Equipment,
    EquipmentName,
    FunctionalLocation,
    TechnicalObjectLabel,
    MaintenanceNotification,
    MaintenanceActivityType,
    MaintOrdBasicStartDate,
    MaintOrdBasicEndDate,
    MaintOrderActualStartDateTime,
    MaintOrderActualFinishDateTime,
    SystemStatusText,
    UserStatusText,
    MaintOrdPersonResponsible,
    CreatedByUser,
    MaintOrderCreationDateTime,
    to_Operation as Operations
  };

  /** Maintenance order operations / tasks (read-only, curated fields). */
  @readonly
  entity MaintenanceOrderOperations as projection on S4M.MaintenanceOrderOperation {
    MaintenanceOrder,
    MaintenanceOrderOperation,
    OperationDescription,
    WorkCenter,
    Plant,
    OperationControlKey,
    MaintOrderOperationQuantity,
    MaintOrdOperationQuantityUnit,
    MaintOrdOperationWorkDuration,
    MaintOrdOpWorkDurationUnit,
    ActualWorkQuantity,
    OpActualExecutionStartDate,
    OpActualExecutionEndDate,
    SystemStatusText
  };

  /**
   * Return header details for a single maintenance order.
   * @param maintenanceOrder the maintenance order number
   */
  function getOrderDetails(maintenanceOrder : String) returns {
    maintenanceOrder : String;
    description : String;
    priority : String;
    equipment : String;
    functionalLocation : String;
    status : String;
  };
}
