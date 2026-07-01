public with sharing class TimesheetTimerController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTimerInitData() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            Id userId = UserInfo.getUserId();
            
            // Get Projects directly by User Id
            List<Project_Employee__c> projects = [
                SELECT Id, Name, Project__c, Project__r.Name, Employee__c, Hourly_Rate__c, Project__r.Billable__c
                FROM Project_Employee__c 
                WHERE Employee__r.User__c = :userId 
                AND Project__r.Active__c = true
                WITH SECURITY_ENFORCED
            ];
            result.put('projects', projects);
            
            // Get Active Timer directly by User Id
            List<Timesheet_Line_Item__c> activeTimers = [
                SELECT Id, Start_Time__c, Project__c, Project__r.Name, Activity__c, Duration__c, Employee__c, Description__c 
                FROM Timesheet_Line_Item__c 
                WHERE Employee__r.User__c = :userId 
                AND Start_Time__c != NULL 
                AND End_Time__c = NULL
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!activeTimers.isEmpty()) {
                result.put('activeTimer', activeTimers[0]);
            }
            
            // Get Employee ID for the UI
            Id empId = null;
            if (!projects.isEmpty()) {
                empId = projects[0].Employee__c;
            } else if (!activeTimers.isEmpty()) {
                empId = activeTimers[0].Employee__c;
            } else {
                List<Employee__c> emps = [SELECT Id FROM Employee__c WHERE User__c = :userId WITH SECURITY_ENFORCED LIMIT 1];
                if (!emps.isEmpty()) {
                    empId = emps[0].Id;
                }
            }
            
            if (empId != null) {
                result.put('employeeId', empId);
            } else {
                throw new AuraHandledException('No Employee record found for the current user.');
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Timesheet_Line_Item__c startTimer(Id employeeId, Id projectId, String activityName) {
        try {
            Date todayDate = Date.today();
            // Check for existing line item for today, project, activity
            List<Timesheet_Line_Item__c> existingItems = [
                SELECT Id, Start_Time__c, End_Time__c, Duration__c, Description__c
                FROM Timesheet_Line_Item__c 
                WHERE Employee__c = :employeeId
                AND Project__c = :projectId
                AND Activity__c = :activityName
                AND Date__c = :todayDate
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!existingItems.isEmpty()) {
                Timesheet_Line_Item__c item = existingItems[0];
                
                Map<String, Object> state = new Map<String, Object>();
                state.put('status', 'Resumed');
                state.put('oldStart', item.Start_Time__c != null ? item.Start_Time__c.getTime() : null);
                state.put('oldEnd', item.End_Time__c != null ? item.End_Time__c.getTime() : null);
                
                item.Start_Time__c = Datetime.now();
                item.End_Time__c = null;
                item.Created_From_Timer__c = JSON.serialize(state);
                
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Timesheet_Line_Item__c>{item});
                update decision.getRecords();
                
                return [SELECT Id, Start_Time__c, Project__c, Project__r.Name, Activity__c, Duration__c, Description__c FROM Timesheet_Line_Item__c WHERE Id = :item.Id];
            }
            
            Timesheet__c ts = getOrCreateTimesheet(employeeId, todayDate);
            
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
                Billable__c = billable,
                Created_From_Timer__c = '{"status": "New"}'
            );
            
            SObjectAccessDecision decisionLi = Security.stripInaccessible(AccessType.CREATABLE, new List<Timesheet_Line_Item__c>{newLineItem});
            insert decisionLi.getRecords();
            
            return [SELECT Id, Start_Time__c, Project__c, Project__r.Name, Activity__c, Duration__c, Description__c FROM Timesheet_Line_Item__c WHERE Id = :decisionLi.getRecords()[0].Id];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void stopTimer(Id lineItemId, Long stopTimeMs, Long totalPauseMs, String description) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<Timesheet_Line_Item__c> items = [
                SELECT Id, Start_Time__c, Timesheet__c, Timesheet__r.Name, Employee__c, Project__c, Project__r.Name, Activity__c, Type__c, Billable__c, Duration__c
                FROM Timesheet_Line_Item__c 
                WHERE Id = :lineItemId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (items.isEmpty()) {
                throw new AuraHandledException('Timer record not found.');
            }
            
            Timesheet_Line_Item__c item = items[0];
            
            // Adjust start time forward by the total paused milliseconds
            Long adjustedStartMs = item.Start_Time__c.getTime();
            if (totalPauseMs != null && totalPauseMs > 0) {
                adjustedStartMs += totalPauseMs;
            }
            Datetime startTime = Datetime.newInstance(adjustedStartMs);
            
            Datetime endTime = (stopTimeMs != null) ? Datetime.newInstance(stopTimeMs) : Datetime.now();
            Date startDate = startTime.date();
            Date endDate = endTime.date();
            
            List<Timesheet_Line_Item__c> itemsToUpsert = new List<Timesheet_Line_Item__c>();
            
            if (startDate == endDate) {
                item.End_Time__c = endTime;
                item.Duration__c = (item.Duration__c != null ? item.Duration__c : 0) + calculateDuration(startTime, endTime);
                item.Created_From_Timer__c = '{"status": "Saved"}';
                item.Description__c = description;
                itemsToUpsert.add(item);
            } else {
                // Crossing days, need to check for existing items to avoid duplicate errors
                List<Date> allDates = new List<Date>();
                Date d = startDate.addDays(1);
                while (d <= endDate) {
                    allDates.add(d);
                    d = d.addDays(1);
                }
                
                List<Timesheet_Line_Item__c> existingItems = [
                    SELECT Id, Date__c, Duration__c, Description__c
                    FROM Timesheet_Line_Item__c 
                    WHERE Employee__c = :item.Employee__c 
                    AND Project__c = :item.Project__c 
                    AND Activity__c = :item.Activity__c 
                    AND Date__c IN :allDates
                    WITH SECURITY_ENFORCED
                ];
                Map<Date, Timesheet_Line_Item__c> dateToExistingItem = new Map<Date, Timesheet_Line_Item__c>();
                for (Timesheet_Line_Item__c ex : existingItems) {
                    dateToExistingItem.put(ex.Date__c, ex);
                }
                
                // Close the first day item
                Datetime endOfFirstDay = Datetime.newInstance(startDate.year(), startDate.month(), startDate.day(), 23, 59, 59);
                item.End_Time__c = endOfFirstDay;
                item.Duration__c = (item.Duration__c != null ? item.Duration__c : 0) + calculateDuration(startTime, endOfFirstDay);
                item.Created_From_Timer__c = '{"status": "Saved"}';
                item.Description__c = description;
                itemsToUpsert.add(item);
                
                // Create or update items for intermediate and last day
                Date currDate = startDate.addDays(1);
                while (currDate <= endDate) {
                    Datetime dayStart = Datetime.newInstance(currDate.year(), currDate.month(), currDate.day(), 0, 0, 0);
                    Datetime dayEnd = (currDate == endDate) ? endTime : Datetime.newInstance(currDate.year(), currDate.month(), currDate.day(), 23, 59, 59);
                    Decimal dayDur = calculateDuration(dayStart, dayEnd);
                    
                    if (dateToExistingItem.containsKey(currDate)) {
                        Timesheet_Line_Item__c ex = dateToExistingItem.get(currDate);
                        ex.Duration__c = (ex.Duration__c != null ? ex.Duration__c : 0) + dayDur;
                        if (String.isNotBlank(description)) {
                            ex.Description__c = String.isNotBlank(ex.Description__c) ? ex.Description__c + '\n' + description : description;
                        }
                        itemsToUpsert.add(ex);
                    } else {
                        Timesheet__c ts = getOrCreateTimesheet(item.Employee__c, currDate);
                        Timesheet_Line_Item__c newItem = new Timesheet_Line_Item__c(
                            Timesheet__c = ts.Id,
                            Employee__c = item.Employee__c,
                            Project__c = item.Project__c,
                            Activity__c = item.Activity__c,
                            Type__c = item.Type__c,
                            Billable__c = item.Billable__c,
                            Date__c = currDate,
                            Start_Time__c = dayStart,
                            End_Time__c = dayEnd,
                            Duration__c = dayDur,
                            Created_From_Timer__c = '{"status": "Saved"}',
                            Description__c = description
                        );
                        itemsToUpsert.add(newItem);
                    }
                    currDate = currDate.addDays(1);
                }
            }
            
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPSERTABLE, itemsToUpsert);
            upsert decision.getRecords();
            
        } catch (Exception e) {
            Database.rollback(sp);
            
            // Prepare detailed error message based on the items we attempted to save
            String originalError = e.getMessage();
            if (originalError.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                originalError = originalError.substringAfter('FIELD_CUSTOM_VALIDATION_EXCEPTION,').substringBefore(': [').trim();
            }
            
            // Try to gather item details again for the error message
            List<Map<String, Object>> failedItemsData = new List<Map<String, Object>>();
            try {
                // Re-query the first item to get Project Name, etc.
                List<Timesheet_Line_Item__c> baseItems = [
                    SELECT Id, Timesheet__r.Name, Project__r.Name, Activity__c 
                    FROM Timesheet_Line_Item__c 
                    WHERE Id = :lineItemId 
                    LIMIT 1
                ];
                
                if (!baseItems.isEmpty()) {
                    String projName = baseItems[0].Project__r.Name;
                    String activity = baseItems[0].Activity__c;
                    
                    // We know the date range from the parameters, let's reconstruct the durations
                    Datetime st = Datetime.newInstance([SELECT Start_Time__c FROM Timesheet_Line_Item__c WHERE Id = :lineItemId LIMIT 1][0].Start_Time__c.getTime() + (totalPauseMs != null ? totalPauseMs : 0));
                    Datetime et = (stopTimeMs != null) ? Datetime.newInstance(stopTimeMs) : Datetime.now();
                    
                    Date sDate = st.date();
                    Date eDate = et.date();
                    
                    Date curr = sDate;
                    while (curr <= eDate) {
                        Datetime ds = (curr == sDate) ? st : Datetime.newInstance(curr.year(), curr.month(), curr.day(), 0, 0, 0);
                        Datetime de = (curr == eDate) ? et : Datetime.newInstance(curr.year(), curr.month(), curr.day(), 23, 59, 59);
                        Decimal dur = calculateDuration(ds, de);
                        
                        Map<String, Object> itemData = new Map<String, Object>();
                        itemData.put('date', String.valueOf(curr));
                        itemData.put('project', projName);
                        itemData.put('activity', activity);
                        itemData.put('duration', dur);
                        failedItemsData.add(itemData);
                        
                        curr = curr.addDays(1);
                    }
                }
            } catch (Exception innerE) {
                // Ignore inner exception for gathering details
            }
            
            Map<String, Object> errorPayload = new Map<String, Object>();
            errorPayload.put('isCustomError', true);
            errorPayload.put('message', originalError);
            errorPayload.put('failedItems', failedItemsData);
            
            throw new AuraHandledException(JSON.serialize(errorPayload));
        }
    }

    @AuraEnabled
    public static void discardTimer(Id lineItemId) {
        try {
            List<Timesheet_Line_Item__c> items = [
                SELECT Id, Created_From_Timer__c 
                FROM Timesheet_Line_Item__c 
                WHERE Id = :lineItemId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (items.isEmpty()) return;
            
            Timesheet_Line_Item__c item = items[0];
            String stateStr = item.Created_From_Timer__c;
            
            if (String.isNotBlank(stateStr)) {
                Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(stateStr);
                String status = (String)state.get('status');
                
                if (status == 'New') {
                    if (Schema.sObjectType.Timesheet_Line_Item__c.isDeletable()) {
                        delete item;
                    }
                } else if (status == 'Resumed') {
                    Long oldStart = (Long)state.get('oldStart');
                    Long oldEnd = (Long)state.get('oldEnd');
                    
                    item.Start_Time__c = oldStart != null ? Datetime.newInstance(oldStart) : null;
                    item.End_Time__c = oldEnd != null ? Datetime.newInstance(oldEnd) : null;
                    item.Created_From_Timer__c = '{"status": "Saved"}';
                    
                    SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Timesheet_Line_Item__c>{item});
                    update decision.getRecords();
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateTimerDescription(Id lineItemId, String description) {
        try {
            Timesheet_Line_Item__c item = new Timesheet_Line_Item__c(Id = lineItemId, Description__c = description);
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Timesheet_Line_Item__c>{item});
            update decision.getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static Decimal calculateDuration(Datetime startDt, Datetime endDt) {
        Long dt1 = startDt.getTime();
        Long dt2 = endDt.getTime();
        Decimal durationHours = (Decimal)(dt2 - dt1) / (1000 * 60 * 60);
        return durationHours.setScale(2);
    }
    
    private static Timesheet__c getOrCreateTimesheet(Id employeeId, Date targetDate) {
        Date weekStart = targetDate.toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(6);
        
        List<Timesheet__c> tsList = [
            SELECT Id 
            FROM Timesheet__c 
            WHERE Employee__c = :employeeId 
            AND Start_Date__c <= :targetDate 
            AND End_Date__c >= :targetDate
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        if (tsList.isEmpty()) {
            Timesheet__c ts = new Timesheet__c(
                Employee__c = employeeId,
                Start_Date__c = weekStart,
                End_Date__c = weekEnd,
                Status__c = 'Draft'
            );
            insert ts;
            return ts;
        }
        return tsList[0];
    }
}
