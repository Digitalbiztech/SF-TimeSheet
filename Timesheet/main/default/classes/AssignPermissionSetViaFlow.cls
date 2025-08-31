public without sharing class AssignPermissionSetViaFlow {
    @InvocableMethod(label='Assign Permission Set')
    public static void assignPermissionSets(List<List<PermissionSetAssignment>> perSetAssignAll) {
        if (perSetAssignAll == null || perSetAssignAll.isEmpty()) {
            System.debug('Input list is null or empty. Exiting method.');
            return;
        }

        List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
        for (List<PermissionSetAssignment> innerList : perSetAssignAll) {
            if (innerList != null) {
                assignmentsToInsert.addAll(innerList);
            }
        }

        if (assignmentsToInsert.isEmpty()) {
            System.debug('No permission set assignments to insert.');
            return;
        }

        Database.SaveResult[] srList = Database.insert(assignmentsToInsert, false, AccessLevel.SYSTEM_MODE);
        for (Database.SaveResult sr : srList) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('The following error has occurred: ' + err.getStatusCode() + ': ' + err.getMessage());
                }
            }
        }
    }
}