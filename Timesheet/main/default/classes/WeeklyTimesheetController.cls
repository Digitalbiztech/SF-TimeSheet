public with sharing class WeeklyTimesheetController {

    @AuraEnabled(cacheable=true)
    public static Timesheet__c getTimesheet(Id timesheetId){
        try {
            return [select Id,
                    name,
                    Employee__c, 
                    Start_Date__c, 
                    End_Date__c 
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
                    End_Date__c 
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
}