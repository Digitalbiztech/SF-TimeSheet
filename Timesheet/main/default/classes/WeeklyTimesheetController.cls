public with sharing class WeeklyTimesheetController {

    @AuraEnabled(cacheable=true)
    public static Boolean isPartialSubmitAllowed() {
        try {
            Timesheet_Default_Value__mdt[] mdts = [
                SELECT Allow_Partial_Submit__c
                FROM Timesheet_Default_Value__mdt
                LIMIT 1
            ];
            if (!mdts.isEmpty() && mdts[0].Allow_Partial_Submit__c != null) {
                return mdts[0].Allow_Partial_Submit__c;
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Timesheet__c getTimesheet(Id timesheetId){
        try {
            return [select Id,
                    name,
                    Employee__c, 
                    Start_Date__c, 
                    End_Date__c,
                    Status__c
                    from Timesheet__c 
                    WHERE Id = :timesheetId
                    WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Timesheet__c> getEmployeeTimesheetItems(String empId, String recordId){
        try {
            return [select Id,
                    Name,
                    Employee__c, 
                    Start_Date__c, 
                    End_Date__c,
                    Status__c
                    from Timesheet__c 
                    WHERE Employee__c = :empId
                    and id != :recordId
                    WITH SECURITY_ENFORCED
                    ORDER BY Start_Date__c DESC
                    LIMIT 10
                    ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Project_Employee__c> getProjects(String empId){
        try {
            return [SELECT Id,
                    Name, 
                    Project__c, 
                    Project__r.Name, 
                    Employee__c,
                    Hourly_Rate__c,
                    Project__r.Billable__c,
                    Project__r.Active__c
                    FROM Project_Employee__c 
                    WHERE Employee__c = :empId
                    WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Project_Activity__c> getProjectActivities(List<Id> projectIds){
        try {
            return [SELECT id,
                    name,
                    Project__c 
                    FROM Project_Activity__c 
                    WHERE Project__c IN :projectIds
                    WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Timesheet_Line_Item__c> getWeeklyTimesheetItems(Id timesheetId){
        try {
            return [SELECT Id,
                    Type__c, 
                    Timesheet__c,
                    Date__c,
                    Project__c,
                    Activity__c,
                    Absence_Category__c,
                    Description__c,
                    Duration__c,
                    Line_Item_Status__c,
                    Rejection_Notes__c,
                    Project__r.Billable__c
                    FROM Timesheet_Line_Item__c
                    WHERE Timesheet__c = :timesheetId
                    WITH SECURITY_ENFORCED
                    ORDER BY Date__c ASC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String upsertLineItems(List<Timesheet_Line_Item__c> lineItems) {
        if(lineItems == null || lineItems.isEmpty()){
            return 'Error: No Timesheet Line Items provided.';
        }
        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                lineItems,
                true
            );
            upsert decision.getRecords();
            return 'Success';
        } catch(Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String deleteTimesheetLineItems(List<Timesheet_Line_Item__c> lineItemIds) {
        if(lineItemIds == null || lineItemIds.isEmpty()){
            return 'Error: No Timesheet Line Items provided.';
        }
        try {
            delete as user lineItemIds;
            return 'Success';
        } catch(Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String submitPartialLineItems(Id timesheetId, List<Id> lineItemIds) {
        if (timesheetId == null || lineItemIds == null || lineItemIds.isEmpty()) {
            return 'Error: Please provide valid Timesheet and Line Items.';
        }
        try {
            List<Timesheet_Line_Item__c> itemsToUpdate = [
                SELECT Id, Line_Item_Status__c, Date__c
                FROM Timesheet_Line_Item__c
                WHERE Id IN :lineItemIds AND Timesheet__c = :timesheetId
                WITH SECURITY_ENFORCED
            ];
            if (itemsToUpdate.isEmpty()) {
                return 'Error: No matching line items found.';
            }
            for (Timesheet_Line_Item__c li : itemsToUpdate) {
                li.Line_Item_Status__c = 'Partial Submitted';
            }
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, itemsToUpdate, true);
            update decision.getRecords();

            Timesheet__c ts = new Timesheet__c(
                Id = timesheetId,
                Status__c = 'Partial'
            );
            SObjectAccessDecision tsDecision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Timesheet__c>{ ts }, true);
            update tsDecision.getRecords();

            return 'Success';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String submitTimesheet(Id timesheetId) {
        if (timesheetId == null) {
            return 'Error: Please provide a valid Timesheet Id.';
        }
        try {
            // Validate pre-condition: Timesheet must be New or Partial
            Timesheet__c ts = [
                SELECT Id, Status__c
                FROM Timesheet__c
                WHERE Id = :timesheetId
                WITH SECURITY_ENFORCED
            ];
            if (ts.Status__c != 'New' && ts.Status__c != 'Partial') {
                return 'Error: Timesheet can only be submitted when in New or Partial status.';
            }

            // Update all line items to Submitted, EXCEPT Partial Approved
            List<Timesheet_Line_Item__c> lineItems = [
                SELECT Id, Line_Item_Status__c
                FROM Timesheet_Line_Item__c
                WHERE Timesheet__c = :timesheetId
                AND Line_Item_Status__c != 'Partial Approved'
                WITH SECURITY_ENFORCED
            ];
            for (Timesheet_Line_Item__c li : lineItems) {
                li.Line_Item_Status__c = 'Submitted';
            }
            if (!lineItems.isEmpty()) {
                SObjectAccessDecision liDecision = Security.stripInaccessible(AccessType.UPDATABLE, lineItems, true);
                update liDecision.getRecords();
            }

            // Update Timesheet to Submitted
            ts.Status__c = 'Submitted';
            SObjectAccessDecision tsDecision = Security.stripInaccessible(
                AccessType.UPDATABLE, new List<Timesheet__c>{ ts }, true
            );
            update tsDecision.getRecords();

            return 'Success';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
}