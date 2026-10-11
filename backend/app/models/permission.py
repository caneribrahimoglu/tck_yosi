from enum import Enum


class AppPermission(str, Enum):
    viewAssignedVehicle = "viewAssignedVehicle"
    viewVehicleFleet = "viewVehicleFleet"
    manageVehicleFleet = "manageVehicleFleet"
    receiveVehicle = "receiveVehicle"
    returnVehicle = "returnVehicle"
    updateMileage = "updateMileage"
    createFuelRecord = "createFuelRecord"
    createVehicleFaultRecord = "createVehicleFaultRecord"
    createVehicleMaintenanceRecord = "createVehicleMaintenanceRecord"
    reviewVehicleFaults = "reviewVehicleFaults"
    createFieldReport = "createFieldReport"
    viewPersonnel = "viewPersonnel"
    managePersonnel = "managePersonnel"
    viewReports = "viewReports"
    approveOperations = "approveOperations"
    manageUsers = "manageUsers"
    assignTechnicalWork = "assignTechnicalWork"
    startTechnicalWork = "startTechnicalWork"
    addTechnicalWorkProgress = "addTechnicalWorkProgress"
    pauseTechnicalWork = "pauseTechnicalWork"
    resumeTechnicalWork = "resumeTechnicalWork"
    requestTechnicalWorkCompletion = "requestTechnicalWorkCompletion"
    reviewTechnicalWorkCompletion = "reviewTechnicalWorkCompletion"
    viewAllTechnicalWork = "viewAllTechnicalWork"
    manageTeamPermissions = "manageTeamPermissions"


# Explicit bootstrap grants, stored on the account. Runtime authorization must
# inspect stored permissions, never infer these grants from the role.
INITIAL_CHIEF_PERMISSIONS = tuple(
    permission.value
    for permission in AppPermission
    if permission not in {
        AppPermission.receiveVehicle,
        AppPermission.returnVehicle,
        AppPermission.updateMileage,
        AppPermission.createFuelRecord,
    }
)
