public with sharing class GetDashboardTimesheetLineItems {
    @AuraEnabled(cacheable=true)
    public static List<AggregateResult> getDashboardTimesheetLineItemsDetails(Id userID){
        try {
            // system.debug('userid'+ userID);
            return [
                select 
                    dbt__Date__c, dbt__Type__c, dbt__Project__r.name,SUM(dbt__Duration__c) duration 
                from 
                    dbt__Timesheet_Line_Item__c
                where 
                    dbt__Employee__c IN (select id from dbt__Employee__c where dbt__User__c = '005fK000000xxC9QAI') // userid  
                    AND 
                    dbt__Date__c >= LAST_N_YEARS:5
                group by 
                    dbt__Date__c, dbt__Type__c, dbt__Project__r.name
                order by 
                    dbt__Date__c DESC
            ];
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}