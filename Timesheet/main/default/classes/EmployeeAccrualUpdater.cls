public with sharing class EmployeeAccrualUpdater {
    public Static Void EmployeeAccrualUpdater() {
        Set<Id> empIds = new Set<Id>();
        for(dbt__Timesheet__c ts : [SELECT dbt__Employee__c FROM dbt__Timesheet__c WHERE dbt__Status__c = 'Approved' AND dbt__Employee__c != NULL AND dbt__Employee__r.dbt__Accrual_Start_Date__c != NULL AND dbt__Employee__r.Accrual_Divisor__c != NULL]) {
            empIds.add(ts.dbt__Employee__c);
        }

        if(!empIds.isEmpty()) {
            List<dbt__Employee__c> employeesToUpdate = new List<dbt__Employee__c>();
            
            AggregateResult[] results = [
                SELECT dbt__Employee__c, SUM(Accrued_Hours__c) totalAccrued
                FROM dbt__Timesheet__c 
                WHERE dbt__Employee__c IN :empIds 
                AND dbt__Status__c = 'Approved'
                GROUP BY dbt__Employee__c
            ];

            for (AggregateResult ar : results) {
                employeesToUpdate.add(new dbt__Employee__c(
                    Id = (Id)ar.get('dbt__Employee__c'),
                    Total_Accrued_Hours__c = (Decimal)ar.get('totalAccrued')
                ));
            }
            
            if(!employeesToUpdate.isEmpty()) {
                update employeesToUpdate;
            }
        }
    }
}