public with sharing class GetTimesheetLineItems{
    @AuraEnabled
    public static List<AggregateResult> getTimesheetLineItemsRecords(Id recId) {
        return [SELECT dbt__Date__c, sum(dbt__Duration__c) duration FROM dbt__Timesheet_Line_Item__c
        where dbt__Timesheet__c = :recId
        and dbt__Type__c = 'Attendance'
        group by dbt__Date__c
        order by dbt__Date__c
        ];
  
    }
}