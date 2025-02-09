public with sharing class GetRangeOfTimesheetsLineItems {
    @AuraEnabled
    public static List<AggregateResult> getTimesheetsLineItems(Id recID, Date startDate, Date endDate) {
        return [
            SELECT dbt__Type__c,dbt__Date__c, SUM(dbt__Duration__c) duration 
            FROM dbt__Timesheet_Line_Item__c 
            WHERE dbt__Employee__c = :recID and dbt__type__c = 'Attendance' AND dbt__Date__c>= :startDate AND dbt__Date__c<= :endDate
            GROUP BY dbt__Type__c,dbt__Date__c 
            ORDER BY dbt__Date__c
        ];
    }
}