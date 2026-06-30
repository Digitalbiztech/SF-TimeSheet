public with sharing class TimesheetTimerController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTimerInitData() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            Id userId = UserInfo.getUserId();
            
            // Get Employee
            List<Employee__c> emps = EmployeeSelector.getEmployeesByUserId(userId);
            if (emps.isEmpty()) {
                throw new AuraHandledException('No Employee record found for the current user.');
            }
            Employee__c emp = emps[0];
            result.put('employeeId', emp.Id);
            
            // Get Projects
            List<Project_Employee__c> projects = EmployeeSelector.getEmployeeProjects(emp.Id);
            result.put('projects', projects);
            
            // Get Active Timer
            List<Timesheet_Line_Item__c> activeTimers = [
                SELECT Id, Start_Time__c, Project__c, Project__r.Name, Activity__c 
                FROM Timesheet_Line_Item__c 
                WHERE Employee__c = :emp.Id 
                AND Start_Time__c != NULL 
                AND End_Time__c = NULL
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!activeTimers.isEmpty()) {
                result.put('activeTimer', activeTimers[0]);
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Timesheet_Line_Item__c startTimer(Id employeeId, Id projectId, String activityName) {
        try {
            // Find or create current week's timesheet
            Date todayDate = Date.today();
            Date weekStart = todayDate.toStartOfWeek().addDays(1); // Assuming Monday start
            Date weekEnd = weekStart.addDays(6);
            
            List<Timesheet__c> tsList = [
                SELECT Id 
                FROM Timesheet__c 
                WHERE Employee__c = :employeeId 
                AND Start_Date__c <= :todayDate 
                AND End_Date__c >= :todayDate
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            Timesheet__c ts;
            if (tsList.isEmpty()) {
                ts = new Timesheet__c(
                    Employee__c = employeeId,
                    Start_Date__c = weekStart,
                    End_Date__c = weekEnd,
                    Status__c = 'Draft'
                );
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Timesheet__c>{ts});
                insert decision.getRecords();
                ts = (Timesheet__c)decision.getRecords()[0];
            } else {
                ts = tsList[0];
            }
            
            // Check billable on project
            List<Project__c> projs = [SELECT Id, Billable__c FROM Project__c WHERE Id = :projectId WITH SECURITY_ENFORCED LIMIT 1];
            String billable = projs.isEmpty() ? 'No' : projs[0].Billable__c;

            // Create Timer Line Item
            Timesheet_Line_Item__c newLineItem = new Timesheet_Line_Item__c(
                Timesheet__c = ts.Id,
                Employee__c = employeeId,
                Project__c = projectId,
                Activity__c = activityName,
                Type__c = 'Attendance',
                Date__c = todayDate,
                Start_Time__c = Datetime.now(),
                Duration__c = 0,
                Billable__c = billable
            );
            
            SObjectAccessDecision decisionLi = Security.stripInaccessible(AccessType.CREATABLE, new List<Timesheet_Line_Item__c>{newLineItem});
            insert decisionLi.getRecords();
            
            return [SELECT Id, Start_Time__c, Project__c, Project__r.Name, Activity__c FROM Timesheet_Line_Item__c WHERE Id = :decisionLi.getRecords()[0].Id];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void stopTimer(Id lineItemId) {
        try {
            List<Timesheet_Line_Item__c> items = [
                SELECT Id, Start_Time__c 
                FROM Timesheet_Line_Item__c 
                WHERE Id = :lineItemId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (items.isEmpty()) {
                throw new AuraHandledException('Timer record not found.');
            }
            
            Timesheet_Line_Item__c item = items[0];
            item.End_Time__c = Datetime.now();
            
            // Calculate duration in hours
            Long dt1 = item.Start_Time__c.getTime();
            Long dt2 = item.End_Time__c.getTime();
            Decimal durationHours = (Decimal)(dt2 - dt1) / (1000 * 60 * 60);
            item.Duration__c = durationHours.setScale(2);
            
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Timesheet_Line_Item__c>{item});
            update decision.getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
