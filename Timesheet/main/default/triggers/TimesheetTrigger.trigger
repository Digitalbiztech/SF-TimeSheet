trigger TimesheetTrigger on dbt__Timesheet__c (before insert, before update, after insert, after update, after delete, after undelete) {

    if (Trigger.isBefore) {
        
        Set<Id> timesheetIds = new Set<Id>();
        Set<Id> empIdsForDivisor = new Set<Id>();
        for (dbt__Timesheet__c ts : Trigger.new) {
            if (ts.dbt__Status__c == 'Approved' && ts.dbt__Employee__c != null) {
                empIdsForDivisor.add(ts.dbt__Employee__c);
                timesheetIds.add(ts.Id);
            } else {
                ts.Accrued_Hours__c = 0;
            }
        }

        Map<Id, Decimal> empDivisorMap = new Map<Id, Decimal>();
        Map<Id, Date> empAccrualStartMap = new Map<Id, Date>();
        if (!empIdsForDivisor.isEmpty()) {
            for (dbt__Employee__c emp : [
                SELECT Id, Accrual_Divisor__c, dbt__Accrual_Start_Date__c
                FROM dbt__Employee__c
                WHERE Id IN :empIdsForDivisor
            ]) {
                empDivisorMap.put(emp.Id, emp.Accrual_Divisor__c);
                empAccrualStartMap.put(emp.Id, emp.dbt__Accrual_Start_Date__c);
            }
        }

        Map<Id, Decimal> timesheetToBillableHours = new Map<Id, Decimal>();
        if (!timesheetIds.isEmpty()) {
            for (dbt__Timesheet_Line_Item__c li : [
                SELECT dbt__Timesheet__c, dbt__Duration__c, dbt__Date__c, dbt__Billable__c, dbt__Type__c, dbt__Employee__c
                FROM dbt__Timesheet_Line_Item__c
                WHERE dbt__Timesheet__c IN :timesheetIds
                AND dbt__Billable__c = 'Yes'
                AND dbt__Type__c = 'Attendance'
            ]) {
                Date accrualStart = empAccrualStartMap.get(li.dbt__Employee__c);
                if (accrualStart != null && li.dbt__Date__c != null && li.dbt__Date__c >= accrualStart) {
                    Decimal running = timesheetToBillableHours.containsKey(li.dbt__Timesheet__c)
                        ? timesheetToBillableHours.get(li.dbt__Timesheet__c)
                        : 0;
                    running += (li.dbt__Duration__c == null ? 0 : li.dbt__Duration__c);
                    //Decimal running = (timesheetToBillableHours.get(li.dbt__Timesheet__c) ?? 0) + (li.dbt__Duration__c ?? 0);
                    timesheetToBillableHours.put(li.dbt__Timesheet__c, running);
                }
            }
        }

        for (dbt__Timesheet__c ts : Trigger.new) {
            if (ts.dbt__Status__c == 'Approved' && ts.dbt__Employee__c != null) {
                Decimal totalBillableHours = timesheetToBillableHours.get(ts.Id);
                Decimal divisor = empDivisorMap.get(ts.dbt__Employee__c);

                if (totalBillableHours != null && totalBillableHours > 0 && divisor != null && divisor != 0) {
                    ts.Accrued_Hours__c = totalBillableHours / divisor;
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

                    if (statusChanged) {
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

            // Integer currentYear = System.Today().year();
            
            AggregateResult[] results = [
                SELECT dbt__Employee__c, SUM(Accrued_Hours__c) totalAccrued
                FROM dbt__Timesheet__c 
                WHERE dbt__Employee__c IN :empIdsToUpdate 
                AND dbt__Status__c = 'Approved'
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