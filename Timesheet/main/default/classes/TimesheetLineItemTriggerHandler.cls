public with sharing class TimesheetLineItemTriggerHandler {
    
    public static void beforeInsert(List<Timesheet_Line_Item__c> timesheetLineItems){
        updateEmployeeId(timesheetLineItems);
        updateBillableField(timesheetLineItems);
        checkForDuplicateTimesheetLineItem(timesheetLineItems);
    }
    
    public static void beforeUpdate(List<Timesheet_Line_Item__c> timesheetLineItems){
        checkForDuplicateTimesheetLineItem(timesheetLineItems);
    }
    
    public static void updateEmployeeId(List<Timesheet_Line_Item__c> timesheetLineItems){
        Set<Id> masterIds = new Set<Id>();
        for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
            masterIds.add(timesheetLineItem.Timesheet__c);
        }
        if(Timesheet__c.SObjectType.getDescribe().isAccessible() &&
        Schema.SObjectType.Timesheet__c.fields.Employee__c.isAccessible()) {
            Map<Id, Timesheet__c> timesheetMap = new Map<Id, Timesheet__c>([SELECT
                                                            Id,
                                                            Employee__c 
                                                            FROM Timesheet__c
                                                            WHERE Id = :masterIds 
                                                            WITH SECURITY_ENFORCED]);
            if(timesheetMap.size() > 0 && Timesheet_Line_Item__c.SObjectType.getDescribe().isCreateable() &&
            Schema.SObjectType.Timesheet_Line_Item__c.fields.Employee__c.isCreateable()){
                for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                    Id employeeId = timesheetMap.get(timesheetLineItem.Timesheet__c).Employee__c;
                    timesheetLineItem.Employee__c = employeeId;
                }
            }
        } else {
            for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                timesheetLineItem.addError('You do not have access, Please contact system admin');
            }
        }
    }
    
    public static void updateBillableField(List<Timesheet_Line_Item__c> timesheetLineItems){
        List<Id> projectIds = new List<Id>();
        for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
			projectIds.add(timesheetLineItem.Project__c);            
        }
        if(Project__c.SObjectType.getDescribe().isAccessible() &&
        Schema.SObjectType.Project__c.fields.Id.isAccessible() &&
        Schema.SObjectType.Project__c.fields.Billable__c.isAccessible()) {
            Map<Id, Project__c> projectMap = new Map<Id, Project__c>([SELECT 
                                                    Id,
                                                    Billable__c
                                                    FROM Project__c
                                                    WHERE Id = : projectIds
                                                    WITH SECURITY_ENFORCED]);
            if(projectMap.size() > 0 && Timesheet_Line_Item__c.SObjectType.getDescribe().isCreateable() &&
            Schema.SObjectType.Timesheet_Line_Item__c.fields.Billable__c.isCreateable()){
                for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                    if(timesheetLineItem.Type__c == 'Attendance'){
                        timesheetLineItem.Billable__c = projectMap.get(timesheetLineItem.Project__c).Billable__c;
                    }
                }
            }
        } else{
            for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                timesheetLineItem.addError('You do not have access, Please contact system admin');
            }
        }
    }
    
    public static void checkForDuplicateTimesheetLineItem(List<Timesheet_Line_Item__c> timesheetLineItems){
        Set<Id> projectIds = new Set<Id>();
        Set<Date> dates = new Set<Date>();
        Set<Id> timesheetIds = new Set<Id>();
        for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
            projectIds.add(timesheetLineItem.Project__c);
            dates.add(timesheetLineItem.Date__c);
            timesheetIds.add(timesheetLineItem.Timesheet__c);
        }
        Map<Id, Timesheet_Line_Item__c> timesheetLineItemMap = new Map<Id, Timesheet_Line_Item__c>();
        if(Timesheet_Line_Item__c.SObjectType.getDescribe().isAccessible() &&
        Schema.SObjectType.Timesheet_Line_Item__c.fields.Id.isAccessible() &&
        Schema.SObjectType.Timesheet_Line_Item__c.fields.Project__c.isAccessible() &&
        Schema.SObjectType.Timesheet_Line_Item__c.fields.Date__c.isAccessible() &&
        Schema.SObjectType.Timesheet_Line_Item__c.fields.Activity__c.isAccessible() &&
        Schema.SObjectType.Timesheet_Line_Item__c.fields.Timesheet__c.isAccessible()) {
            timesheetLineItemMap = new Map<Id, Timesheet_Line_Item__c>([SELECT
                                                                        Id,
                                                                        Project__c,
                                                                        Date__c,
                                                                        Activity__c,
                                                                        Timesheet__c
                                                                        FROM Timesheet_Line_Item__c
                                                                        WHERE Project__c = : projectIds
                                                                        AND Date__c = : dates
                                                                        AND Timesheet__c = : timesheetIds
                                                                        WITH SECURITY_ENFORCED]);
            for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                for(Id id : timesheetLineItemMap.keySet()){
                    if(timesheetLineItem.Id != timesheetLineItemMap.get(id).Id &&  timesheetLineItem.Date__c == timesheetLineItemMap.get(id).Date__c  && timesheetLineItem.Project__c == timesheetLineItemMap.get(id).Project__c && timesheetLineItem.Timesheet__c == timesheetLineItemMap.get(id).Timesheet__c && timesheetLineItem.Activity__c == timesheetLineItemMap.get(id).Activity__c){
                        timesheetLineItem.Project__c.addError('LineItem with the same project and activity already exists for this date, please update the existing record');
                    }
                }
            }
        } else{
            for(Timesheet_Line_Item__c timesheetLineItem : timesheetLineItems){
                timesheetLineItem.addError('You do not have access, Please contact system admin');
        	}
        }
    }
}