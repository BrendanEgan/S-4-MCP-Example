/**
 * Trimmed, hand-written external model for the SAP S/4HANA OData service
 * `API_MAINTENANCEORDER` (OData V2) — verified active on QJ6.
 *
 * Covers the two core entity sets (header + operations) with the real field
 * names discovered from the live $metadata. For the FULL model, import the EDMX:
 *   cds import API_MAINTENANCEORDER.edmx --as cds
 */
@cds.external
service API_MAINTENANCEORDER {

  /** Maintenance order header (S/4HANA MaintenanceOrder). */
  entity MaintenanceOrder {
    key MaintenanceOrder            : String(12);
    MaintenanceOrderType            : String(4);
    MaintenanceOrderDesc            : String(40);
    MaintenanceOrderInternalID      : String(12);
    MaintenanceOrderPlanningCode    : String(1);
    MaintPriority                   : String(1);
    MaintenancePlant                : String(4);
    MaintenancePlanningPlant        : String(4);
    MainWorkCenter                  : String(8);
    Equipment                       : String(18);
    EquipmentName                   : String(40);
    FunctionalLocation              : String(40);
    TechnicalObject                 : String(40);
    TechnicalObjectLabel            : String(40);
    MaintenanceNotification         : String(12);
    MaintenanceActivityType         : String(3);
    CompanyCode                     : String(4);
    CostCenter                      : String(10);
    Currency                        : String(5);
    MaintOrdBasicStartDate          : DateTime;
    MaintOrdBasicEndDate            : DateTime;
    MaintOrderActualStartDateTime   : Timestamp;
    MaintOrderActualFinishDateTime  : Timestamp;
    MaintOrdProcessPhaseCode        : String(2);
    SystemStatusText                : String(200);
    UserStatusText                  : String(200);
    MaintOrdPersonResponsible       : String(12);
    CreatedByUser                   : String(12);
    MaintOrderCreationDateTime      : Timestamp;
    to_Operation                    : Association to many MaintenanceOrderOperation
                                        on to_Operation.MaintenanceOrder = MaintenanceOrder;
  }

  /** Maintenance order operation / task (S/4HANA MaintenanceOrderOperation). */
  entity MaintenanceOrderOperation {
    key MaintenanceOrder            : String(12);
    key MaintenanceOrderOperation   : String(4);
    OperationDescription            : String(40);
    WorkCenter                      : String(8);
    Plant                           : String(4);
    OperationControlKey             : String(4);
    MaintOrderOperationQuantity     : Decimal(13, 3);
    MaintOrdOperationQuantityUnit   : String(3);
    MaintOrdOperationWorkDuration   : Decimal(9, 1);
    MaintOrdOpWorkDurationUnit      : String(3);
    ActualWorkQuantity              : Decimal(13, 3);
    OperationSystemCondition        : String(1);
    OpActualExecutionStartDate      : DateTime;
    OpActualExecutionEndDate        : DateTime;
    SystemStatusText                : String(200);
    to_MaintenanceOrder             : Association to MaintenanceOrder
                                        on to_MaintenanceOrder.MaintenanceOrder = MaintenanceOrder;
  }
}
