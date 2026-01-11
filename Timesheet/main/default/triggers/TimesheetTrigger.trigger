trigger TimesheetTrigger on dbt__Timesheet__c (before insert, before update, after insert, after update, after delete, after undelete) {

    if (Trigger.isBefore) {
        
        Set<Id> empIdsForDivisor = new Set<Id>();
        for (dbt__Timesheet__c ts : Trigger.new) {
            if (ts.dbt__Status__c == 'Approved' && ts.dbt__Employee__c != null) {
                empIdsForDivisor.add(ts.dbt__Employee__c);
            } else {
                ts.Accrued_Hours__c = 0;
            }
        }

        Map<Id, Decimal> empDivisorMap = new Map<Id, Decimal>();
        if (!empIdsForDivisor.isEmpty()) {
            for (dbt__Employee__c emp : [SELECT Id, Accrual_Divisor__c FROM dbt__Employee__c WHERE Id IN :empIdsForDivisor]) {
                empDivisorMap.put(emp.Id, emp.Accrual_Divisor__c);
            }
        }

        for (dbt__Timesheet__c ts : Trigger.new) {
            if (ts.dbt__Status__c == 'Approved' && ts.dbt__Total_Hours__c != null && ts.dbt__Employee__c != null) {
                
                Decimal divisor = empDivisorMap.get(ts.dbt__Employee__c);
                
                if (divisor != null && divisor != 0) {
                    ts.Accrued_Hours__c = ts.dbt__Total_Hours__c / divisor;
                } else {
                    ts.Accrued_Hours__c = 0; 
                }
            }
        }
    }

    if (Trigger.isAfter) {
        Set<Id> empIdsToUpdate = new Set<Id>();

        if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
            for (dbt__Timesheet__c ts : Trigger.new) {
                boolean isRelevantChange = false;
                
                if (Trigger.isInsert && ts.dbt__Status__c == 'Approved') {
                    isRelevantChange = true;
                }
                else if (Trigger.isUpdate) {
                    dbt__Timesheet__c oldTs = Trigger.oldMap.get(ts.Id);
                    
                    boolean statusChanged = (ts.dbt__Status__c != oldTs.dbt__Status__c) && 
                                            (ts.dbt__Status__c == 'Approved' || oldTs.dbt__Status__c == 'Approved');
                                            
                    boolean hoursChanged = (ts.dbt__Status__c == 'Approved' && ts.dbt__Total_Hours__c != oldTs.dbt__Total_Hours__c);

                    if (statusChanged || hoursChanged) {
                        isRelevantChange = true;
                    }
                }
                
                if (isRelevantChange && ts.dbt__Employee__c != null) {
                    empIdsToUpdate.add(ts.dbt__Employee__c);
                }
            }
        }

        if (Trigger.isDelete) {
            for (dbt__Timesheet__c ts : Trigger.old) {
                if (ts.dbt__Status__c == 'Approved' && ts.dbt__Employee__c != null) {
                    empIdsToUpdate.add(ts.dbt__Employee__c);
                }
            }
        }

        if (!empIdsToUpdate.isEmpty()) {
            List<dbt__Employee__c> employeesToUpdate = new List<dbt__Employee__c>();
            Map<Id, Decimal> empTotalMap = new Map<Id, Decimal>();

            for(Id empId : empIdsToUpdate){
                empTotalMap.put(empId, 0);
            }

            Integer currentYear = System.Today().year();
            
            AggregateResult[] results = [
                SELECT dbt__Employee__c, SUM(Accrued_Hours__c) totalAccrued
                FROM dbt__Timesheet__c 
                WHERE dbt__Employee__c IN :empIdsToUpdate 
                AND dbt__Status__c = 'Approved'
                AND CALENDAR_YEAR(dbt__Start_Date__c) = :currentYear
                GROUP BY dbt__Employee__c
            ];

            for (AggregateResult ar : results) {
                Id empId = (Id)ar.get('dbt__Employee__c');
                Decimal total = (Decimal)ar.get('totalAccrued');
                empTotalMap.put(empId, total);
            }

            for (Id empId : empTotalMap.keySet()) {
                dbt__Employee__c emp = new dbt__Employee__c();
                emp.Id = empId;
                emp.Total_Accrued_Hours__c = empTotalMap.get(empId);
                employeesToUpdate.add(emp);
            }

            if (!employeesToUpdate.isEmpty()) {
                update employeesToUpdate;
            }
        }
    }
}